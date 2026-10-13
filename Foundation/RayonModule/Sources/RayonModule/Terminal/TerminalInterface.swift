//
//  TerminalInterface.swift
//  RayonModule
//
//  Platform UI handler used by the shared terminal session core. Each app
//  registers its implementation before any session starts.
//

import Foundation

public protocol TerminalUIHandler: AnyObject {
    /// Called on the first connection bootstrap when the store asks to open
    /// interfaces automatically; iOS uses it to auto-present the terminal.
    /// Called on the main thread.
    func autoOpenInterface(_ context: TerminalContext)
}

public extension TerminalUIHandler {
    func autoOpenInterface(_: TerminalContext) {}
}

private final class DefaultTerminalUIHandler: TerminalUIHandler {}

public enum TerminalInterface {
    // Registered once at app launch and only read afterwards;
    // nonisolated(unsafe) matches the codebase's singleton conventions.
    nonisolated(unsafe) public static var uiHandler: TerminalUIHandler = DefaultTerminalUIHandler()
}
