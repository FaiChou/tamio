//
//  MacUpdates.swift
//  Tamio (macOS)
//
//  Sparkle, Tamio's updater. It reads the appcast that each release puts on
//  GitHub (SUFeedURL in the app's Info.plist), checks that the disk image is
//  signed with the release key (SUPublicEDKey), and installs it with its own
//  windows.
//
//  What a check in the background finds is not put up in a window of its
//  own: the app shows a small notice in the corner of its window ("gentle
//  reminders"), and a click on it opens Sparkle's window for that version.
//

import AppKit
import Sparkle

extension Mac {
    @MainActor private static var updaterController: SPUStandardUpdaterController?
    @MainActor private static let reminders = UpdateReminders()

    @MainActor static func startUpdater() {
        guard updaterController == nil else { return }
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: reminders, userDriverDelegate: reminders)
    }

    @MainActor static func checkForUpdates() {
        startUpdater()
        updaterController?.checkForUpdates(nil)
    }

    @MainActor static var canCheckForUpdates: Bool {
        updaterController?.updater.canCheckForUpdates ?? false
    }

    @MainActor static var automaticallyChecksForUpdates: Bool {
        get { updaterController?.updater.automaticallyChecksForUpdates ?? false }
        set { updaterController?.updater.automaticallyChecksForUpdates = newValue }
    }

    @MainActor static var automaticallyDownloadsUpdates: Bool {
        get { updaterController?.updater.automaticallyDownloadsUpdates ?? false }
        set { updaterController?.updater.automaticallyDownloadsUpdates = newValue }
    }

    @MainActor static var lastUpdateCheck: Date? {
        updaterController?.updater.lastUpdateCheckDate
    }

    /// Called with the version a scheduled check found, and with nil once it
    /// is dealt with.
    @MainActor static func setUpdateNotice(_ handler: @escaping (String?) -> Void) {
        reminders.notice = handler
    }
}

/// Takes over showing what scheduled checks find, so the app can say it
/// quietly; checks the user asks for keep Sparkle's window.
final class UpdateReminders: NSObject, SPUStandardUserDriverDelegate {
    var notice: ((String?) -> Void)?

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_: SUAppcastItem, andInImmediateFocus _: Bool) -> Bool {
        false
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state _: SPUUserUpdateState) {
        guard !handleShowingUpdate else { return }
        notice?(update.displayVersionString)
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate _: SUAppcastItem) {
        notice?(nil)
    }

    func standardUserDriverWillFinishUpdateSession() {
        notice?(nil)
    }
}

extension UpdateReminders: SPUUpdaterDelegate {
    /// Debug builds started with TAMIO_UPDATE_FEED=<url> read that feed
    /// instead of the release's, to look at the update window.
    func feedURLString(for _: SPUUpdater) -> String? {
        #if DEBUG
            return ProcessInfo.processInfo.environment["TAMIO_UPDATE_FEED"]
        #else
            return nil
        #endif
    }
}
