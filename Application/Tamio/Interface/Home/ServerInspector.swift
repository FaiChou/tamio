//
//  ServerInspector.swift
//  Tamio (macOS)
//
//  The panel beside the cards for the selected server: Overview (CPU, memory,
//  network with TCP counters and interfaces, one box per disk with its I/O),
//  Processes (a top-style list) and Containers (Docker). Processes and
//  containers are read only while their tab is shown.
//

import MachineStatus
import MachineStatusView
import SwiftUI
import TamioDesign
import TamioModule

struct ServerInspector: View {
    let machine: RDMachine.ID
    let close: () -> Void

    enum Tab: Hashable { case overview, processes, containers, activity }

    @EnvironmentObject var store: TamioStore
    @ObservedObject private var live = LiveStatusCenter.shared
    @State private var tab: Tab = .overview

    static let width: CGFloat = 440

    var body: some View {
        let read = store.machineGroup[machine]
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: RX.Space.s2) {
                if let flag = read.countryFlag { Text(flag) }
                RedactableText(read.name.uppercased(), redacted: store.machineRedacted == .all)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                Spacer()
                RXSegmented(selection: $tab, options: [
                    .init(.overview, "Overview"),
                    .init(.processes, "Processes"),
                    .init(.containers, "Containers"),
                    .init(.activity, "Activity"),
                ], caps: false)
                .fixedSize()
                Button(action: close) {
                    Label("Close", systemImage: "xmark")
                }
                .buttonStyle(.rx(.plain, size: .small, iconOnly: true))
                .help("Close (Esc)")
            }
            .frame(height: 30)
            .padding(.horizontal, RX.Space.s4)
            .padding(.top, RX.Space.s2)
            .padding(.bottom, RX.Space.s3)
            if tab == .activity {
                ServerActivity(machine: machine)
            } else if let session = live.session(for: machine) {
                switch tab {
                case .overview:
                    ScrollView { InspectorOverview(session: session).padding(.horizontal, RX.Space.s4).padding(.bottom, RX.Space.s4) }
                case .processes:
                    ProcessList(session: session)
                case .containers:
                    ContainerList(session: session, machine: machine)
                case .activity:
                    EmptyView()
                }
            } else {
                EmptyStateView("No live status", systemImage: "key", message: "Add a password or key to this server to see it.")
                    .frame(maxHeight: .infinity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: RX.Radius.card, style: .continuous)
                .fill(Color.rxSurface.opacity(0.6))
        )
        .padding(.trailing, RX.Space.s3)
        .padding(.bottom, RX.Space.s3)
    }
}

// MARK: - Activity

/// What agents did on this server, from every Mac, newest first.
private struct ServerActivity: View {
    let machine: RDMachine.ID
    @ObservedObject private var log = AgentServer.shared.log

    var body: some View {
        let entries = log.entries(for: machine).reversed()
        if entries.isEmpty {
            EmptyStateView("No agent activity", systemImage: "sparkles", message: "What agents run or change here, through Tamio or reported by them, shows here.")
                .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: RX.Space.s3) {
                    ForEach(Array(entries)) { entry in
                        AgentActivityRow(entry: entry)
                            .padding(RX.Space.s3)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.rxSurfaceSunken))
                    }
                }
                .padding(.horizontal, RX.Space.s4)
                .padding(.bottom, RX.Space.s4)
            }
        }
    }
}

// MARK: - Overview

private struct InspectorOverview: View {
    @ObservedObject var session: MonitorSession

    var body: some View {
        let status = session.status
        VStack(alignment: .leading, spacing: RX.Space.s3) {
            if !status.system.releaseName.isEmpty {
                HStack(spacing: 5) {
                    OSLogo(session: session, size: 13)
                    Text(status.system.releaseName)
                        .font(.rxHelp)
                        .foregroundStyle(.rxInkSecondary)
                        .textSelection(.enabled)
                    if status.system.uptimeSec > 0 {
                        Text("· up \(RXFormat.duration(status.system.uptimeSec))")
                            .font(.rxHelp)
                            .foregroundStyle(.rxInkSecondary)
                    }
                }
            }
            cpu(status)
            memory(status)
            network(status)
            ForEach(disks(status), id: \.mountPoint) { disk in
                diskBox(disk, io: ioDevice(for: disk, in: status))
            }
            if !session.status.hasData {
                HStack { ProgressView().controlSize(.small); Text("Connecting…").font(.rxBody).foregroundStyle(.rxInkSecondary) }
            }
        }
    }

    func box(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: RX.Space.s3) { content() }
            .padding(RX.Space.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.rxSurfaceSunken))
    }

    func fact(_ label: String, _ value: String, unit: String = "", dot: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                if let dot { RoundedRectangle(cornerRadius: 1.5).fill(dot).frame(width: 3, height: 9) }
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(.rxInkSecondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                    .contentTransition(.numericText())
                if !unit.isEmpty {
                    Text(unit).font(.system(size: 10, weight: .medium)).foregroundStyle(.rxInkSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func cpu(_ status: ServerStatus) -> some View {
        let summary = status.processor.summary
        let idle = max(0, 100 - Double(summary.sumUsed))
        return box {
            HStack(alignment: .top, spacing: RX.Space.s2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(RXFormat.percent(Double(summary.sumUsed)))
                        .font(.system(size: 30, weight: .semibold).monospacedDigit())
                        .contentTransition(.numericText())
                    Text("%").font(.system(size: 12)).foregroundStyle(.rxInkSecondary)
                }
                .frame(width: 84, alignment: .leading)
                fact("Sys", RXFormat.percent(Double(summary.sumSystem)), unit: "%", dot: .rxDanger)
                fact("User", RXFormat.percent(Double(summary.sumUser)), unit: "%", dot: .rxSuccess)
                fact("IO wait", RXFormat.percent(Double(summary.sumIOWait)), unit: "%", dot: .purple)
                fact("Nice", RXFormat.percent(Double(summary.sumNice)), unit: "%", dot: .yellow)
            }
            HistoryPills(values: session.history.cpu)
            HStack(alignment: .bottom) {
                fact("Cores", "\(status.cores)")
                fact("Idle", RXFormat.percent(idle), unit: "%")
                fact("Uptime", RXFormat.duration(status.system.uptimeSec))
                VStack(alignment: .trailing, spacing: 2) {
                    Text("LOAD").font(.system(size: 10, weight: .medium)).foregroundStyle(.rxInkSecondary)
                    LoadRings(load: (Double(status.system.load1), Double(status.system.load5), Double(status.system.load15)),
                              cores: status.cores)
                        .scaleEffect(0.8)
                        .frame(width: 38, height: 38)
                }
            }
        }
    }

    func memory(_ status: ServerStatus) -> some View {
        let memory = status.memory
        return box {
            HStack(alignment: .center) {
                fact("Free", RXFormat.bytes(memory.memFree * 1000).value, unit: RXFormat.bytes(memory.memFree * 1000).unit)
                fact("Used", RXFormat.bytes(status.memoryUsedKB * 1000).value, unit: RXFormat.bytes(status.memoryUsedKB * 1000).unit, dot: .rxSuccess)
                fact("Cache", RXFormat.bytes(status.memoryCacheKB * 1000).value, unit: RXFormat.bytes(status.memoryCacheKB * 1000).unit, dot: .rxInkTertiary)
                RingGauge(fraction: status.memoryUsedPercent / 100,
                          cache: memory.memTotal > 0 ? status.memoryCacheKB / memory.memTotal : 0)
            }
            if memory.swapTotal > 0 {
                let used = max(0, memory.swapTotal - memory.swapFree)
                HStack {
                    fact("Swap", RXFormat.bytes(used * 1000).value, unit: RXFormat.bytes(used * 1000).unit + " of " + RXFormat.bytesString(memory.swapTotal * 1000))
                    UsageBar(fraction: used / memory.swapTotal, color: .rxSuccess, thresholds: true)
                        .frame(width: 120)
                }
            }
        }
    }

    func network(_ status: ServerStatus) -> some View {
        let physical = status.network.elements.filter { !NetworkFilter.isVirtual($0.device) }
        let virtual = status.network.elements.filter { NetworkFilter.isVirtual($0.device) }
        return box {
            trafficRow(physical)
            if status.tcp.outSegments > 0 {
                Hairline()
                HStack {
                    fact("Retrans", String(format: "%.1f", status.tcp.retransmitPercent), unit: "%")
                    fact("Active", compact(status.tcp.activeOpens))
                    fact("Passive", compact(status.tcp.passiveOpens))
                    fact("Fails", compact(status.tcp.attemptFails))
                }
            }
            ForEach(physical) { element in
                Hairline()
                VStack(alignment: .leading, spacing: RX.Space.s2) {
                    HStack {
                        Image(systemName: element.device.hasPrefix("w") ? "wifi" : "network")
                            .font(.system(size: 11))
                            .foregroundStyle(.rxSuccess)
                        Text(element.device).font(.rxCode)
                        Spacer()
                        if let address = status.addresses[element.device] {
                            Text(address).font(.rxCode).foregroundStyle(.rxInkSecondary).textSelection(.enabled)
                        }
                    }
                    trafficRow([element])
                }
            }
            if !virtual.isEmpty {
                DisclosureGroup {
                    ForEach(virtual) { element in
                        HStack {
                            Text(element.device).font(.rxCode)
                            Spacer()
                            Text("↑ \(RXFormat.rateString(Double(element.txBytesPerSec)))  ↓ \(RXFormat.rateString(Double(element.rxBytesPerSec)))")
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(.rxInkSecondary)
                        }
                    }
                } label: {
                    HStack {
                        Text("VIRTUAL INTERFACES").font(.system(size: 10, weight: .medium)).foregroundStyle(.rxInkSecondary)
                        Spacer()
                        Text("\(virtual.count)").font(.system(size: 11)).foregroundStyle(.rxInkSecondary)
                    }
                }
            }
        }
    }

    func trafficRow(_ elements: [ServerStatus.NetworkInfo.NetworkInfoElement]) -> some View {
        let up = Double(elements.map(\.txBytesPerSec).reduce(0, +))
        let down = Double(elements.map(\.rxBytesPerSec).reduce(0, +))
        let upTotal = Double(elements.map(\.txBytesTotal).reduce(0, +))
        let downTotal = Double(elements.map(\.rxBytesTotal).reduce(0, +))
        return HStack(alignment: .center) {
            fact("↑/s", RXFormat.rate(up).value, unit: RXFormat.rate(up).unit)
            fact("↓/s", RXFormat.rate(down).value, unit: RXFormat.rate(down).unit)
            VStack(alignment: .trailing, spacing: 2) {
                totalLine("↑", upTotal, .orange)
                totalLine("↓", downTotal, .rxSuccess)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            ShareRing(up: upTotal, down: downTotal)
        }
    }

    func totalLine(_ arrow: String, _ bytes: Double, _ color: Color) -> some View {
        let pair = RXFormat.bytes(bytes)
        return HStack(spacing: 4) {
            Text(arrow).font(.system(size: 11)).foregroundStyle(.rxInkSecondary)
            Text(pair.value).font(.system(size: 13, weight: .bold).monospacedDigit())
            Text(pair.unit).font(.system(size: 10)).foregroundStyle(.rxInkSecondary)
            RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 3, height: 9)
        }
        .help("Since the server booted")
    }

    func compact(_ value: Int) -> String {
        let number = Double(value)
        if number >= 1_000_000 { return String(format: "%.1fM", number / 1_000_000) }
        if number >= 1000 { return String(format: "%.1fK", number / 1000) }
        return "\(value)"
    }

    func disks(_ status: ServerStatus) -> [ServerStatus.FileSystemInfo.FileSystemInfoElement] {
        status.fileSystem.elements
    }

    /// The I/O of the disk a mount is on; only the root's when there is one disk.
    func ioDevice(for disk: ServerStatus.FileSystemInfo.FileSystemInfoElement, in status: ServerStatus) -> ServerStatus.DiskIOInfo.Device? {
        let devices = status.diskIO.devices
        if devices.count == 1, disk.mountPoint == "/" { return devices.first }
        return nil
    }

    func diskBox(_ disk: ServerStatus.FileSystemInfo.FileSystemInfoElement, io: ServerStatus.DiskIOInfo.Device?) -> some View {
        box {
            HStack(alignment: .center, spacing: RX.Space.s3) {
                Text(disk.mountPoint)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(disk.used) / \(disk.size)")
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                    Text("\(Int(disk.percent))% used · \(disk.free) free")
                        .font(.system(size: 10))
                        .foregroundStyle(.rxInkSecondary)
                }
                FillPill(fraction: Double(disk.percent) / 100)
            }
            if let io {
                Grid(alignment: .trailing, horizontalSpacing: RX.Space.s3, verticalSpacing: 3) {
                    GridRow {
                        Text("")
                        ForEach(["SPEED", "TOTAL", "IOPS", "WAIT"], id: \.self) {
                            Text($0).font(.system(size: 10, weight: .medium)).foregroundStyle(.rxInkSecondary)
                        }
                    }
                    ioRow("R", io.readBytesPerSec, io.readBytesTotal, io.readOpsPerSec, io.readWaitMs)
                    ioRow("W", io.writeBytesPerSec, io.writeBytesTotal, io.writeOpsPerSec, io.writeWaitMs)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    func ioRow(_ label: String, _ rate: Int, _ total: Int, _ ops: Int, _ wait: Double) -> some View {
        GridRow {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.rxInkSecondary).gridColumnAlignment(.leading)
            Text(RXFormat.rateString(Double(rate))).font(.system(size: 12).monospacedDigit())
            Text(RXFormat.bytesString(Double(total))).font(.system(size: 12, weight: .semibold).monospacedDigit())
            Text("\(ops)").font(.system(size: 12, weight: .semibold).monospacedDigit())
            Text(String(format: "%.1f ms", wait)).font(.system(size: 12).monospacedDigit())
        }
    }
}

/// One rounded pill per CPU sample, newest on the right, taller and greener
/// the busier.
private struct HistoryPills: View {
    let values: [Double]

    var body: some View {
        GeometryReader { proxy in
            let count = max(1, Int(proxy.size.width / 7))
            let shown = Array(values.suffix(count))
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0 ..< count, id: \.self) { index in
                    let offset = index - (count - shown.count)
                    let value = offset >= 0 ? shown[offset] : 0
                    Capsule()
                        .fill(offset >= 0 && value > 1 ? rxUsageColor(value, base: .rxSuccess) : Color.rxHairline)
                        .frame(width: 4, height: 6 + CGFloat(min(value, 100)) / 100 * 14)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 22)
        .animation(.easeOut(duration: 0.3), value: values)
    }
}

/// Up and down traffic's share of the total, as a two-colour ring.
private struct ShareRing: View {
    let up: Double
    let down: Double

    var body: some View {
        let total = up + down
        let upShare = total > 0 ? up / total : 0
        ZStack {
            Circle().stroke(Color.rxHairline, lineWidth: 5)
            Circle().trim(from: 0, to: upShare).stroke(Color.orange, style: StrokeStyle(lineWidth: 5, lineCap: .butt)).rotationEffect(.degrees(-90))
            Circle().trim(from: upShare, to: total > 0 ? 1 : 0).stroke(Color.rxSuccess, style: StrokeStyle(lineWidth: 5, lineCap: .butt)).rotationEffect(.degrees(-90))
        }
        .frame(width: 34, height: 34)
        .help(total > 0 ? "\(RXFormat.percent(upShare * 100))% sent, \(RXFormat.percent((1 - upShare) * 100))% received" : "")
    }
}

/// A disk's fill as a vertical pill.
private struct FillPill: View {
    let fraction: Double

    var body: some View {
        let value = min(max(fraction, 0), 1)
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.rxHairline)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(rxUsageColor(value * 100, base: .rxSuccess))
                .frame(height: max(3, 34 * value))
        }
        .frame(width: 14, height: 34)
    }
}

// MARK: - Processes

private struct ProcessList: View {
    @ObservedObject var session: MonitorSession

    struct Row: Identifiable, Equatable {
        let pid: Int
        let cpu: Double
        let rssKB: Double
        let command: String
        var id: Int { pid }
    }

    enum Sort { case cpu, memory, name }

    @State private var rows: [Row] = []
    @State private var sort: Sort = .cpu
    @State private var loaded = false

    var sorted: [Row] {
        switch sort {
        case .cpu: return rows.sorted { $0.cpu > $1.cpu }
        case .memory: return rows.sorted { $0.rssKB > $1.rssKB }
        case .name: return rows.sorted { $0.command.localizedStandardCompare($1.command) == .orderedAscending }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                header("Process", .name).frame(maxWidth: .infinity, alignment: .leading)
                header("CPU%", .cpu).frame(width: 60, alignment: .trailing)
                header("Mem", .memory).frame(width: 64, alignment: .trailing)
            }
            .padding(.horizontal, RX.Space.s4)
            .frame(height: 28)
            Hairline()
            if !loaded {
                ProgressView().controlSize(.small).frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sorted) { row in
                            HStack {
                                Text(row.command)
                                    .font(.rxCode)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .help(row.command)
                                Text(String(format: "%.1f", row.cpu)).font(.system(size: 12).monospacedDigit()).frame(width: 60, alignment: .trailing)
                                Text(RXFormat.bytesString(row.rssKB * 1024)).font(.system(size: 12).monospacedDigit()).frame(width: 64, alignment: .trailing)
                            }
                            .padding(.horizontal, RX.Space.s4)
                            .frame(height: 26)
                            .contextMenu {
                                Button("Copy PID") { UIBridge.sendPasteboard(str: "\(row.pid)") }
                                Divider()
                                Button("Kill…", role: .destructive) { kill(row, signal: "TERM") }
                                Button("Kill -9…", role: .destructive) { kill(row, signal: "KILL") }
                            }
                        }
                    }
                }
            }
        }
        .task(id: session.id) {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(nanoseconds: 3 * NSEC_PER_SEC)
            }
        }
    }

    func header(_ title: String, _ key: Sort) -> some View {
        Button {
            sort = key
        } label: {
            Text(title + (sort == key ? (key == .name ? " ↑" : " ↓") : ""))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(sort == key ? Color.rxInk : Color.rxInkSecondary)
        }
        .buttonStyle(.plain)
    }

    func refresh() async {
        let command = """
        if [ "$(uname -s)" = Darwin ]; then ps -Ao pid=,%cpu=,rss=,command= -r | head -100; \
        else ps -eo pid=,pcpu=,rss=,args= --sort=-pcpu | head -100; fi
        """
        guard let output = await session.run(command) else { return }
        let parsed = output.split(separator: "\n").compactMap { line -> Row? in
            let fields = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard fields.count == 4, let pid = Int(fields[0]) else { return nil }
            return Row(pid: pid, cpu: Double(fields[1]) ?? 0, rssKB: Double(fields[2]) ?? 0, command: String(fields[3]))
        }
        rows = parsed
        loaded = true
    }

    func kill(_ row: Row, signal: String) {
        UIBridge.requiresConfirmation(
            message: "Send SIG\(signal) to \(row.pid)?",
            informative: row.command,
            confirmTitle: signal == "KILL" ? "Kill -9" : "Kill",
            destructive: true
        ) { confirmed in
            guard confirmed else { return }
            Task {
                _ = await session.run("kill -\(signal) \(row.pid) 2>&1")
                await refresh()
            }
        }
    }
}

// MARK: - Containers

private struct ContainerList: View {
    @ObservedObject var session: MonitorSession
    let machine: RDMachine.ID

    struct Container: Identifiable, Equatable {
        let id: String
        let name: String
        let state: String
        let status: String
        var cpu = ""
        var memory = ""
        var blockIO = ""
        var netIO = ""
        var running: Bool { state == "running" }
        var unhealthy: Bool { status.contains("unhealthy") }
    }

    @State private var containers: [Container] = []
    @State private var problem: String?
    @State private var loaded = false

    var body: some View {
        Group {
            if !loaded {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let problem {
                EmptyStateView("No containers", systemImage: "shippingbox", message: problem)
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: RX.Space.s2) {
                        ForEach(containers) { container in
                            row(container)
                        }
                    }
                    .padding(.horizontal, RX.Space.s4)
                    .padding(.bottom, RX.Space.s4)
                }
            }
        }
        .task(id: session.id) {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(nanoseconds: 5 * NSEC_PER_SEC)
            }
        }
    }

    func row(_ container: Container) -> some View {
        VStack(alignment: .leading, spacing: RX.Space.s2) {
            HStack {
                Text(container.name).font(.rxBodyStrong).lineLimit(1)
                Spacer()
                Text(container.status)
                    .font(.system(size: 11))
                    .foregroundStyle(container.running && !container.unhealthy ? Color.rxInkSecondary : Color.rxDanger)
                    .lineLimit(1)
                Menu {
                    if container.running {
                        Button("Restart") { act("restart", container) }
                        Button("Stop") { act("stop", container) }
                    } else {
                        Button("Start") { act("start", container) }
                    }
                    Divider()
                    Button("Logs") { openTerminal(running: "docker logs -f --tail 200 \(container.name)") }
                    Button("Shell") { openTerminal(running: "docker exec -it \(container.name) sh -c 'command -v bash >/dev/null && exec bash || exec sh'") }
                        .disabled(!container.running)
                    Button("Copy ID") { UIBridge.sendPasteboard(str: container.id) }
                } label: {
                    Label("Actions", systemImage: "ellipsis")
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .buttonStyle(.rx(.plain, size: .small, iconOnly: true))
                .fixedSize()
            }
            HStack(alignment: .center, spacing: RX.Space.s3) {
                RingGauge(fraction: (Double(container.cpu.replacingOccurrences(of: "%", with: "")) ?? 0) / 100, empty: !container.running)
                    .scaleEffect(0.8)
                    .frame(width: 38, height: 38)
                column("Mem", container.memory.components(separatedBy: " / ").first ?? "—")
                column("Block R / W", container.blockIO)
                column("Net ↓ / ↑", container.netIO)
            }
        }
        .padding(RX.Space.s3)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.rxSurfaceSunken))
    }

    func column(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased()).font(.system(size: 10, weight: .medium)).foregroundStyle(.rxInkSecondary)
            Text(value.isEmpty ? "—" : value).font(.system(size: 12, weight: .semibold).monospacedDigit()).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func refresh() async {
        let command = """
        if ! command -v docker >/dev/null 2>&1; then echo 'TAMIO:NODOCKER'; \
        else docker ps -a --format '{{.ID}}\t{{.Names}}\t{{.State}}\t{{.Status}}' 2>&1; echo 'TAMIO:STATS'; \
        docker stats --no-stream --format '{{.ID}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.BlockIO}}\t{{.NetIO}}' 2>/dev/null; fi
        """
        guard let output = await session.run(command, timeout: 20) else { return }
        defer { loaded = true }
        if output.contains("TAMIO:NODOCKER") {
            problem = "Docker isn't installed on this server."
            return
        }
        let parts = output.components(separatedBy: "TAMIO:STATS")
        let listing = parts.first ?? ""
        if listing.contains("permission denied") || listing.contains("Got permission denied") {
            let user = TamioStore.shared.machineGroup[machine].loginUsername(with: TamioStore.shared.associatedIdentity(for: TamioStore.shared.machineGroup[machine]))
            problem = "\(user) can't reach the Docker socket. Add the user to the docker group."
            return
        }
        var list = listing.split(separator: "\n").compactMap { line -> Container? in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 4 else { return nil }
            return Container(id: fields[0], name: fields[1], state: fields[2], status: fields[3])
        }
        for line in (parts.count > 1 ? parts[1] : "").split(separator: "\n") {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 5, let index = list.firstIndex(where: { fields[0].hasPrefix($0.id) || $0.id.hasPrefix(fields[0]) }) else { continue }
            list[index].cpu = fields[1]
            list[index].memory = fields[2]
            list[index].blockIO = fields[3]
            list[index].netIO = fields[4]
        }
        problem = list.isEmpty ? "No containers on this server." : nil
        containers = list.sorted { lhs, rhs in
            if lhs.running != rhs.running { return lhs.running }
            return (Double(lhs.cpu.dropLast()) ?? 0) > (Double(rhs.cpu.dropLast()) ?? 0)
        }
    }

    func act(_ verb: String, _ container: Container) {
        Task {
            _ = await session.run("docker \(verb) \(container.name) 2>&1", timeout: 60)
            await refresh()
        }
    }

    func openTerminal(running command: String) {
        AppRouter.shared.openTerminal(machine: machine, initialCommand: command)
    }
}
