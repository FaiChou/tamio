//
//  StatusItem.swift
//  Rayon (macOS)
//
//  Created by Lakr Aream on 2022/3/1.
//
//  The menu bar extra per server: the run cat (frame rate follows CPU load, crash
//  frame when unreachable) and a popover with CPU / Memory / RX / TX, Graphics and
//  Disks, then Terminal, Monitor and Open Rayon.
//

import Combine
import MachineStatus
import MachineStatusView
import RayonModule
import SwiftUI
import UIKit

/// The menu bar item itself is AppKit's, kept by the bridge under `key`; this
/// is its model, and the owner of the popover's content.
class MenubarStatusItem: NSObject, Identifiable {
    let id: UUID = .init()
    var key: String { id.uuidString }

    let machine: RDMachine
    let identity: RDIdentity
    let session: MonitorSession

    var cancellables = Set<AnyCancellable>()
    /// The scene whose window holds the popover's content.
    weak var trayScene: UIWindowScene?
    private var waitingForPopover = false

    static let frames = (0 ... 4).map { "cat_frame_\($0)" }
    static let crashFrame = "cat_frame_crash"

    @MainActor init(machine: RDMachine, identity: RDIdentity, session: MonitorSession? = nil) {
        self.machine = machine
        self.identity = identity
        self.session = session ?? MonitorSession(machine: machine, identity: identity)

        super.init()

        Mac.bridge?.addStatusItem(
            key,
            toolTip: machine.name,
            frames: Self.frames.compactMap { UIImage(named: $0)?.cgImage },
            idleFrame: UIImage(named: Self.crashFrame)?.cgImage
        ) { [weak self] in
            MainActor.assumeIsolated { self?.togglePopover() }
        }

        observeSession()
    }

    deinit {
        debugPrint("\(self) \(#function)")
    }

    /// How often the cat changes frame: the busier the server, the faster.
    enum CatSpeed: TimeInterval {
        case light = 0.05
        case fast = 0.1
        case run = 0.25
        case walk = 0.5
        case hang = 1
        case broken = -1
    }

    /// The popover's content is made on the first click: it lives in a window
    /// scene of its own, which the bridge turns into the popover.
    @MainActor func togglePopover() {
        guard let bridge = Mac.bridge else { return }
        if bridge.hasPopover(key) {
            bridge.togglePopover(key)
            return
        }
        guard !waitingForPopover else { return }
        waitingForPopover = true
        bridge.prepareForPopoverWindow()
        TraySceneDelegate.open(for: self)
    }

    @MainActor var popoverContent: some View {
        MenubarPopoverView(session: session) { [weak self] in
            self?.closeThisItem()
        } dismiss: { [weak self] in
            guard let self else { return }
            Mac.bridge?.closePopover(self.key)
        }
        .environmentObject(RayonStore.shared)
        .environment(\.rxControlsAtRest, true)
    }

    /// Called by the popover's scene once its window is up.
    @MainActor func attachPopover(window: UIWindow, size: CGSize, attempt: Int = 0) {
        guard let bridge = Mac.bridge else { return }
        if bridge.attachPopover(key, window: window, width: size.width, height: size.height) {
            waitingForPopover = false
            bridge.togglePopover(key)
        } else if attempt < 200 {
            // UIKit makes the AppKit window a moment after the UIWindow.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                self?.attachPopover(window: window, size: size, attempt: attempt + 1)
            }
        } else {
            waitingForPopover = false
        }
    }

    @MainActor func closeThisItem() {
        Mac.bridge?.removeStatusItem(key)
        if let session = trayScene?.session {
            UIApplication.shared.requestSceneSessionDestruction(session, options: nil)
        }
        session.shutdown()
        cancellables.removeAll()
        MenubarTool.shared.remove(menubarItem: id)
    }
}

/// The window scene behind a menu bar popover. UIKit gives the scene a window
/// of its own; the bridge moves that window's content into the popover and
/// keeps the window out of sight.
final class TraySceneDelegate: NSObject, UIWindowSceneDelegate {
    static let activityType = "wiki.qaq.rayon.menubar-popover"
    private static let itemKey = "item"
    private static let marker = "wiki.qaq.rayon.menubar-popover"

    var window: UIWindow?

    @MainActor static func open(for item: MenubarStatusItem) {
        let activity = NSUserActivity(activityType: activityType)
        activity.userInfo = [itemKey: item.key]
        if #available(iOS 17.0, *) {
            let request = UISceneSessionActivationRequest(role: .windowApplication, userActivity: activity)
            UIApplication.shared.activateSceneSession(for: request)
        } else {
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil)
        }
    }

    static func owns(_ session: UISceneSession) -> Bool {
        session.userInfo?[marker] != nil
    }

    /// Whether a connecting session is a popover's: one just asked for, or one
    /// the system kept from an earlier run.
    static func claims(_ session: UISceneSession, options: UIScene.ConnectionOptions) -> Bool {
        owns(session) || options.userActivities.contains { $0.activityType == activityType }
    }

    /// A popover's scene does not outlive the run it was made in.
    @MainActor static func discardLeftovers() {
        for session in UIApplication.shared.openSessions where owns(session) {
            UIApplication.shared.requestSceneSessionDestruction(session, options: nil)
        }
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        let key = options.userActivities
            .first { $0.activityType == Self.activityType }?
            .userInfo?[Self.itemKey] as? String
        guard let scene = scene as? UIWindowScene,
              let key, let item = MenubarTool.shared.item(withKey: key)
        else {
            UIApplication.shared.requestSceneSessionDestruction(session, options: nil)
            return
        }
        session.userInfo = [Self.marker: key]
        item.trayScene = scene

        let host = UIHostingController(rootView: item.popoverContent)
        host.view.backgroundColor = .clear
        let size = host.sizeThatFits(in: CGSize(width: MenubarPopoverView.width, height: .greatestFiniteMagnitude))
        scene.sizeRestrictions?.minimumSize = size
        scene.sizeRestrictions?.maximumSize = size
        scene.titlebar?.titleVisibility = .hidden
        scene.titlebar?.toolbar = nil

        let window = UIWindow(windowScene: scene)
        window.backgroundColor = .clear
        window.rootViewController = host
        window.isHidden = false
        self.window = window
        item.attachPopover(window: window, size: size)
        // SwiftUI's WindowGroup puts a main window in every scene, this one
        // too; it would draw behind the cards.
        DispatchQueue.main.async {
            for other in scene.windows where other !== window && !(other.rootViewController is UIInputViewController) {
                if String(describing: type(of: other)) == "UIWindow" { other.isHidden = true }
            }
        }
    }

    /// Nothing to bring back: the scene is made again from its menu bar item.
    func stateRestorationActivity(for _: UIScene) -> NSUserActivity? { nil }
}

/// The popover for one server: the same cards as its Monitor page, in one column.
struct MenubarPopoverView: View {
    @ObservedObject var session: MonitorSession
    @EnvironmentObject var store: RayonStore
    let remove: () -> Void
    let dismiss: () -> Void

    static let width: CGFloat = 380

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, RX.Space.s4)
                .padding(.vertical, RX.Space.s3)
            Hairline()
            ScrollView {
                VStack(spacing: RX.Space.s3) {
                    if session.phase == .connected, session.status.hasData {
                        SystemCard(session: session)
                        ProcessorCard(session: session)
                        MemoryCard(session: session)
                        HStack(spacing: RX.Space.s3) {
                            ThroughputCard(session: session, direction: .receive, height: 128)
                            ThroughputCard(session: session, direction: .transmit, height: 128)
                        }
                        NetworkCard(session: session)
                        DiskCard(session: session)
                        GraphicsCard(session: session)
                    } else {
                        MonitorPlaceholder(session: session)
                    }
                }
                .padding(RX.Space.s3)
            }
            .frame(height: 560)
        }
        .frame(width: Self.width)
        // The window's material, not the popover's, so the cards sit on the same
        // backdrop as in the main window.
        .background(RXWindowBackground().ignoresSafeArea())
    }

    /// Name and system facts on the left; the server's tools as symbols on the right.
    var header: some View {
        let system = session.status.system
        // The hostname only when it says something the name doesn't.
        let hostname = system.hostname == session.machine.name ? "" : system.hostname
        let facts = [hostname, system.releaseName, system.uptimeSec > 0 ? "up \(RXFormat.duration(system.uptimeSec))" : ""]
            .filter { !$0.isEmpty }
        return HStack(alignment: .center, spacing: RX.Space.s2) {
            VStack(alignment: .leading, spacing: 2) {
                RedactableText(session.machine.name, redacted: store.machineRedacted == .all)
                    .font(.rxBodyStrong)
                    .foregroundStyle(.rxInk)
                    .lineLimit(1)
                if !facts.isEmpty {
                    Text(facts.joined(separator: " · "))
                        .font(.rxHelp)
                        .foregroundStyle(.rxInkSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: RX.Space.s2)
            ForEach(ServerTool.allCases) { tool in
                RXIconButton(tool.help, systemImage: tool.systemImage, kind: .plain) {
                    dismiss()
                    openMainWindow()
                    tool.show(session.machine.id)
                }
            }
            Hairline(vertical: true)
                .frame(height: 16)
            RXIconButton("Remove from Menu Bar", systemImage: "xmark", kind: .plain, action: remove)
        }
    }

    func openMainWindow() {
        MainWindow.show()
    }
}
