//
//  Platform.swift
//  TamioDesign
//
//  Control styles that exist on one platform only, expressed once so views can
//  stay shared between macOS, Mac Catalyst and iOS.
//

import SwiftUI

public extension View {
    /// A checkbox on the Mac; iOS has no checkbox, so a switch there.
    func rxCheckboxToggle() -> some View {
        #if os(macOS)
            toggleStyle(.checkbox)
        #elseif targetEnvironment(macCatalyst)
            // The Mac idiom draws the automatic style as a checkbox.
            toggleStyle(.automatic)
        #else
            toggleStyle(.switch)
        #endif
    }

    /// A switch. Mac Catalyst's switch claims 12pt beyond the control it draws,
    /// which would keep it that far from the trailing edge of a row.
    func rxSwitchToggle() -> some View {
        #if targetEnvironment(macCatalyst)
            toggleStyle(.switch).padding(.trailing, -12)
        #else
            toggleStyle(.switch)
        #endif
    }

    /// An indeterminate spinner at AppKit's regular size. Mac Catalyst draws the
    /// regular control size at half that.
    func rxSpinner() -> some View {
        #if targetEnvironment(macCatalyst)
            controlSize(.large)
        #else
            controlSize(.regular)
        #endif
    }

    /// A menu drawn as a button (the Mac needs the button menu style; on iOS a
    /// `Menu` already is one), optionally without the disclosure indicator.
    func rxButtonMenu(indicator: Bool = true) -> some View {
        #if os(macOS) || targetEnvironment(macCatalyst)
            menuStyle(.button).menuIndicator(indicator ? .automatic : .hidden)
        #else
            menuIndicator(indicator ? .automatic : .hidden)
        #endif
    }

    /// An inline text link: the link button style on macOS, where there is one;
    /// elsewhere a borderless button, in the link colour on Mac Catalyst.
    func rxLinkButton() -> some View {
        #if os(macOS)
            buttonStyle(.link)
        #elseif targetEnvironment(macCatalyst)
            buttonStyle(.plain).foregroundStyle(Color(uiColor: .link))
        #else
            buttonStyle(.borderless)
        #endif
    }

    /// Lets the window toolbar float over the page instead of drawing its own
    /// background.
    func rxClearToolbar() -> some View {
        #if os(macOS)
            toolbarBackground(.hidden, for: .windowToolbar)
        #else
            toolbarBackground(.hidden, for: .navigationBar)
        #endif
    }
}

private struct RXControlsAtRestKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// True where AppKit draws controls as in a window that is not the main
    /// one, the selection grey: a menu bar popover, whichever app is in front.
    var rxControlsAtRest: Bool {
        get { self[RXControlsAtRestKey.self] }
        set { self[RXControlsAtRestKey.self] = newValue }
    }
}
