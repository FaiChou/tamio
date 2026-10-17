//
//  Bridge.swift
//  MacBridge
//
//  AppKit for the Catalyst app: loaded from Contents/PlugIns at launch. SwiftUI
//  is out of reach here (a Catalyst process carries the iOS one), so this is
//  plain AppKit, and views with content come from the app as UIKit windows.
//

import AppKit
import ObjectiveC

@objc(Bridge) final class Bridge: NSObject, MacBridging {
    var statusItems: [String: StatusItem] = [:]
    /// Keeps the toolbar strips of the main windows in step with the appearance.
    var appearanceObservers: [NSKeyValueObservation] = []
    /// Resize notifications of the main windows, for the same purpose.
    var windowObservers: [NSObjectProtocol] = []
    var mayTerminate: (() -> Bool)?
    var openApp: (() -> Void)?
    /// Windows that existed before a popover's window was asked for.
    var windowsBeforePopover: Set<ObjectIdentifier>?
    var updateObserver: NSObjectProtocol?
    /// Sparkle's updater and its standard windows, once started.
    var updaterController: AnyObject?
    var updateReminders: AnyObject?

    override required init() {
        super.init()
    }

    // MARK: Application

    func setAppearance(_ name: String?) {
        switch name {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
        for item in statusItems.values { item.popover?.appearance = NSApp.appearance }
    }

    func setTerminationGuard(_ mayTerminate: @escaping () -> Bool) {
        let install = self.mayTerminate == nil
        self.mayTerminate = mayTerminate
        if install { installTerminationGuard() }
    }

    /// UIKit owns the application delegate; its answer to "should terminate"
    /// is wrapped rather than replaced.
    private func installTerminationGuard() {
        guard let delegate = NSApp.delegate else { return }
        let selector = #selector(NSApplicationDelegate.applicationShouldTerminate(_:))
        let cls: AnyClass = type(of: delegate)
        typealias Original = @convention(c) (AnyObject, Selector, NSApplication) -> NSApplication.TerminateReply
        let original = class_getInstanceMethod(cls, selector).map {
            unsafeBitCast(method_getImplementation($0), to: Original.self)
        }
        let block: @convention(block) (AnyObject, NSApplication) -> NSApplication.TerminateReply = { [weak self] receiver, app in
            if let mayTerminate = self?.mayTerminate, !mayTerminate() { return .terminateCancel }
            return original?(receiver, selector, app) ?? .terminateNow
        }
        let implementation = imp_implementationWithBlock(block)
        if !class_addMethod(cls, selector, implementation, "Q@:@"),
           let method = class_getInstanceMethod(cls, selector)
        {
            method_setImplementation(method, implementation)
        }
    }

    func terminate() {
        NSApp.terminate(nil)
    }

    func activate(window uiWindow: AnyObject?) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let window = uiWindow.flatMap(nsWindow(for:)) ?? ordinaryWindows.first
        window?.makeKeyAndOrderFront(nil)
    }

    func hasVisibleWindow() -> Bool {
        ordinaryWindows.contains { $0.isVisible }
    }

    func setAccessory(_ accessory: Bool) {
        let policy: NSApplication.ActivationPolicy = accessory ? .accessory : .regular
        if NSApp.activationPolicy() != policy { NSApp.setActivationPolicy(policy) }
    }
}
