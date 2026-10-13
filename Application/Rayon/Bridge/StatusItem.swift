//
//  StatusItem.swift
//  MacBridge
//
//  One menu bar item: an animated image, a two-line title, and a popover whose
//  content is a UIKit window's, moved here from the window UIKit made for it.
//

import AppKit

final class StatusItem: NSObject, NSPopoverDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let frames: [NSImage]
    let idleFrame: NSImage?
    let onClick: () -> Void
    /// Shows the main window; the item's menu offers it with Quit, which a
    /// Rayon that lives only in the menu bar has nowhere else.
    var onOpenApp: (() -> Void)?

    var popover: NSPopover?
    /// The window UIKit made for the popover's content. It stays open, unseen:
    /// UIKit stops drawing the content of a window that is ordered out.
    var donor: NSWindow?
    var didClose: (() -> Void)?
    private var holder: NSView?
    private var outsideClicks: Any?

    private var frameIndex = 0
    private var interval: Double = 0
    private var timer: Timer?

    init(toolTip: String, frames: [AnyObject], idleFrame: AnyObject?, onClick: @escaping () -> Void) {
        self.frames = frames.compactMap(Self.templateImage)
        self.idleFrame = idleFrame.flatMap(Self.templateImage)
        self.onClick = onClick
        super.init()
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.imagePosition = .imageLeading
        item.button?.toolTip = toolTip
        item.button?.image = self.idleFrame
    }

    private static func templateImage(_ object: AnyObject) -> NSImage? {
        guard CFGetTypeID(object) == CGImage.typeID else { return nil }
        let cgImage = object as! CGImage
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width / 2, height: cgImage.height / 2))
        image.isTemplate = true
        return image
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp || NSEvent.modifierFlags.contains(.control) {
            showMenu()
        } else {
            onClick()
        }
    }

    private func showMenu() {
        close()
        let menu = NSMenu()
        menu.addItem(withTitle: "Open catussh", action: #selector(openApp), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit catussh", action: #selector(quit), keyEquivalent: "q").target = self
        // Shown for this click only, so a left click still opens the popover.
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func openApp() {
        onOpenApp?()
    }

    @objc private func quit() {
        // The termination guard may ask first; its alert needs Rayon in front.
        NSApp.activate(ignoringOtherApps: true)
        NSApp.terminate(nil)
    }

    func remove() {
        timer?.invalidate()
        stopWatchingOutsideClicks()
        popover?.close()
        donor?.close()
        NSStatusBar.system.removeStatusItem(item)
    }

    // MARK: Image and title

    func update(title: String, frameInterval: Double) {
        guard let button = item.button else { return }
        if title.isEmpty {
            button.attributedTitle = NSAttributedString(string: "")
        } else {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .right
            paragraph.maximumLineHeight = 10
            paragraph.minimumLineHeight = 10
            button.attributedTitle = NSAttributedString(
                string: title,
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium),
                    .paragraphStyle: paragraph,
                    .baselineOffset: -5,
                ]
            )
        }
        guard frameInterval != interval else { return }
        interval = frameInterval
        timer?.invalidate()
        timer = nil
        guard frameInterval > 0, !frames.isEmpty else {
            button.image = idleFrame
            return
        }
        let timer = Timer(timeInterval: frameInterval, repeats: true) { [weak self] _ in self?.nextFrame() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        nextFrame()
    }

    private func nextFrame() {
        frameIndex = (frameIndex + 1) % frames.count
        item.button?.image = frames[frameIndex]
    }

    // MARK: Popover

    func attach(donor window: NSWindow, size: NSSize) {
        guard let content = window.contentView else { return }
        donor = window
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.transient, .ignoresCycle, .fullScreenNone]
        window.isExcludedFromWindowsMenu = true

        let holder = NSView(frame: NSRect(origin: .zero, size: size))
        window.contentView = NSView()
        content.frame = holder.bounds
        content.autoresizingMask = [.width, .height]
        // The backdrop put in while this was an ordinary window draws the
        // window material; the popover's own goes below the content instead.
        content.subviews.filter { $0 is NSVisualEffectView }.forEach { $0.removeFromSuperview() }
        holder.addSubview(content)
        self.holder = holder
        installBackdrop()

        let controller = NSViewController()
        controller.view = holder
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = size
        popover.contentViewController = controller
        popover.delegate = self
        self.popover = popover
    }

    /// The window material behind the popover's content, as in Rayon's windows.
    func installBackdrop() {
        guard let holder, !holder.subviews.contains(where: { $0 is NSVisualEffectView }) else { return }
        let backdrop = Bridge.makeBackdrop(frame: holder.bounds)
        // As in an AppKit popover, whose window is never the main one: the
        // material at rest, whichever app is in front.
        backdrop.state = .inactive
        holder.addSubview(backdrop, positioned: .below, relativeTo: nil)
    }

    func toggle() {
        guard let popover else { return }
        if popover.isShown { close() } else { show() }
    }

    func show() {
        guard let popover, let button = item.button else { return }
        // A menu bar popover takes the menu bar's appearance, which follows the
        // wallpaper; use Rayon's Light / Dark / System choice instead so the
        // cards look as they do in the window.
        popover.appearance = NSApp.appearance ?? NSApp.effectiveAppearance
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    func close() {
        popover?.performClose(nil)
        stopWatchingOutsideClicks()
    }

    func popoverDidClose(_: Notification) {
        stopWatchingOutsideClicks()
        didClose?()
    }

    private func stopWatchingOutsideClicks() {
        if let outsideClicks { NSEvent.removeMonitor(outsideClicks) }
        outsideClicks = nil
    }
}
