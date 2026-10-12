//
//  Bench.swift
//  Rayon (macOS)
//
//  Measurements for the Files page, in debug builds only. Launch with
//  RAYON_BENCH_FILES=<count> to fill a page with that many entries and time
//  showing them, selecting, filtering, a transfer's progress ticks and scrolling.
//  Results go to the log, one "BENCH" line each.
//

#if DEBUG
    import NSRemoteShell
    import RayonModule
    import SwiftUI
    import UIKit

    extension Notification.Name {
        /// userInfo: "select" (Int, an index into the sorted list) or "filter" (String).
        static let benchFiles = Notification.Name("wiki.qaq.rayon.bench.files")
    }

    @MainActor
    enum Bench {
        static func runIfRequested() {
            if ProcessInfo.processInfo.environment["RAYON_PREVIEW_FILES"] != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { Task { await previewFiles() } }
            }
            if ProcessInfo.processInfo.environment["RAYON_BENCH_SETTINGS"] != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { Task { await settings() } }
            }
            guard let value = ProcessInfo.processInfo.environment["RAYON_BENCH_FILES"], let count = Int(value) else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { Task { await files(count) } }
        }

        /// How long the main thread worked in the 0.4 s after the action: the
        /// state change, SwiftUI's update, layout and the commit to the render
        /// server, wherever in that window they ran.
        static func settle(_ action: () -> Void) async -> Double {
            nonisolated(unsafe) var busy = 0.0
            nonisolated(unsafe) var woke = CACurrentMediaTime()
            let activities = CFRunLoopActivity.afterWaiting.rawValue | CFRunLoopActivity.beforeWaiting.rawValue
            let observer = CFRunLoopObserverCreateWithHandler(nil, activities, true, CFIndex.max) { _, activity in
                let now = CACurrentMediaTime()
                if activity == .afterWaiting { woke = now } else { busy += now - woke; woke = now }
            }
            CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
            action()
            try? await Task.sleep(nanoseconds: 400_000_000)
            CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
            return busy * 1000
        }

        static func report(_ name: String, _ samples: [Double]) {
            let sorted = samples.sorted()
            let median = sorted[sorted.count / 2]
            NSLog("BENCH %@ median %.2f ms  max %.2f ms  n=%d", name, median, sorted.last ?? 0, samples.count)
        }

        /// A Files page with no server behind it, to be filled by hand.
        static func emptyFilesPage() async -> FileTransferContext {
            let machine = RDMachine(remoteAddress: "203.0.113.10", remotePort: "22", name: "web-01")
            let context = FileTransferContext(machine: machine)
            FileTransferManager.shared.transfers.append(context)
            AppRouter.shared.route = .transfer(context.id)
            // Once the connection attempt has given up.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            while context.processConnection { try? await Task.sleep(nanoseconds: 200_000_000) }
            try? await Task.sleep(nanoseconds: 500_000_000)
            context.connected = true
            context.isProgressRunning = false
            try? await Task.sleep(nanoseconds: 500_000_000)
            return context
        }

        /// A folder of sample entries: launch with RAYON_PREVIEW_FILES=1 to check
        /// the table's layout.
        static func previewFiles() async {
            let context = await emptyFilesPage()
            context.currentDir = "/var/log"
            let base = URL(fileURLWithPath: "/var/log")
            let names = ["nginx", "journal", "apt", "private", "auth.log", "syslog", "kern.log", "dpkg.log", "boot.log",
                         "a-very-long-file-name-that-does-not-fit-in-the-name-column-of-the-table-and-is-truncated-in-the-middle-2026-10-11.log.gz",
                         "fail2ban.log", "alternatives.log", "cloud-init.log", "wtmp", "btmp", "lastlog", "ufw.log", "mail.log"]
            context.currentFileList = names.enumerated().map { index, name in
                let file = NSRemoteFile(filename: name)
                var attributes = LIBSSH2_SFTP_ATTRIBUTES()
                attributes.flags = 0xF
                attributes.filesize = UInt64(index * index * 4321 + 17)
                attributes.uid = index < 4 ? 0 : 1000
                attributes.gid = 0
                attributes.permissions = index < 4 ? 0o040755 : 0o100644
                attributes.mtime = UInt(1_780_000_000 + index * 86400 * 3)
                attributes.atime = attributes.mtime
                file.populateAttributes(attributes)
                return FileTransferContext.RemoteFile(base: base, name: name, fstat: file)
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            NotificationCenter.default.post(name: .benchFiles, object: nil, userInfo: ["select": 6])
            if ProcessInfo.processInfo.environment["RAYON_PREVIEW_TOUR"] != nil { await tour(context) }
        }

        /// Goes back and forth between Files and the Editor, and from folder to
        /// folder, so the motion between them can be watched or captured.
        static func tour(_ context: FileTransferContext) async {
            _ = EditorCenter.shared.workspace(for: context)
            let list = context.currentFileList
            for step in 0 ..< 8 {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                NSLog("TOUR step %d", step)
                switch step % 4 {
                case 0: AppRouter.shared.route = .editor(context.id)
                case 1: AppRouter.shared.route = .transfer(context.id)
                case 2:
                    context.currentDir = "/var/log/nginx"
                    context.currentFileList = Array(list.prefix(7))
                default:
                    context.currentDir = "/var/log"
                    context.currentFileList = list
                }
            }
            NSLog("TOUR done")
        }

        static func files(_ count: Int) async {
            let context = await emptyFilesPage()

            let base = URL(fileURLWithPath: "/var/log")
            var generator = SystemRandomNumberGenerator()
            let list = (0 ..< count).map { _ in
                let name = "file-\(Int.random(in: 0 ..< 10_000_000, using: &generator)).log"
                return FileTransferContext.RemoteFile(base: base, name: name, fstat: NSRemoteFile(filename: name))
            }
            report("show \(count)", [await settle { context.currentFileList = list }])
            try? await Task.sleep(nanoseconds: 500_000_000)

            var samples: [Double] = []
            for index in 0 ..< 20 {
                samples.append(await settle {
                    NotificationCenter.default.post(name: .benchFiles, object: nil, userInfo: ["select": index % 12])
                })
            }
            report("select", samples)

            samples = []
            for index in 0 ..< 20 {
                samples.append(await settle { context.currentSpeed = 1000 + index })
            }
            report("progress tick", samples)

            samples = []
            for text in Array(repeating: ["1", "12", "123", "12", "1", ""], count: Int(ProcessInfo.processInfo.environment["RAYON_BENCH_REPEAT"] ?? "1") ?? 1).flatMap({ $0 }) {
                samples.append(await settle {
                    NotificationCenter.default.post(name: .benchFiles, object: nil, userInfo: ["filter": text])
                })
            }
            report("filter keystroke", samples)

            try? await Task.sleep(nanoseconds: 1_000_000_000)
            report("idle 0.4 s", [await settle {}, await settle {}, await settle {}])
            await scroll()
            NSLog("BENCH done")
        }

        /// Opens Settings, goes through its categories and scrolls the longest.
        static func settings() async {
            let router = AppRouter.shared
            router.settingsSelection = "general"
            report("open settings", [await settle { router.route = .settings }])
            try? await Task.sleep(nanoseconds: 500_000_000)
            let ids = ["general", "connection", "text", "colors", "cursor", "window", "input", "keyboard", "advanced", "about"]
            var samples: [Double] = []
            let rounds = Int(ProcessInfo.processInfo.environment["RAYON_BENCH_REPEAT"] ?? "2") ?? 2
            for id in Array(repeating: ids, count: rounds).flatMap({ $0 }) {
                let sample = await settle { router.settingsSelection = id }
                NSLog("BENCH category %@ %.2f ms", id, sample)
                samples.append(sample)
            }
            report("switch category", samples)
            router.settingsSelection = "advanced"
            try? await Task.sleep(nanoseconds: 800_000_000)
            report("idle 0.4 s", [await settle {}, await settle {}, await settle {}])
            await scroll()
            router.settingsSelection = "colors"
            try? await Task.sleep(nanoseconds: 800_000_000)
            await scroll()
            NSLog("BENCH done")
        }

        /// Scrolls the file list from top to bottom and back at a steady pace
        /// and reports how long frames took.
        static func scroll() async {
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: { $0.bounds.width > 900 }),
                let scroller = largestScrollView(in: window)
            else { return NSLog("BENCH scroll: no scroll view") }
            NSLog("BENCH scroll view %@ content %.0f", String(describing: type(of: scroller)), scroller.contentSize.height)
            let recorder = FrameRecorder()
            // A fast flick, about 6000 pt a second, rather than the whole list.
            let distance = min(12000, max(0, scroller.contentSize.height - scroller.bounds.height))
            let duration = 4.0
            recorder.start { progress in
                // There and back.
                let phase = progress < 0.5 ? progress * 2 : (1 - progress) * 2
                scroller.contentOffset.y = distance * phase
            }
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            let frames = recorder.stop()
            guard frames.count > 2 else { return }
            let sorted = frames.sorted()
            let slow = frames.filter { $0 > 1000.0 / 60 * 1.5 }.count
            NSLog(
                "BENCH scroll %.0f pt  frames %d  median %.2f ms  p95 %.2f ms  max %.2f ms  slow(>25ms) %d",
                distance, frames.count, sorted[sorted.count / 2], sorted[Int(Double(sorted.count) * 0.95)], sorted.last ?? 0, slow
            )
        }

        private static func largestScrollView(in view: UIView) -> UIScrollView? {
            var best: UIScrollView?
            var stack = [view]
            while let next = stack.popLast() {
                if let scroll = next as? UIScrollView, scroll.contentSize.height > (best?.contentSize.height ?? 0) { best = scroll }
                stack.append(contentsOf: next.subviews)
            }
            return best
        }
    }

    @MainActor
    private final class FrameRecorder: NSObject {
        private var link: CADisplayLink?
        private var step: ((Double) -> Void)?
        private var begin = 0.0
        private var last = 0.0
        private var frames: [Double] = []

        func start(duration: Double = 4, step: @escaping (Double) -> Void) {
            self.step = step
            self.duration = duration
            link = CADisplayLink(target: self, selector: #selector(tick))
            link?.add(to: .main, forMode: .common)
        }

        private var duration = 4.0

        @objc private func tick(_: CADisplayLink) {
            // Wall time between callbacks: a stalled main thread shows as a long frame.
            let now = CACurrentMediaTime()
            if begin == 0 { begin = now } else { frames.append((now - last) * 1000) }
            last = now
            step?(min(1, (now - begin) / duration))
        }

        func stop() -> [Double] {
            link?.invalidate()
            return frames
        }
    }
#endif
