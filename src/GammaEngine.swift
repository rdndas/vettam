// GammaEngine.swift — High-performance GPU Lookup Table Controller
// Zero window overlays. Pure hardware-accelerated color transfer curves.
// Features: Brightness, S-Curve Contrast, Color Warmth (Kelvin), Monochrome Mode.

import Foundation
import CoreGraphics

public final class GammaEngine {
    public static let shared = GammaEngine()
    private let tableSize: Int = 256

    private init() {}

    public func apply(
        display: CGDirectDisplayID,
        brightness: Float,     // 0.0 ... 1.0
        contrast: Float,       // 0.0 ... 1.0 (0.5 = neutral)
        kelvin: Float,         // 3000 ... 6500
        isMonochrome: Bool
    ) {
        var red = [CGGammaValue](repeating: 0, count: tableSize)
        var green = [CGGammaValue](repeating: 0, count: tableSize)
        var blue = [CGGammaValue](repeating: 0, count: tableSize)

        // Safety floor: map 0.0...1.0 slider to 0.06...1.0 luminance so 0% never turns off screen
        let effectiveBrightness: Float = 0.06 + (brightness * 0.94)

        // Calculate Color Temperature multipliers (Kelvin to RGB gains)
        let (rGain, gGain, bGain) = kelvinToRGBMultipliers(kelvin: kelvin)

        for i in 0..<tableSize {
            let normalizedInput = Float(i) / Float(tableSize - 1)

            // 1. Contrast Transformation (S-curve around midpoint 0.5)
            let contrastSlope = pow(2.0, (contrast - 0.5) * 2.5)
            var postContrast = (normalizedInput - 0.5) * contrastSlope + 0.5
            postContrast = min(max(postContrast, 0.0), 1.0)

            // 2. Brightness Scaling (Luminance Scaling with safety floor)
            let postBrightness = postContrast * effectiveBrightness

            // 3. Color Temperature attenuation
            var r = postBrightness * rGain
            var g = postBrightness * gGain
            var b = postBrightness * bGain

            // 4. Monochrome / Paper Mode (Rec. 709 Luminance weights)
            if isMonochrome {
                let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
                r = lum
                g = lum
                b = lum
            }

            red[i] = CGGammaValue(min(max(r, 0.0), 1.0))
            green[i] = CGGammaValue(min(max(g, 0.0), 1.0))
            blue[i] = CGGammaValue(min(max(b, 0.0), 1.0))
        }

        CGSetDisplayTransferByTable(display, UInt32(tableSize), red, green, blue)
    }

    public func restoreOriginal() {
        CGDisplayRestoreColorSyncSettings()
    }

    private func kelvinToRGBMultipliers(kelvin: Float) -> (Float, Float, Float) {
        if kelvin >= 6500 {
            return (1.0, 1.0, 1.0)
        }
        let t = (kelvin - 3000.0) / (6500.0 - 3000.0)
        let r: Float = 1.0
        let g: Float = 0.75 + (0.25 * t)
        let b: Float = 0.40 + (0.60 * pow(t, 1.2))
        return (r, g, b)
    }
}
