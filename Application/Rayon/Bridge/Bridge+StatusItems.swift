//
//  Bridge+StatusItems.swift
//  MacBridge
//

import AppKit

extension Bridge {
    func addStatusItem(_ id: String, toolTip: String, frames: [String], idleFrame: String, onClick: @escaping () -> Void) {
        statusItems[id]?.remove()
        let item = StatusItem(toolTip: toolTip, frames: frames, idleFrame: idleFrame, onClick: onClick)
        // The popover's hidden window must not keep the keyboard once it closes.
        item.didClose = { [weak self, weak item] in
            guard let self, NSApp.isActive, NSApp.keyWindow == nil || NSApp.keyWindow === item?.donor else { return }
            self.ordinaryWindows.first { $0.isVisible }?.makeKey()
        }
        item.onOpenApp = { [weak self] in self?.openApp?() }
        statusItems[id] = item
    }

    func setOpenAppHandler(_ handler: @escaping () -> Void) {
        openApp = handler
    }

    func updateStatusItem(_ id: String, title: String, frameInterval: Double) {
        statusItems[id]?.update(title: title, frameInterval: frameInterval)
    }

    func removeStatusItem(_ id: String) {
        statusItems.removeValue(forKey: id)?.remove()
    }

    func prepareForPopoverWindow() {
        windowsBeforePopover = Set(NSApp.windows.map(ObjectIdentifier.init))
        guard updateObserver == nil else { return }
        // Posted on every pass of the event loop: the new window is caught
        // before it is drawn.
        updateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didUpdateNotification, object: nil, queue: nil
        ) { [weak self] _ in
            self?.hideNewWindows()
        }
        // If the window never comes, stop looking for it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.stopHidingNewWindows() }
    }

    private func hideNewWindows() {
        guard let known = windowsBeforePopover else { return }
        for window in NSApp.windows
            where !known.contains(ObjectIdentifier(window)) && window.className.contains("UINSWindow")
        {
            window.alphaValue = 0
            window.hasShadow = false
            window.ignoresMouseEvents = true
        }
    }

    private func stopHidingNewWindows() {
        windowsBeforePopover = nil
        if let updateObserver { NotificationCenter.default.removeObserver(updateObserver) }
        updateObserver = nil
    }

    func attachPopover(_ id: String, window uiWindow: AnyObject, width: Double, height: Double) -> Bool {
        guard let item = statusItems[id], let window = nsWindow(for: uiWindow) else { return false }
        stopHidingNewWindows()
        item.attach(donor: window, size: NSSize(width: width, height: height))
        return true
    }

    func hasPopover(_ id: String) -> Bool {
        statusItems[id]?.popover != nil
    }

    func togglePopover(_ id: String) {
        statusItems[id]?.toggle()
    }

    func closePopover(_ id: String) {
        statusItems[id]?.close()
    }
}
