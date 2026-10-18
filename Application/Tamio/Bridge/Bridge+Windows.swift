//
//  Bridge+Windows.swift
//  MacBridge
//

import AppKit

/// Debug builds started with TAMIO_TRACE=<file> append what the window
/// watch sees to that file.
func trace(_ message: @autoclosure () -> String) {
    #if DEBUG
        guard let path = ProcessInfo.processInfo.environment["TAMIO_TRACE"], let handle = FileHandle(forWritingAtPath: path) else { return }
        handle.seekToEndOfFile()
        handle.write(Data("\(Date().timeIntervalSince1970) \(message())\n".utf8))
        handle.closeFile()
    #endif
}

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
        unifyTitlebar(of: window)
        window.isOpaque = false
        window.backgroundColor = .clear
        let effect = Bridge.makeBackdrop(frame: content.bounds)
        content.addSubview(effect, positioned: .below, relativeTo: nil)
        // The toolbar strip is outside UIKit's content, so the pages' window
        // colour stops below it and the material shows through, near white.
        // It is painted the same colour as the pages.
        let toolbarHeight = max(window.frame.height - window.contentLayoutRect.height, 0)
        if toolbarHeight > 0 {
            let strip = PaintOnlyView(frame: NSRect(
                x: 0, y: content.bounds.height - toolbarHeight,
                width: content.bounds.width, height: toolbarHeight
            ))
            strip.autoresizingMask = [.width, .minYMargin]
            strip.wantsLayer = true
            strip.layer?.backgroundColor = Bridge.windowColor.cgColor
            content.addSubview(strip, positioned: .above, relativeTo: effect)
            // The layer keeps a CGColor, which does not follow the appearance.
            appearanceObservers.append(window.observe(\.effectiveAppearance) { window, _ in
                window.effectiveAppearance.performAsCurrentDrawingAppearance {
                    strip.layer?.backgroundColor = Bridge.windowColor.cgColor
                }
            })
        }
    }

    func enforceMinimumContentSize(_ size: CGSize, of uiWindow: AnyObject) {
        guard let window = nsWindow(for: uiWindow) else {
            DispatchQueue.main.async { [weak self, weak uiWindow] in
                if let uiWindow { self?.enforceMinimumContentSize(size, of: uiWindow) }
            }
            return
        }
        window.contentMinSize = size
        let content = window.contentRect(forFrameRect: window.frame).size
        if content.width < size.width || content.height < size.height {
            window.setContentSize(NSSize(width: max(content.width, size.width), height: max(content.height, size.height)))
            // Grown upward from the bottom edge, it may now reach past the
            // top of the screen.
            if let screen = window.screen { window.constrainFrameRect(window.frame, to: screen) }
        }
    }

    /// One surface from the top edge down: the title bar draws nothing of its
    /// own, so the traffic lights and toolbar sit on the window colour like
    /// the sidebar and the page, not on a white band. Its background views are
    /// hidden instead of the title bar being made transparent: a transparent
    /// title bar passes clicks to the content under it, and Catalyst's toolbar
    /// items (New Server, search) then never get them. UIKit and AppKit bring
    /// the background back when the toolbar changes and while the window is
    /// resized, so this is applied again at once (not on the next turn of the
    /// run loop, which shows as a flicker) whenever either happens.
    func unifyTitlebar(of window: NSWindow) {
        var seen = ""
        func apply(_ window: NSWindow) {
            let state = "style \(window.toolbarStyle.rawValue) title \(window.titleVisibility.rawValue) toolbar \(window.toolbar == nil ? "none" : "present") items \(window.toolbar?.items.count ?? 0) key \(window.isKeyWindow)"
            if state != seen { seen = state; trace(state) }
            if !window.styleMask.contains(.fullSizeContentView) { window.styleMask.insert(.fullSizeContentView) }
            if window.titlebarSeparatorStyle != .none { window.titlebarSeparatorStyle = .none }
            // The title bar's own fill, a white layer in light mode.
            if let frame = window.contentView?.superview {
                Bridge.hideTitlebarBackgrounds(in: frame)
            }
        }
        apply(window)
        appearanceObservers.append(window.observe(\.titlebarAppearsTransparent) { window, _ in apply(window) })
        appearanceObservers.append(window.observe(\.styleMask) { window, _ in apply(window) })
        // didUpdate comes after every event, before the window draws: a page
        // switch rebuilds the toolbar and with it the title bar's background.
        for name in [NSWindow.willStartLiveResizeNotification, NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification, NSWindow.didUpdateNotification] {
            let token = NotificationCenter.default.addObserver(forName: name, object: window, queue: nil) { note in
                if let window = note.object as? NSWindow { apply(window) }
            }
            windowObservers.append(token)
        }
    }

    static func hideTitlebarBackgrounds(in view: NSView) {
        for sub in view.subviews {
            if String(describing: type(of: sub)) == "NSTitlebarBackgroundView" {
                if !sub.isHidden { sub.isHidden = true }
            } else if String(describing: type(of: sub)).hasPrefix("NSTitlebar") {
                hideTitlebarBackgrounds(in: sub)
            }
        }
    }

    var commandHeld: Bool { NSEvent.modifierFlags.contains(.command) }
    var shiftHeld: Bool { NSEvent.modifierFlags.contains(.shift) }
    var isFrontmost: Bool { NSApp.isActive }

    func holdNewWindowsUntilToolbar() {
        let started = Date()
        var seen = Set<ObjectIdentifier>()
        windowObservers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didUpdateNotification, object: nil, queue: nil
        ) { note in
            guard let window = note.object as? NSWindow,
                  window.className.contains("UINSWindow"),
                  seen.insert(ObjectIdentifier(window)).inserted,
                  Date().timeIntervalSince(started) < 5
            else { return }
            // Whatever its toolbar now: Catalyst can drop it as the window is
            // ordered on screen. watchToolbar shows the window once it settles.
            window.alphaValue = 0
        })
    }

    /// Catalyst builds the window's AppKit toolbar out of the pages'
    /// navigation bar. Without it the sidebar keeps a navigation bar of its
    /// own: the collapse button goes on a second row and everything moves
    /// down. A new window is kept transparent until its toolbar is there (or
    /// for two seconds, whatever happens), so that layout is never seen.
    ///
    /// Catalyst dropped the toolbar whenever the window sat exactly at the
    /// content's minimum frame; the content no longer has one (see
    /// MainView). Nothing short of the app being hidden and reopened brings
    /// a dropped toolbar back, and rebuilding the pages only made them
    /// flicker, so the watch does not try.
    func watchToolbar(of uiWindow: AnyObject) {
        guard let window = nsWindow(for: uiWindow) else {
            DispatchQueue.main.async { [weak self, weak uiWindow] in
                if let uiWindow { self?.watchToolbar(of: uiWindow) }
            }
            return
        }
        var revealing = false
        let launched = Date()
        func check() {
            if window.toolbar == nil, Date().timeIntervalSince(launched) < 2, window.alphaValue > 0 {
                window.alphaValue = 0
            }
            guard window.toolbar != nil, window.alphaValue < 1, !revealing else { return }
            // Shown once on screen with its toolbar kept a moment: it can
            // still go as the window is ordered front.
            revealing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                revealing = false
                guard window.toolbar != nil, window.isVisible else { return check() }
                NSAnimationContext.runAnimationGroup { $0.duration = 0.12; window.animator().alphaValue = 1 }
            }
        }
        if window.toolbar == nil { window.alphaValue = 0 }
        appearanceObservers.append(window.observe(\.toolbar) { window, _ in
            trace("toolbar \(window.toolbar == nil ? "gone" : "present") size \(Int(window.frame.width))x\(Int(window.frame.height)) t+\(String(format: "%.1f", Date().timeIntervalSince(launched)))s")
            DispatchQueue.main.async { check() }
        })
        // Shown after two seconds whatever happens.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if window.alphaValue < 1 { window.alphaValue = 1 }
        }
        check()
    }

    /// TamioDesign's `RXPalette.window`, the colour the pages are drawn on.
    static let windowColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0x1B / 255, green: 0x1C / 255, blue: 0x1F / 255, alpha: 1)
            : NSColor(srgbRed: 0xEE / 255, green: 0xF0 / 255, blue: 0xF5 / 255, alpha: 1)
    }

    /// The material of Tamio's windows: the desktop shows through, blurred.
    static func makeBackdrop(frame: NSRect) -> NSVisualEffectView {
        let effect = NSVisualEffectView(frame: frame)
        effect.autoresizingMask = [.width, .height]
        effect.material = .underWindowBackground
        effect.blendingMode = .behindWindow
        effect.state = .followsWindowActiveState
        return effect
    }
}

/// Paints and nothing else: clicks go through it to the toolbar items it
/// lies under (or over, as Catalyst orders the window's views).
private final class PaintOnlyView: NSView {
    override func hitTest(_: NSPoint) -> NSView? { nil }
}
