import Foundation
import SwiftUI

enum FlashcardStyle: String, CaseIterable {
    case crayon
    case doodle
    case pencil
    case simple
    case watercolor
    case mosaic
    case elvish
    case pastel
    case clay
    case chalk
    case sticker
    case pixel

    var title: String {
        rawValue.capitalized
    }

    static let noImageToken = "none"
    private static let legacyRandomToken = "random"

    static func pool(from rawValue: String) -> Set<FlashcardStyle> {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalized.isEmpty || normalized == noImageToken {
            return []
        }

        if normalized == legacyRandomToken {
            return Set(allCases)
        }

        if normalized.contains(",") {
            let styles = normalized
                .split(separator: ",")
                .compactMap { FlashcardStyle(rawValue: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            return Set(styles)
        }

        if let style = FlashcardStyle(rawValue: normalized) {
            return [style]
        }

        return []
    }

    static func serializedPool(_ styles: Set<FlashcardStyle>) -> String {
        guard !styles.isEmpty else { return noImageToken }
        return styles.map(\.rawValue).sorted().joined(separator: ",")
    }

    static func randomStyle(from styles: Set<FlashcardStyle>) -> FlashcardStyle? {
        styles.randomElement()
    }
}

private let flashcardVideoFileExtensions = ["mp4", "mov", "m4v", "webm"]

extension URL {
    var isFlashcardVideoFile: Bool {
        flashcardVideoFileExtensions.contains(pathExtension.lowercased())
    }
}

extension UserDefaults {
    var flashcardStylePool: Set<FlashcardStyle> {
        get {
            let rawValue = string(forKey: "flashcardStyle") ?? FlashcardStyle.noImageToken
            return FlashcardStyle.pool(from: rawValue)
        }
        set {
            set(FlashcardStyle.serializedPool(newValue), forKey: "flashcardStyle")
        }
    }
}

extension RandomWord {
    func flashcardImage(style: FlashcardStyle?) -> Image? {
        guard let style, !english.isEmpty else { return nil }

        // Check if this is a color word and generate color square on-the-fly
        if let colorImage = generateColorImage(for: english.lowercased(), clarification: clarification) {
            return colorImage
        }

        if let selection = FlashcardAssetStore.shared.imageSelection(for: self, style: style),
           let nsImage = NSImage(contentsOf: selection.url) {
            return Image(nsImage: nsImage)
        }
        return nil
    }

    func flashcardVideoURL(style: FlashcardStyle?) -> URL? {
        guard let style, !english.isEmpty else { return nil }

        let sanitizedEnglish = english.lowercased().replacingOccurrences(of: " ", with: "_")
        let styledBaseName = "\(style.rawValue)_\(sanitizedEnglish)"

        if let styleSpecificURL = locateFlashcardVideo(
            baseName: styledBaseName,
            style: style
        ) {
            return styleSpecificURL
        }

        return locateFlashcardVideo(baseName: sanitizedEnglish, style: style)
    }

    private func locateFlashcardVideo(baseName: String, style: FlashcardStyle) -> URL? {
        let candidateDirectories = [
            "Resources/FlashcardVideos/\(style.rawValue)",
            "FlashcardVideos/\(style.rawValue)",
            "Resources/FlashcardVideos",
            "FlashcardVideos",
            "Resources/FlashcardVideos/demo",
            "FlashcardVideos/demo",
            "Resources",
        ]

        for ext in flashcardVideoFileExtensions {
            if let url = Bundle.main.url(forResource: baseName, withExtension: ext) {
                return url
            }

            for directory in candidateDirectories {
                if let url = Bundle.main.url(
                    forResource: baseName,
                    withExtension: ext,
                    subdirectory: directory
                ) {
                    return url
                }
            }
        }

        guard let resourcePath = Bundle.main.resourcePath else { return nil }

        for directory in candidateDirectories {
            for ext in flashcardVideoFileExtensions {
                let fullPath = "\(resourcePath)/\(directory)/\(baseName).\(ext)"
                if FileManager.default.fileExists(atPath: fullPath) {
                    return URL(fileURLWithPath: fullPath)
                }
            }
        }

        return nil
    }

    private func generateColorImage(for word: String, clarification: String?) -> Image? {
        if let clarification, !clarification.isEmpty, clarification.lowercased() != "color" {
            return nil
        }
        // Define color mappings
        let colorMap: [String: NSColor] = [
            "red": NSColor(red: 220/255, green: 38/255, blue: 38/255, alpha: 1.0),
            "blue": NSColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0),
            "green": NSColor(red: 22/255, green: 163/255, blue: 74/255, alpha: 1.0),
            "yellow": NSColor(red: 234/255, green: 179/255, blue: 8/255, alpha: 1.0),
            "orange": NSColor(red: 234/255, green: 88/255, blue: 12/255, alpha: 1.0),
            "purple": NSColor(red: 147/255, green: 51/255, blue: 234/255, alpha: 1.0),
            "pink": NSColor(red: 219/255, green: 39/255, blue: 119/255, alpha: 1.0),
            "brown": NSColor(red: 120/255, green: 53/255, blue: 15/255, alpha: 1.0),
            "black": NSColor(red: 0, green: 0, blue: 0, alpha: 1.0),
            "white": NSColor(red: 1, green: 1, blue: 1, alpha: 1.0),
            "gray": NSColor(red: 107/255, green: 114/255, blue: 128/255, alpha: 1.0),
            "grey": NSColor(red: 107/255, green: 114/255, blue: 128/255, alpha: 1.0), // Alternative spelling
        ]

        guard let color = colorMap[word] else { return nil }

        // Generate a simple colored square
        let size = NSSize(width: 800, height: 800)
        let image = NSImage(size: size)

        image.lockFocus()

        // Fill with color
        color.setFill()
        NSRect(x: 0, y: 0, width: 800, height: 800).fill()

        // Add a subtle border for white to show edges
        if word == "white" {
            let borderColor = NSColor(red: 220/255, green: 220/255, blue: 220/255, alpha: 1.0)
            borderColor.setStroke()
            let borderPath = NSBezierPath(rect: NSRect(x: 10, y: 10, width: 780, height: 780))
            borderPath.lineWidth = 10
            borderPath.stroke()
        }

        image.unlockFocus()

        return Image(nsImage: image)
    }
} 
