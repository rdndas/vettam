// StatusItemIconHelper.swift — Authentic vettam_template Template Icon
import AppKit

public final class StatusItemIconHelper {
    /// Loads the authentic template icon with Retina (@2x) support
    public static func makeVettamTemplateIcon() -> NSImage {
        let bundle = Bundle.main
        let imageURL_2x = bundle.url(forResource: "vettam_template@2x", withExtension: "png")
            ?? URL(fileURLWithPath: "resources/vettam_template@2x.png")
        let imageURL_1x = bundle.url(forResource: "vettam_template", withExtension: "png")
            ?? URL(fileURLWithPath: "resources/vettam_template.png")

        let image = NSImage(size: NSSize(width: 25, height: 18))
        
        if let rep2xData = try? Data(contentsOf: imageURL_2x),
           let rep2x = NSBitmapImageRep(data: rep2xData) {
            rep2x.size = NSSize(width: 25, height: 18)
            image.addRepresentation(rep2x)
        }
        if let rep1xData = try? Data(contentsOf: imageURL_1x),
           let rep1x = NSBitmapImageRep(data: rep1xData) {
            rep1x.size = NSSize(width: 25, height: 18)
            image.addRepresentation(rep1x)
        }

        image.isTemplate = true // Auto-adapts to macOS Light and Dark mode
        return image
    }
}
