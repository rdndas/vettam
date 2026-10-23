// ddc_probe.swift — LuminoBar / Vettam DDC/CI diagnostic probe (Apple Silicon)
// Build: swiftc -O -module-cache-path .modcache -framework IOKit -framework Foundation -framework CoreGraphics ddc_probe.swift -o ddc_probe
// Usage: ./ddc_probe [--no-write]

import Foundation
import IOKit
import CoreGraphics

// MARK: - Private IOAVService bindings
@_silgen_name("IOAVServiceCreateWithService")
func IOAVServiceCreateWithService(_ allocator: CFAllocator?, _ service: io_service_t) -> Unmanaged<CFTypeRef>?
@_silgen_name("IOAVServiceWriteI2C")
func IOAVServiceWriteI2C(_ service: CFTypeRef, _ chipAddress: UInt32, _ dataAddress: UInt32, _ inputBuffer: UnsafePointer<UInt8>, _ inputBufferSize: UInt32) -> IOReturn
@_silgen_name("IOAVServiceReadI2C")
func IOAVServiceReadI2C(_ service: CFTypeRef, _ chipAddress: UInt32, _ offset: UInt32, _ outputBuffer: UnsafeMutablePointer<UInt8>, _ outputBufferSize: UInt32) -> IOReturn

let DDC_CHIP: UInt32 = 0x37      // 7-bit DDC/CI address (0x6E/0x6F on the wire)
let DDC_HOST: UInt32 = 0x51      // host "source address" byte, passed as data address
let allowWrite = !CommandLine.arguments.contains("--no-write")

func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02X", $0) }.joined(separator: " ") }
func ioErr(_ r: IOReturn) -> String { String(format: "0x%08X", UInt32(bitPattern: r)) }
func msleep(_ ms: UInt32) { usleep(ms * 1000) }
extension String: @retroactive Error {}

// MARK: - DDC transport
struct DDC {
    let av: CFTypeRef
    var replyDelayMs: UInt32 = 50
    var verbose = false

    /// Builds [len|0x80, payload..., checksum]; checksum = 0x6E ^ 0x51 ^ bytes.
    func frame(_ payload: [UInt8]) -> [UInt8] {
        var p: [UInt8] = [0x80 | UInt8(payload.count)] + payload
        var chk: UInt8 = 0x6E ^ UInt8(DDC_HOST)
        for b in p { chk ^= b }
        p.append(chk)
        return p
    }

    func write(_ payload: [UInt8]) -> IOReturn {
        let f = frame(payload)
        let r = f.withUnsafeBufferPointer { IOAVServiceWriteI2C(av, DDC_CHIP, DDC_HOST, $0.baseAddress!, UInt32(f.count)) }
        if verbose { print("      TX \(hex(f)) -> \(ioErr(r))") }
        return r
    }

    func read(_ n: Int) -> (IOReturn, [UInt8]) {
        var buf = [UInt8](repeating: 0, count: n)
        let r = IOAVServiceReadI2C(av, DDC_CHIP, DDC_HOST, &buf, UInt32(n))
        if verbose { print("      RX \(hex(buf)) -> \(ioErr(r))") }
        return (r, buf)
    }

    /// Validates reply checksum: 0x50 ^ bytes[0..<n-1] (reply source 0x6E, dest 0x51 → virtual host 0x50).
    func checksumOK(_ b: [UInt8], len: Int) -> Bool {
        guard len >= 2, len <= b.count else { return false }
        var chk: UInt8 = 0x50
        for i in 0..<(len - 1) { chk ^= b[i] }
        return chk == b[len - 1]
    }

    struct VCPReply { let code: UInt8; let type: UInt8; let max: UInt16; let cur: UInt16; let raw: [UInt8] }

    /// VCP Get Feature (0x01) with retries.
    func getVCP(_ code: UInt8, attempts: Int = 5) -> Result<VCPReply, String> {
        var last = "no attempt"
        for a in 1...attempts {
            let w = write([0x01, code])
            if w != kIOReturnSuccess { last = "write \(ioErr(w))"; msleep(replyDelayMs); continue }
            msleep(replyDelayMs)
            let (r, b) = read(12)
            if r != kIOReturnSuccess { last = "read \(ioErr(r))"; msleep(replyDelayMs); continue }
            // Expected: 6E 88 02 RC VCP TP MH ML CH CL CHK
            if b[0] == 0x6E, b[1] == 0x88, b[2] == 0x02, b[4] == code {
                if !checksumOK(b, len: 11) { last = "bad checksum \(hex(b))"; msleep(replyDelayMs); continue }
                if b[3] != 0x00 { return .failure("unsupported (result code 0x\(String(format: "%02X", b[3])))") }
                return .success(VCPReply(code: code, type: b[5],
                                         max: UInt16(b[6]) << 8 | UInt16(b[7]),
                                         cur: UInt16(b[8]) << 8 | UInt16(b[9]), raw: b))
            }
            if b[0] == 0x6E, b[1] == 0x80, b[2] == 0xBE {
                last = "DDC/CI NULL message (6E 80 BE): display ACKs but is not servicing VCP requests"
                msleep(replyDelayMs); continue
            }
            last = "malformed reply (attempt \(a)) \(hex(b))"
            msleep(replyDelayMs)
        }
        return .failure(last)
    }

    func setVCP(_ code: UInt8, _ value: UInt16) -> IOReturn {
        var r: IOReturn = kIOReturnError
        for _ in 0..<2 {      // Apple Silicon convention: send set twice for reliability (idempotent)
            r = write([0x03, code, UInt8(value >> 8), UInt8(value & 0xFF)])
            msleep(replyDelayMs)
        }
        return r
    }

    /// Capabilities Request (0xF3) — fragments of up to 32 data bytes.
    func capabilities() -> (String?, String) {
        var data = [UInt8]()
        var offset: UInt16 = 0
        var fragments = 0
        while fragments < 64 {
            var got: [UInt8]? = nil
            var lastErr = ""
            for _ in 0..<6 {
                let w = write([0xF3, UInt8(offset >> 8), UInt8(offset & 0xFF)])
                if w != kIOReturnSuccess { lastErr = "write \(ioErr(w))"; msleep(replyDelayMs); continue }
                msleep(replyDelayMs)
                let (r, b) = read(38)
                if r != kIOReturnSuccess { lastErr = "read \(ioErr(r))"; msleep(replyDelayMs); continue }
                guard b[0] == 0x6E, b[1] & 0x80 != 0, b[2] == 0xE3 else { lastErr = "malformed \(hex(b))"; msleep(replyDelayMs); continue }
                let len = Int(b[1] & 0x7F)
                guard len >= 3, len + 3 <= b.count else { lastErr = "bad length \(len)"; msleep(replyDelayMs); continue }
                guard checksumOK(b, len: len + 3) else { lastErr = "bad checksum"; msleep(replyDelayMs); continue }
                let roff = UInt16(b[3]) << 8 | UInt16(b[4])
                guard roff == offset else { lastErr = "offset mismatch \(roff) != \(offset)"; msleep(replyDelayMs); continue }
                got = Array(b[5..<(5 + len - 3)])
                break
            }
            guard let chunk = got else { return (data.isEmpty ? nil : String(decoding: data, as: UTF8.self), "fragment @\(offset) failed: \(lastErr)") }
            fragments += 1
            if chunk.isEmpty { break }                // empty fragment = end
            data += chunk
            offset += UInt16(chunk.count)
            if chunk.contains(0) { break }
            msleep(replyDelayMs)
        }
        let s = String(decoding: data.filter { $0 != 0 }, as: UTF8.self)
        return (s, "\(fragments) fragments, \(data.count) bytes")
    }
}

// MARK: - MCCS dictionary
let vcpNames: [UInt8: String] = [
    0x02: "New Control Value", 0x04: "Restore Factory Defaults", 0x05: "Restore Factory Luminance/Contrast",
    0x06: "Restore Factory Geometry", 0x08: "Restore Factory Color", 0x0B: "Color Temp Increment",
    0x0C: "Color Temp Request", 0x10: "Brightness", 0x12: "Contrast", 0x14: "Color Preset (Temp)",
    0x16: "Red Gain", 0x18: "Green Gain", 0x1A: "Blue Gain", 0x52: "Active Control", 0x60: "Input Source",
    0x62: "Audio Volume", 0x6C: "Red Black Level", 0x6E: "Green Black Level", 0x70: "Blue Black Level",
    0x72: "Gamma", 0x86: "Display Scaling", 0x87: "Sharpness", 0x8A: "Saturation", 0x8D: "Audio Mute",
    0x90: "Hue", 0xAC: "H Frequency", 0xAE: "V Frequency", 0xB2: "Flat Panel Sub-pixel Layout",
    0xB6: "Display Technology Type", 0xC0: "Display Usage Time", 0xC6: "Application Enable Key",
    0xC8: "Display Controller Type", 0xC9: "Display Firmware Level", 0xCA: "OSD/Button Control",
    0xCC: "OSD Language", 0xD6: "Power Mode", 0xDC: "Display Mode (Picture Preset)", 0xDF: "VCP Version",
]
func vcpName(_ c: UInt8) -> String { vcpNames[c] ?? (c >= 0xE0 ? "Manufacturer-specific" : "Unknown") }

let inputNames: [UInt16: String] = [0x01: "VGA-1", 0x03: "DVI-1", 0x0F: "DisplayPort-1", 0x10: "DisplayPort-2",
                                    0x11: "HDMI-1", 0x12: "HDMI-2", 0x1B: "USB-C", 0x13: "HDMI-3"]
let colorPresetNames: [UInt16: String] = [0x01: "sRGB", 0x02: "Native", 0x03: "4000K", 0x04: "5000K", 0x05: "6500K",
                                          0x06: "7500K", 0x08: "9300K", 0x09: "10000K", 0x0A: "11500K", 0x0B: "User 1",
                                          0x0C: "User 2", 0x0D: "User 3"]
let powerNames: [UInt16: String] = [0x01: "On", 0x02: "Standby", 0x03: "Suspend", 0x04: "Off (soft)", 0x05: "Off (hard)"]

func parseVCP(_ caps: String) -> [(UInt8, [UInt8])] {
    guard let r = caps.range(of: "vcp(", options: .caseInsensitive) else { return [] }
    var i = r.upperBound
    var depth = 1
    var out: [(UInt8, [UInt8])] = []
    var token = ""
    var inner: [UInt8] = []
    var innerTok = ""
    func flushTop() { if let v = UInt8(token, radix: 16) { out.append((v, [])) }; token = "" }
    while i < caps.endIndex, depth > 0 {
        let ch = caps[i]
        if depth == 1 {
            if ch == "(" { flushTop(); depth = 2; inner = []; innerTok = "" }
            else if ch == ")" { flushTop(); depth = 0 }
            else if ch == " " { flushTop() }
            else { token.append(ch) }
        } else {
            if ch == "(" { depth += 1 }
            else if ch == ")" {
                depth -= 1
                if depth == 1 {
                    if let v = UInt8(innerTok, radix: 16) { inner.append(v) }
                    if !out.isEmpty { out[out.count - 1].1 = inner }
                }
            } else if ch == " " { if let v = UInt8(innerTok, radix: 16) { inner.append(v) }; innerTok = "" }
            else if depth == 2 { innerTok.append(ch) }
        }
        i = caps.index(after: i)
    }
    return out
}

// MARK: - Registry helpers
func prop(_ s: io_service_t, _ key: String) -> Any? {
    IORegistryEntryCreateCFProperty(s, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
}
func services(_ cls: String) -> [io_service_t] {
    var it: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(cls), &it) == KERN_SUCCESS else { return [] }
    defer { IOObjectRelease(it) }
    var out: [io_service_t] = []
    while case let s = IOIteratorNext(it), s != 0 { out.append(s) }
    return out
}

// MARK: - Main
print("== Vettam / LuminoBar DDC/CI probe ==")
var info = utsname(); uname(&info)
print("Host: \(ProcessInfo.processInfo.operatingSystemVersionString), write test: \(allowWrite ? "ON" : "OFF")")

var ids = [CGDirectDisplayID](repeating: 0, count: 16); var n: UInt32 = 0
CGGetOnlineDisplayList(16, &ids, &n)
for d in ids.prefix(Int(n)) {
    print(String(format: "CG display %u: vendor 0x%04X model 0x%04X builtin=%@", d, CGDisplayVendorNumber(d), CGDisplayModelNumber(d), CGDisplayIsBuiltin(d) != 0 ? "yes" : "no"))
}

print("\n-- AppleCLCD2 framebuffers --")
var externalTransport = "unknown"
var externalName = "unknown"
for s in services("AppleCLCD2") {
    guard let attrs = prop(s, "DisplayAttributes") as? [String: Any],
          let pa = attrs["ProductAttributes"] as? [String: Any] else { continue }
    let name = pa["ProductName"] as? String ?? "?"
    let t = prop(s, "Transport") as? [String: String]
    let ts = t.map { "\($0["Upstream"] ?? "?") -> \($0["Downstream"] ?? "?")" } ?? "internal"
    print("  \(name)  vendor=\(pa["ManufacturerID"] ?? "?") pid=\(pa["ProductID"] ?? "?") serial=\(pa["AlphanumericSerialNumber"] ?? "?")  transport: \(ts)")
    if t != nil { externalName = name; externalTransport = ts }
}
let portKind: String = {
    if externalTransport.hasSuffix("HDMI") { return externalTransport.hasPrefix("DP") ? "HDMI (via internal DP->HDMI converter / built-in HDMI port or USB-C->HDMI adapter)" : "HDMI" }
    if externalTransport.hasSuffix("DP") { return "DisplayPort / USB-C Alt Mode" }
    return externalTransport
}()
print("  => external: \(externalName) over \(portKind)")

print("\n-- DCPAVServiceProxy --")
let proxies = services("DCPAVServiceProxy")
if proxies.isEmpty { print("  none found") }
var tested = 0
for s in proxies {
    let loc = prop(s, "Location") as? String ?? "?"
    var eid: UInt64 = 0; IORegistryEntryGetRegistryEntryID(s, &eid)
    print(String(format: "  proxy id 0x%llX Location=%@", eid, loc))
    guard loc == "External" else { print("    (skipping embedded panel)"); continue }
    guard let avU = IOAVServiceCreateWithService(kCFAllocatorDefault, s) else {
        print("    IOAVServiceCreateWithService FAILED"); continue
    }
    let av = avU.takeRetainedValue()
    print("    IOAVService handle created")
    tested += 1

    var ddc = DDC(av: av)
    var working: DDC.VCPReply? = nil
    for delay: UInt32 in [10, 30, 50, 80, 120] {
        ddc.replyDelayMs = delay
        ddc.verbose = true
        print("    probing 0x10 with reply delay \(delay) ms")
        switch ddc.getVCP(0x10, attempts: 3) {
        case .success(let r): working = r; print("    OK at \(delay) ms")
        case .failure(let e): print("    fail: \(e)")
        }
        if working != nil { break }
    }
    ddc.verbose = false
    guard working != nil else {
        var edid = [UInt8](repeating: 0, count: 16)
        _ = IOAVServiceReadI2C(av, 0x50, 0, &edid, 16)
        let edidOK = edid.prefix(8) == [0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00]
        print("\n    EDID over I2C (chip 0x50): \(edidOK ? "OK — DDC wires pass through" : "FAILED") [\(hex(edid))]")
        print("    RESULT: DDC/CI BLOCKED — no valid VCP reply on any timing.")
        continue
    }
    ddc.replyDelayMs = max(ddc.replyDelayMs, 50)

    print("\n    -- Capabilities (0xF3) --")
    let (caps, capInfo) = ddc.capabilities()
    print("    \(capInfo)")
    print("    RAW: \(caps ?? "<none>")")
    var codes = caps.map(parseVCP) ?? []
    if codes.isEmpty {
        print("    (no vcp() block parsed — falling back to MCCS sweep of common codes)")
        codes = [0x10, 0x12, 0x14, 0x16, 0x18, 0x1A, 0x60, 0x62, 0x6C, 0x6E, 0x70, 0x72, 0x87, 0x8A, 0x8D, 0xAC, 0xAE, 0xB6, 0xC0, 0xC6, 0xC8, 0xC9, 0xCA, 0xCC, 0xD6, 0xDC, 0xDF].map { ($0, []) }
    }

    print("\n    -- Feature table --")
    print("    CODE  NAME                              TYPE  CUR     MAX    DECODED / ALLOWED")
    let neverTouch: Set<UInt8> = [0x01, 0x02, 0x04, 0x05, 0x06, 0x08, 0x0A]
    for (code, allowed) in codes {
        let name = vcpName(code).padding(toLength: 32, withPad: " ", startingAt: 0)
        let allowedStr = allowed.isEmpty ? "" : " allowed=[" + allowed.map { String(format: "%02X", $0) }.joined(separator: " ") + "]"
        if neverTouch.contains(code) {
            print(String(format: "    0x%02X  %@  —     (action/reset code — not queried)%@", code, name, allowedStr)); continue
        }
        switch ddc.getVCP(code, attempts: 3) {
        case .success(let r):
            var dec = ""
            switch code {
            case 0x60: dec = inputNames[r.cur & 0xFF] ?? "?"
            case 0x14: dec = colorPresetNames[r.cur] ?? "?"
            case 0xD6: dec = powerNames[r.cur] ?? "?"
            case 0x8D: dec = r.cur == 1 ? "Muted" : r.cur == 2 ? "Unmuted" : "?"
            default: break
            }
            print(String(format: "    0x%02X  %@  %@    %-6u  %-5u  %@%@", code, name, r.type == 0 ? "C " : "NC", r.cur, r.max, dec, allowedStr))
        case .failure(let e):
            print(String(format: "    0x%02X  %@  ERR   %@%@", code, name, e, allowedStr))
        }
    }

    print("\n    -- Key register tests --")
    for code: UInt8 in [0x10, 0x12, 0x62, 0x8D, 0x60, 0xD6] {
        switch ddc.getVCP(code) {
        case .success(let r): print(String(format: "    0x%02X %@: cur=%u max=%u raw=[%@]", code, vcpName(code), r.cur, r.max, hex(r.raw)))
        case .failure(let e): print(String(format: "    0x%02X %@: %@", code, vcpName(code), e))
        }
    }

    if allowWrite, case .success(let b) = ddc.getVCP(0x10) {
        print("\n    -- Write-back test: brightness = \(b.cur) (unchanged) --")
        let w = ddc.setVCP(0x10, b.cur)
        msleep(100)
        if case .success(let b2) = ddc.getVCP(0x10) {
            print("    write \(ioErr(w)); readback=\(b2.cur) -> \(w == kIOReturnSuccess && b2.cur == b.cur ? "PASS" : "MISMATCH")")
        } else { print("    write \(ioErr(w)); readback failed") }
    }
}
if tested == 0 { print("\nNo external IOAVService could be opened.") }
