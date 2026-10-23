// ddc_matrix.swift — sweep IOAVService transaction parameters for VCP 0x10 Get
import Foundation
import IOKit

@_silgen_name("IOAVServiceCreateWithService")
func IOAVServiceCreateWithService(_ a: CFAllocator?, _ s: io_service_t) -> Unmanaged<CFTypeRef>?
@_silgen_name("IOAVServiceWriteI2C")
func IOAVServiceWriteI2C(_ s: CFTypeRef, _ c: UInt32, _ d: UInt32, _ b: UnsafePointer<UInt8>, _ n: UInt32) -> IOReturn
@_silgen_name("IOAVServiceReadI2C")
func IOAVServiceReadI2C(_ s: CFTypeRef, _ c: UInt32, _ o: UInt32, _ b: UnsafeMutablePointer<UInt8>, _ n: UInt32) -> IOReturn

func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02X", $0) }.joined(separator: " ") }
let vcp: UInt8 = UInt8(CommandLine.arguments.dropFirst().first.flatMap { UInt8($0, radix: 16) } ?? 0x10)

var it: io_iterator_t = 0
IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &it)
var av: CFTypeRef?
while case let s = IOIteratorNext(it), s != 0 {
    if (IORegistryEntryCreateCFProperty(s, "Location" as CFString, nil, 0)?.takeRetainedValue() as? String) == "External" {
        av = IOAVServiceCreateWithService(kCFAllocatorDefault, s)?.takeRetainedValue()
    }
}
guard let av else { print("no external AV service"); exit(1) }

let req: [UInt8] = { var p: [UInt8] = [0x82, 0x01, vcp]; p.append(p.reduce(0x6E ^ 0x51, ^)); return p }()
print("request \(hex(req))")
var hits = 0
for readOff: UInt32 in [0x51, 0x00, 0x50, 0x6F] {
    for cycles in [1, 2, 3] {
        for (wSleep, rSleep) in [(10, 50), (20, 100), (50, 200)] as [(UInt32, UInt32)] {
            for len in [11, 12, 16] {
                var buf = [UInt8](repeating: 0, count: len)
                var wr: IOReturn = 0
                for _ in 0..<cycles { usleep(wSleep * 1000); wr = IOAVServiceWriteI2C(av, 0x37, 0x51, req, UInt32(req.count)) }
                usleep(rSleep * 1000)
                let rr = IOAVServiceReadI2C(av, 0x37, readOff, &buf, UInt32(len))
                let ok = buf.count >= 11 && buf[0] == 0x6E && buf[1] == 0x88 && buf[2] == 0x02 && buf[4] == vcp
                if ok { hits += 1 }
                print(String(format: "off=0x%02X cyc=%d w=%3u r=%3u len=%2d wr=%X rr=%X %@ %@", readOff, cycles, wSleep, rSleep, len,
                             UInt32(bitPattern: wr), UInt32(bitPattern: rr), ok ? "HIT " : "    ", hex(buf)))
                usleep(60_000)
            }
        }
    }
}
print("hits: \(hits)")
