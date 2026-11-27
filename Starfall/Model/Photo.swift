import UIKit
import CoreImage

/// Non-destructive edits on top of the cropped photo, saved so you can come back and change them.
struct PhotoEdit: Codable, Hashable {
    var brightness = 0.0   // -0.3 … 0.3
    var contrast = 1.0     //  0.6 … 1.6
    var saturation = 1.0   //  0 … 2
    var warmth = 0.0       // -1 … 1
    var look: Look = .original

    enum Look: String, Codable, CaseIterable, Identifiable {
        case original, mono, noir, fade, chrome, instant
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        var filter: String? {
            switch self {
            case .original: return nil
            case .mono: return "CIPhotoEffectMono"
            case .noir: return "CIPhotoEffectNoir"
            case .fade: return "CIPhotoEffectFade"
            case .chrome: return "CIPhotoEffectChrome"
            case .instant: return "CIPhotoEffectInstant"
            }
        }
    }
}

enum PhotoLab {
    private static let context = CIContext()

    /// Render the square crop the person framed: `side` is the on-screen crop size in points,
    /// `zoom` and `offset` are what they set with pinch and drag.
    static func crop(_ image: UIImage, side: CGFloat, zoom: CGFloat, offset: CGSize, output: CGFloat = 1024) -> UIImage {
        let w = max(1, image.size.width), h = max(1, image.size.height)
        let base = max(side / w, side / h) * zoom
        let dw = w * base, dh = h * base
        let k = output / side
        let rect = CGRect(x: ((side - dw) / 2 + offset.width) * k, y: ((side - dh) / 2 + offset.height) * k,
                          width: dw * k, height: dh * k)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: output, height: output), format: fmt).image { _ in
            image.draw(in: rect)
        }
    }

    static func apply(_ e: PhotoEdit, to image: UIImage) -> UIImage {
        guard let input = CIImage(image: image) else { return image }
        let extent = input.extent
        var ci = input
        if let f = CIFilter(name: "CIColorControls") {
            f.setValue(ci, forKey: kCIInputImageKey)
            f.setValue(e.brightness, forKey: kCIInputBrightnessKey)
            f.setValue(e.contrast, forKey: kCIInputContrastKey)
            f.setValue(e.saturation, forKey: kCIInputSaturationKey)
            if let o = f.outputImage { ci = o }
        }
        if abs(e.warmth) > 0.01, let f = CIFilter(name: "CITemperatureAndTint") {
            f.setValue(ci, forKey: kCIInputImageKey)
            f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            f.setValue(CIVector(x: 6500 - e.warmth * 2000, y: 0), forKey: "inputTargetNeutral")
            if let o = f.outputImage { ci = o }
        }
        if let name = e.look.filter, let f = CIFilter(name: name) {
            f.setValue(ci, forKey: kCIInputImageKey)
            if let o = f.outputImage { ci = o }
        }
        guard let cg = context.createCGImage(ci.cropped(to: extent), from: extent) else { return image }
        return UIImage(cgImage: cg)
    }

    /// A smaller copy for fast live previews while sliders move.
    static func downscaled(_ image: UIImage, to side: CGFloat) -> UIImage {
        let s = min(1, side / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * s, height: image.size.height * s)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}
