//
//  Platform.swift
//  RayonDesign
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
