//
//  Bridge+Windows.swift
//  MacBridge
//

import AppKit

extension Bridge {
    /// The AppKit window UIKit made for a UIWindow.
    func nsWindow(for uiWindow: AnyObject) -> NSWindow? {
        let selector = NSSelectorFromString("uiWindows")
        for window in NSApp.windows where window.responds(to: selector) {
            if let hosted = window.perform(selector)?.takeUnretainedValue() as? [AnyObject],
               hosted.contains(where: { $0 === uiWindow })
            {
                return window
            }
        }
        return nil
    }

    /// The app's own windows: not menu bar items, popovers, or the hidden
    /// windows whose content sits in a popover.
    var ordinaryWindows: [NSWindow] {
        let donors = Set(statusItems.values.compactMap { $0.donor.map(ObjectIdentifier.init) })
        return NSApp.windows.filter { window in
            window.className.contains("UINSWindow") && !donors.contains(ObjectIdentifier(window)) && window.alphaValue > 0
        }
    }

    func installBackdrop(for uiWindow: AnyObject) {
        guard let window = nsWindow(for: uiWindow) else {
            // UIKit makes the AppKit window a moment after the UIWindow.
            DispatchQueue.main.async { [weak self, weak uiWindow] in
                if let uiWindow { self?.installBackdrop(for: uiWindow) }
            }
            return
        }
        if let item = statusItems.values.first(where: { $0.donor === window }) {
            item.installBackdrop()
            return
        }
        guard let content = window.contentView,
              !content.subviews.contains(where: { $0 is NSVisualEffectView })
        else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        let effect = Bridge.makeBackdrop(frame: content.bounds)
        content.addSubview(effect, positioned: .below, relativeTo: nil)
    }

    /// The material of Rayon's windows: the desktop shows through, blurred.
    static func makeBackdrop(frame: NSRect) -> NSVisualEffectView {
        let effect = NSVisualEffectView(frame: frame)
        effect.autoresizingMask = [.width, .height]
        effect.material = .underWindowBackground
        effect.blendingMode = .behindWindow
        effect.state = .followsWindowActiveState
        return effect
    }
}
