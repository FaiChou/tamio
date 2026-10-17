//
//  Bridge+Updates.swift
//  MacBridge
//
//  Sparkle, Tamio's updater. It reads the appcast that each release puts on
//  GitHub (SUFeedURL in the app's Info.plist), checks that the disk image is
//  signed with the release key (SUPublicEDKey), and installs it with its own
//  AppKit windows, which work in the Catalyst process like the bridge's other
//  AppKit.
//
//  What a check in the background finds is not put up in a window of its
//  own: the app shows a small notice in the corner of its window ("gentle
//  reminders"), and a click on it opens Sparkle's window for that version.
//

import AppKit
import Sparkle

extension Bridge {
    private var controller: SPUStandardUpdaterController? {
        updaterController as? SPUStandardUpdaterController
    }

    func startUpdater() {
        guard updaterController == nil else { return }
        let reminders = UpdateReminders()
        updateReminders = reminders
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: reminders)
    }

    func checkForUpdates() {
        startUpdater()
        controller?.checkForUpdates(nil)
    }

    var canCheckForUpdates: Bool {
        controller?.updater.canCheckForUpdates ?? false
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { controller?.updater.automaticallyDownloadsUpdates ?? false }
        set { controller?.updater.automaticallyDownloadsUpdates = newValue }
    }

    var lastUpdateCheck: Date? {
        controller?.updater.lastUpdateCheckDate
    }

    func setUpdateNotice(_ handler: @escaping (String?) -> Void) {
        (updateReminders as? UpdateReminders)?.notice = handler
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
