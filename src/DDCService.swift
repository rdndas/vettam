// DDCService.swift — Hardware DDC/CI Service for Apple Silicon
// Implements strict hardware protection rules:
// 1. Strict VCP Whitelist (no reset/degauss/vendor codes)
// 2. Value Clamping (0...100)
// 3. Write Coalescing (120ms debounce to prevent EEPROM wear-out)
// 4. Scaler Bus Pacing (serial queue, 50ms pause between I2C ops)

import Foundation
import IOKit

// Private IOAVService bindings
@_silgen_name("IOAVServiceCreateWithService")
func IOAVServiceCreateWithService(_ allocator: CFAllocator?, _ service: io_service_t) -> Unmanaged<CFTypeRef>?

@_silgen_name("IOAVServiceWriteI2C")
func IOAVServiceWriteI2C(_ service: CFTypeRef, _ chipAddress: UInt32, _ dataAddress: UInt32, _ inputBuffer: UnsafePointer<UInt8>, _ inputBufferSize: UInt32) -> IOReturn

@_silgen_name("IOAVServiceReadI2C")
func IOAVServiceReadI2C(_ service: CFTypeRef, _ chipAddress: UInt32, _ offset: UInt32, _ outputBuffer: UnsafeMutablePointer<UInt8>, _ outputBufferSize: UInt32) -> IOReturn

public enum SafeVCPCode: UInt8 {
    case brightness = 0x10
    case contrast   = 0x12
    case colorPreset = 0x14
    case redGain    = 0x16
    case greenGain  = 0x18
    case blueGain   = 0x1A
    case inputSource = 0x60
    case audioVolume = 0x62
    case audioMute   = 0x8D
    case powerMode   = 0xD6
}

public final class DDCService {
    public static let shared = DDCService()

    private let ddcQueue = DispatchQueue(label: "luminobar.ddc.serial", qos: .userInitiated)
    private var avService: CFTypeRef?
    private var lastOperationTime: DispatchTime = .now()
    private var pendingWrites: [UInt8: UInt16] = [:]
    private var writeWorkItem: DispatchWorkItem?

    private let ddcChip: UInt32 = 0x37
    private let ddcHost: UInt32 = 0x51
    private let minOpIntervalMs: UInt64 = 50 // Scaler bus pacing delay

    private init() {
        refreshAVService()
    }

    public func refreshAVService() {
        ddcQueue.async {
            self.avService = nil
            var it: io_iterator_t = 0
            guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &it) == KERN_SUCCESS else { return }
            defer { IOObjectRelease(it) }

            while case let s = IOIteratorNext(it), s != 0 {
                if let loc = IORegistryEntryCreateCFProperty(s, "Location" as CFString, nil, 0)?.takeRetainedValue() as? String,
                   loc == "External" {
                    if let av = IOAVServiceCreateWithService(kCFAllocatorDefault, s)?.takeRetainedValue() {
                        self.avService = av
                        break
                    }
                }
            }
        }
    }

    public func isHardwareAvailable(completion: @escaping (Bool) -> Void) {
        ddcQueue.async {
            guard let av = self.avService else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            // Lightweight test: Query brightness (0x10)
            self.paceBus()
            var req: [UInt8] = [0x82, 0x01, 0x10]
            req.append(req.reduce(0x6E ^ 0x51, ^))

            _ = IOAVServiceWriteI2C(av, self.ddcChip, self.ddcHost, req, UInt32(req.count))
            usleep(50_000)

            var buf = [UInt8](repeating: 0, count: 12)
            let r = IOAVServiceReadI2C(av, self.ddcChip, self.ddcHost, &buf, 12)
            
            // Check if valid framing (not 6E 80 BE null message)
            let isWorking = (r == kIOReturnSuccess && buf[0] == 0x6E && buf[1] == 0x88 && buf[2] == 0x02 && buf[4] == 0x10)
            DispatchQueue.main.async {
                completion(isWorking)
            }
        }
    }

    /// Throttled, coalesced write to protect scaler EEPROM
    public func setCoalesced(vcp: SafeVCPCode, value: UInt16) {
        // Enforce clamping 0...100
        let clamped = min(max(value, 0), 100)

        ddcQueue.async {
            self.pendingWrites[vcp.rawValue] = clamped

            // Cancel any prior scheduled commit
            self.writeWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.flushPendingWrites()
            }
            self.writeWorkItem = workItem
            // 120ms debounce interval
            self.ddcQueue.asyncAfter(deadline: .now() + .milliseconds(120), execute: workItem)
        }
    }

    private func flushPendingWrites() {
        guard let av = avService, !pendingWrites.isEmpty else { return }
        for (vcpRaw, val) in pendingWrites {
            // Strictly reject unsafe registers
            guard let safeVCP = SafeVCPCode(rawValue: vcpRaw) else { continue }
            sendSetPacket(av: av, code: safeVCP.rawValue, val: val)
        }
        pendingWrites.removeAll()
    }

    private func sendSetPacket(av: CFTypeRef, code: UInt8, val: UInt16) {
        paceBus()
        var payload: [UInt8] = [0x84, 0x03, code, UInt8(val >> 8), UInt8(val & 0xFF)]
        var chk: UInt8 = 0x6E ^ 0x51
        for b in payload { chk ^= b }
        payload.append(chk)

        _ = IOAVServiceWriteI2C(av, ddcChip, ddcHost, payload, UInt32(payload.count))
        lastOperationTime = .now()
    }

    private func paceBus() {
        let now = DispatchTime.now()
        let elapsedNanos = now.uptimeNanoseconds - lastOperationTime.uptimeNanoseconds
        let minIntervalNanos = minOpIntervalMs * 1_000_000

        if elapsedNanos < minIntervalNanos {
            let sleepMs = UInt32((minIntervalNanos - elapsedNanos) / 1_000_000)
            usleep(sleepMs * 1000)
        }
        lastOperationTime = .now()
    }
}
