// ddc_bus.swift — bus-level sanity checks: passive read, EDID over I2C, capabilities request
import Foundation
import IOKit

@_silgen_name("IOAVServiceCreateWithService")
func IOAVServiceCreateWithService(_ a: CFAllocator?, _ s: io_service_t) -> Unmanaged<CFTypeRef>?
@_silgen_name("IOAVServiceWriteI2C")
func IOAVServiceWriteI2C(_ s: CFTypeRef, _ c: UInt32, _ d: UInt32, _ b: UnsafePointer<UInt8>, _ n: UInt32) -> IOReturn
@_silgen_name("IOAVServiceReadI2C")
func IOAVServiceReadI2C(_ s: CFTypeRef, _ c: UInt32, _ o: UInt32, _ b: UnsafeMutablePointer<UInt8>, _ n: UInt32) -> IOReturn

func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02X", $0) }.joined(separator: " ") }
var it: io_iterator_t = 0
IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &it)
var av: CFTypeRef?
while case let s = IOIteratorNext(it), s != 0 {
    if (IORegistryEntryCreateCFProperty(s, "Location" as CFString, nil, 0)?.takeRetainedValue() as? String) == "External" {
        av = IOAVServiceCreateWithService(kCFAllocatorDefault, s)?.takeRetainedValue()
    }
}
guard let av else { print("no external AV service"); exit(1) }

func rd(_ chip: UInt32, _ off: UInt32, _ n: Int) -> String {
    var b = [UInt8](repeating: 0xAA, count: n)
    let r = IOAVServiceReadI2C(av, chip, off, &b, UInt32(n))
    return String(format: "rr=0x%X ", UInt32(bitPattern: r)) + hex(b)
}
print("1) passive read 0x37 (no request):     ", rd(0x37, 0x51, 12))
print("   passive read 0x37 off 0:            ", rd(0x37, 0, 12))
print("2) EDID chip 0x50 off 0 (32B):         ", rd(0x50, 0, 32))
print("   EDID chip 0x50 off 0x80 (16B):      ", rd(0x50, 0x80, 16))
print("3) nonexistent chip 0x3A:              ", rd(0x3A, 0, 8))
for (name, p) in [("caps 0xF3 @0", [0x83, 0xF3, 0x00, 0x00] as [UInt8]), ("timing 0x07", [0x81, 0x07]), ("get 0xDF", [0x82, 0x01, 0xDF]), ("get 0xC9", [0x82, 0x01, 0xC9])] {
    var f = p; f.append(f.reduce(0x6E ^ 0x51, ^))
    let w = IOAVServiceWriteI2C(av, 0x37, 0x51, f, UInt32(f.count))
    usleep(100_000)
    print("4) \(name) TX \(hex(f)) wr=0x\(String(UInt32(bitPattern: w), radix: 16)) ->", rd(0x37, 0x51, 38))
    usleep(60_000)
}
