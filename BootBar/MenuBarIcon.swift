import AppKit

enum MenuBarIcon {
    static func image(count: Int) -> NSImage {
        let symbol = NSImage(systemSymbolName: "iphone.gen3", accessibilityDescription: "Devices")
            ?? NSImage(size: NSSize(width: 16, height: 16))
        guard count > 0 else {
            symbol.isTemplate = true
            return symbol
        }

        let text = "\(count)" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.black
        ]
        let textSize = text.size(withAttributes: attributes)
        let spacing: CGFloat = 3
        let size = NSSize(width: symbol.size.width + spacing + ceil(textSize.width),
                          height: max(symbol.size.height, ceil(textSize.height)))

        let composed = NSImage(size: size, flipped: false) { _ in
            symbol.draw(at: NSPoint(x: 0, y: (size.height - symbol.size.height) / 2),
                        from: .zero, operation: .sourceOver, fraction: 1)
            text.draw(at: NSPoint(x: symbol.size.width + spacing,
                                  y: (size.height - textSize.height) / 2),
                      withAttributes: attributes)
            return true
        }
        composed.isTemplate = true
        return composed
    }
}
