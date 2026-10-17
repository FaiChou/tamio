//
//  UpdateCenter.swift
//  Tamio (macOS)
//
//  The app's side of Sparkle (see Bridge+Updates.swift): starts the updater in
//  release builds, and when a check in the background finds a new version,
//  shows a small notice at the bottom of the sidebar, the window's bottom-left
//  corner. Clicking it opens Sparkle's window for that version. The first
//  launch of a new version shows its notes from CHANGELOG.md (What's New).
//

import SwiftUI
import TamioDesign

@MainActor
final class UpdateCenter: ObservableObject {
    static let shared = UpdateCenter()

    /// The version a background check found, until it is dealt with.
    @Published private(set) var available: String?
    /// Whether this copy updates itself: the release build only, so a debug
    /// or test copy is never replaced by a release.
    let isSupported = Bundle.main.bundleIdentifier == "sb.moe.tamio"
    /// The notes of the version just updated to, shown once on its first launch.
    @Published var justUpdated: ChangelogRelease?

    private static let lastVersionKey = "TamioLastLaunchedVersion"

    func start() {
        noteLaunch()
        #if DEBUG
            // `-TamioPreviewUpdate 1.2.3` shows the notice, and
            // `-TamioPreviewWhatsNew 0.1.0` that version's notes, to look at them.
            available = UserDefaults.standard.string(forKey: "TamioPreviewUpdate")
            if let version = UserDefaults.standard.string(forKey: "TamioPreviewWhatsNew") {
                justUpdated = Changelog.release(version)
            }
        #endif
        guard isSupported, let bridge = Mac.bridge else { return }
        bridge.startUpdater()
        bridge.setUpdateNotice { [weak self] version in
            Task { @MainActor in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { self?.available = version }
            }
        }
    }

    /// A first launch after an update (not the first launch ever) shows what
    /// is new in it.
    private func noteLaunch() {
        guard let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }
        let defaults = UserDefaults.standard
        if let last = defaults.string(forKey: Self.lastVersionKey), last != current {
            justUpdated = Changelog.release(current)
        }
        defaults.set(current, forKey: Self.lastVersionKey)
    }

    func checkNow() {
        Mac.bridge?.checkForUpdates()
    }
}

/// "New version available" above Settings.
struct UpdateNotice: View {
    @ObservedObject private var center = UpdateCenter.shared

    var body: some View {
        if let version = center.available {
            Button {
                center.checkNow()
            } label: {
                HStack(spacing: RX.Space.s2) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.rxAccent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("New version available")
                            .font(.rxBodyStrong)
                            .foregroundStyle(.rxInk)
                            .fixedSize()
                        Text("Tamio \(version)")
                            .font(.rxHelp)
                            .foregroundStyle(.rxInkSecondary)
                            .fixedSize()
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, RX.Space.s3)
                .padding(.vertical, RX.Space.s2)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.rxAccentFill)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Show what is new and update")
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
