import AppKit
import CoreGraphics
import ScreenCaptureKit

enum CaptureService {
    private static let cropWidth: CGFloat = 800
    private static let cropHeight: CGFloat = 500

    static func mousePosition() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    static func hasScreenRecordingAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func captureMainDisplay() async throws -> CGImage {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: false
            )
        } catch {
            throw CaptureError.captureFailed(error.localizedDescription)
        }

        let mainID = CGMainDisplayID()
        guard let display = content.displays.first(where: { $0.displayID == mainID })
                ?? content.displays.first
        else {
            throw CaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.scalesToFit = false
        config.showsCursor = true

        do {
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            let hint = hasScreenRecordingAccess()
                ? "Capture failed: \(error.localizedDescription)"
                : "Screen Recording not active for this Talkshot build. Remove Talkshot from Screen Recording, reopen the app, and re-enable it."
            throw CaptureError.captureFailed(hint)
        }
    }

    static func captureAndSave(
        shotPath: URL,
        cropPath: URL,
        mousePoints: CGPoint
    ) async throws {
        let cgImage = try await captureMainDisplay()
        try saveAnnotated(cgImage: cgImage, shotPath: shotPath, cropPath: cropPath, mousePoints: mousePoints)
    }

    static func saveAnnotated(
        cgImage: CGImage,
        shotPath: URL,
        cropPath: URL,
        mousePoints: CGPoint
    ) throws {
        let displayBounds = CGDisplayBounds(CGMainDisplayID())
        let scale = CGFloat(cgImage.width) / displayBounds.width
        let px = mousePoints.x * scale
        let py = mousePoints.y * scale

        let annotated = drawCircle(on: cgImage, centerX: px, centerY: py, scale: scale)
        try writePNG(annotated, to: shotPath)

        let cropW = cropWidth * scale
        let cropH = cropHeight * scale
        let left = min(max(0, px - cropW / 2), CGFloat(cgImage.width) - cropW)
        let top = min(max(0, py - cropH / 2), CGFloat(cgImage.height) - cropH)
        let cropRect = CGRect(x: left, y: top, width: cropW, height: cropH)

        guard let cropped = annotated.cropping(to: cropRect) else {
            throw CaptureError.invalidImage
        }
        try writePNG(cropped, to: cropPath)
    }

    private static func drawCircle(on image: CGImage, centerX: CGFloat, centerY: CGFloat, scale: CGFloat) -> CGImage {
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let radius = 18 * scale
        let lineWidth = max(2, 4 * scale)
        context.setStrokeColor(NSColor.red.cgColor)
        context.setLineWidth(lineWidth)
        context.addEllipse(in: CGRect(
            x: centerX - radius,
            y: CGFloat(height) - centerY - radius,
            width: radius * 2,
            height: radius * 2
        ))
        context.strokePath()

        return context.makeImage() ?? image
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw CaptureError.invalidImage
        }
        try data.write(to: url)
    }

    enum CaptureError: LocalizedError {
        case captureFailed(String)
        case noDisplay
        case invalidImage

        var errorDescription: String? {
            switch self {
            case .captureFailed(let message):
                return message
            case .noDisplay:
                return "No display found for screenshot."
            case .invalidImage:
                return "Could not process screenshot image."
            }
        }
    }
}
