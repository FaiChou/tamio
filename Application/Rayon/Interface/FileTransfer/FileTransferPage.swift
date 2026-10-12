//
//  FileTransferPage.swift
//  Rayon (macOS)
//
//  SFTP inside the main window: Up, breadcrumb, Go to Folder, filter, Reload,
//  New Folder, Upload, Download. Table: name, size, modified, permissions, owner.
//  Transfer card with speed and Cancel. Drag files in to upload. Double-click a
//  file to edit it.
//

import RayonModule
import SwiftUI
import UniformTypeIdentifiers

struct FileTransferPage: View {
    @ObservedObject var context: FileTransferContext
    @EnvironmentObject var store: RayonStore

    @State private var filter = ""
    @State private var selection: FileTransferContext.RemoteFile?
    @State private var prompt: FilePrompt?
    @State private var dropTargeted = false

    /// The whole folder in the table's order: folders first, then by name.
    /// Sorted when the folder changes, not on every redraw: a transfer's
    /// progress redraws the page many times a second.
    @State private var sorted: [FileTransferContext.RemoteFile] = []
    /// What the table shows: `sorted`, less what the filter leaves out.
    @State private var files: [FileTransferContext.RemoteFile] = []
    /// Counts the changes of `files`, so the table needn't compare lists.
    @State private var revision = 0
    /// Counts the folder listings, so a slow sort of an old one is dropped.
    @State private var listing = 0

    nonisolated static func sort(_ list: [FileTransferContext.RemoteFile]) -> [FileTransferContext.RemoteFile] {
        // The kind is read once per file, not once per comparison.
        var keyed = list.map { (isDirectory: $0.fstat.isDirectory, file: $0) }
        keyed.sort { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.file.name.localizedStandardCompare(rhs.file.name) == .orderedAscending
        }
        return keyed.map(\.file)
    }

    private func show(sorted list: [FileTransferContext.RemoteFile]) {
        sorted = list
        // A reload reads every file anew; one that is gone is no longer chosen.
        if let chosen = selection { selection = list.first { $0.name == chosen.name && $0.base == chosen.base } }
        applyFilter()
    }

    /// Filtering keeps the order, so typing in the filter never sorts.
    private func applyFilter() {
        let needle = filter.lowercased()
        files = needle.isEmpty ? sorted : sorted.filter { $0.name.lowercased().contains(needle) }
        revision += 1
    }

    private func arrange(_ list: [FileTransferContext.RemoteFile]) {
        listing += 1
        // A long folder is sorted off the main thread; a short one takes less
        // than a frame, and showing it at once avoids a flash of the old one.
        guard list.count > 1000 else { return show(sorted: Self.sort(list)) }
        let expected = listing
        nonisolated(unsafe) let list = list
        DispatchQueue.global(qos: .userInitiated).async {
            nonisolated(unsafe) let result = Self.sort(list)
            DispatchQueue.main.async {
                if listing == expected { show(sorted: result) }
            }
        }
    }

    var busy: Bool { context.processConnection || context.isProgressRunning }

    var body: some View {
        PageScaffold(
            scrolls: false,
            primary: ToolbarAction(
                "Download",
                systemImage: "arrow.down.doc",
                primary: true,
                isEnabled: selection != nil && !busy && context.connected
            ) {
                if let selection { download(selection) }
            }
        ) {
            ToolbarAction("Enclosing Folder", systemImage: "arrow.up") { goUp() }
                .disabled(context.currentUrl.pathComponents.count <= 1 || busy || !context.connected)
                .keyboardShortcut(.upArrow, modifiers: .command)
            ToolbarAction("Go to Folder", systemImage: "arrow.turn.down.right") { prompt = .goTo }
                .disabled(busy || !context.connected)
                .keyboardShortcut("g", modifiers: [.command, .shift])
        } trailing: {
            ToolbarAction("Reload", systemImage: "arrow.clockwise") { context.loadCurrentFileList() }
                .disabled(busy || !context.connected)
                .keyboardShortcut("r", modifiers: .command)
            ToolbarAction("New Folder", systemImage: "folder.badge.plus") { prompt = .newFolder }
                .disabled(busy || !context.connected)
            ToolbarAction("Upload", systemImage: "arrow.up.doc") { upload() }
                .disabled(busy || !context.connected)
        } header: {
            VStack(alignment: .leading, spacing: RX.Space.s2) {
                PageTitle(store.machineRedacted == .all ? "File Transfer" : context.machine.name, subtitle: subtitle)
                HStack(spacing: RX.Space.s3) {
                    Breadcrumb(url: context.currentUrl) { path in
                        context.navigate(path: path)
                    }
                    .disabled(busy || !context.connected)
                    Spacer(minLength: RX.Space.s2)
                    // In the page, not the toolbar: this page stays mounted while
                    // hidden, and a toolbar search field would stay with it.
                    RXSearchField("Filter this folder", text: $filter, width: 200)
                }
            }
        } content: {
            VStack(spacing: RX.Space.s4) {
                if context.destroyedSession || (!context.connected && !context.processConnection) {
                    EmptyStateView(
                        "Connection closed",
                        systemImage: "bolt.horizontal",
                        message: context.currentHint == "Connection Closed" ? "" : context.currentHint,
                        actionTitle: context.destroyedSession ? nil : "Reconnect"
                    ) {
                        context.processBootstrap()
                    }
                    .rxCard()
                    Spacer()
                } else if context.processConnection, context.currentFileList.isEmpty {
                    VStack(spacing: RX.Space.s3) {
                        ProgressView()
                            .rxSpinner()
                        Text(context.currentHint.isEmpty ? "Connecting…" : context.currentHint)
                            .font(.rxBody)
                            .foregroundStyle(.rxInkSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(RX.Space.s6)
                    .rxCard()
                    Spacer()
                } else {
                    fileTable
                }
                if context.isProgressRunning, !context.processConnection {
                    transferCard
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted, perform: handleDrop)
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: RX.Radius.card, style: .continuous)
                    .strokeBorder(Color.rxAccent, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .background(Color.rxAccentFill.clipShape(RoundedRectangle(cornerRadius: RX.Radius.card, style: .continuous)))
                    .overlay(
                        Label("Drop to upload to \(context.currentDir)", systemImage: "arrow.up.doc")
                            .font(.rxBodyStrong)
                            .foregroundStyle(.rxAccent)
                    )
                    .padding(RX.Space.s4)
                    .allowsHitTesting(false)
            }
        }
        .sheet(item: $prompt) { prompt in
            FilePromptSheet(prompt: prompt, context: context) { self.prompt = nil }
        }
        .onChange(of: context.currentDir) { _ in selection = nil }
        .onReceive(context.$currentFileList) { arrange($0) }
        .onChange(of: filter) { _ in applyFilter() }
        #if DEBUG
            .onReceive(NotificationCenter.default.publisher(for: .benchFiles)) { note in
                if let index = note.userInfo?["select"] as? Int, files.indices.contains(index) { selection = files[index] }
                if let text = note.userInfo?["filter"] as? String { filter = text }
            }
        #endif
        .serverToolSwitcher(machine: context.machine.id, current: .files)
    }

    var subtitle: String {
        store.machineRedacted == .none ? context.machine.getCommand(insertLeadingSSH: false) : ""
    }

    // MARK: Table

    var fileTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TableHeaderLabel("Name").frame(maxWidth: .infinity)
                TableHeaderLabel("Size", alignment: .trailing).frame(width: 90)
                Color.clear.frame(width: RX.Space.s4, height: 1)
                TableHeaderLabel("Modified").frame(width: 150)
                TableHeaderLabel("Permissions").frame(width: 110)
                TableHeaderLabel("Owner").frame(width: 70)
            }
            .padding(.horizontal, RX.Space.s3)
            .frame(height: RX.tableHeaderHeight)
            Hairline()
            if files.isEmpty {
                EmptyStateView(
                    filter.isEmpty ? "Empty folder" : "No matches",
                    systemImage: "folder",
                    message: ""
                )
                Spacer(minLength: 0)
            } else {
                FileTable(
                    files: files,
                    folder: context.currentDir,
                    revision: revision,
                    selection: selection,
                    select: { selection = $0 },
                    open: open,
                    menu: menu(for:)
                )
            }
        }
        .padding(RX.Space.s2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear.rxCard(padding: 0))
        .disabled(busy)
        .opacity(busy ? 0.6 : 1)
    }

    func menu(for file: FileTransferContext.RemoteFile) -> UIMenu {
        func group(_ actions: [UIAction]) -> UIMenu {
            UIMenu(options: .displayInline, children: actions)
        }
        return UIMenu(children: [
            group([
                file.fstat.isDirectory
                    ? UIAction(title: "Open") { _ in open(file) }
                    : UIAction(title: "Edit") { _ in edit(file) },
                UIAction(title: "Download…") { _ in download(file) },
            ]),
            group([
                UIAction(title: "Rename…") { _ in prompt = .rename(file.name) },
                UIAction(title: "Copy Name") { _ in UIBridge.sendPasteboard(str: file.name) },
                UIAction(title: "Copy Path") { _ in
                    UIBridge.sendPasteboard(str: context.currentUrl.appendingPathComponent(file.name).path)
                },
            ]),
            group([UIAction(title: "Delete…", attributes: .destructive) { _ in delete(file) }]),
        ])
    }

    // MARK: Transfer card

    var transferCard: some View {
        let total = context.totalProgress
        let current = context.currentProgress
        let fraction: Double? = total.totalUnitCount > 0
            ? total.fractionCompleted
            : (current.totalUnitCount > 0 ? current.fractionCompleted : nil)
        var detail: [String] = []
        if total.totalUnitCount > 1 {
            detail.append("\(total.completedUnitCount) of \(total.totalUnitCount)")
        }
        if context.currentSpeed > 0 {
            detail.append(RXFormat.rateString(Double(context.currentSpeed)))
        }
        let name = context.currentProcessingFile.isEmpty
            ? (context.currentHint.isEmpty ? "Working…" : context.currentHint)
            : URL(fileURLWithPath: context.currentProcessingFile).lastPathComponent
        return VStack(alignment: .leading, spacing: RX.Space.s2) {
            CardHead("Transfer")
            ProgressRowView(
                title: name,
                detail: detail.joined(separator: " · "),
                fraction: fraction,
                cancel: context.currentProgressCancelable && context.continueCurrentProgress
                    ? { context.continueCurrentProgress = false }
                    : nil
            )
        }
        .rxCard()
    }

    // MARK: Actions

    func goUp() {
        context.navigate(path: context.currentUrl.deletingLastPathComponent().path)
    }

    func open(_ file: FileTransferContext.RemoteFile) {
        if file.fstat.isDirectory {
            context.navigate(path: context.currentUrl.appendingPathComponent(file.name).path)
        } else if Int64(truncating: file.fstat.size ?? 0) <= FileTransferContext.editableSizeLimit {
            edit(file)
        } else {
            download(file)
        }
    }

    func edit(_ file: FileTransferContext.RemoteFile) {
        AppRouter.shared.openEditor(context: context, path: context.currentUrl.appendingPathComponent(file.name).path)
    }

    func upload() {
        Mac.bridge?.openPanel(
            message: "Upload to \(context.currentDir)",
            prompt: "Upload",
            directory: nil,
            canChooseFiles: true,
            canChooseDirectories: true,
            allowsMultipleSelection: true,
            canCreateDirectories: false,
            showsHiddenFiles: false
        ) { urls in
            if !urls.isEmpty { context.upload(urls: urls) }
        }
    }

    func download(_ file: FileTransferContext.RemoteFile) {
        let remote = context.currentUrl.appendingPathComponent(file.name)
        Mac.bridge?.openPanel(
            message: "Choose where to save \(file.name)",
            prompt: "Download Here",
            directory: nil,
            canChooseFiles: false,
            canChooseDirectories: true,
            allowsMultipleSelection: false,
            canCreateDirectories: true,
            showsHiddenFiles: false
        ) { urls in
            if let url = urls.first { context.download(from: remote, toDir: url) }
        }
    }

    func delete(_ file: FileTransferContext.RemoteFile) {
        let item = context.currentUrl.appendingPathComponent(file.name)
        UIBridge.requiresConfirmation(
            message: "Delete \(file.name)?",
            informative: file.fstat.isDirectory
                ? "The folder and everything in it is deleted from the server. This cannot be undone."
                : "The file is deleted from the server. This cannot be undone.",
            confirmTitle: "Delete",
            destructive: true
        ) { confirmed in
            if confirmed { context.delete(item: item) }
        }
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard context.connected, !busy else { return false }
        let group = DispatchGroup()
        nonisolated(unsafe) var urls: [URL] = []
        let lock = NSLock()
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            if !urls.isEmpty { context.upload(urls: urls) }
        }
        return true
    }
}

// MARK: - Rows

/// A folder's rows in a UIKit table. Only the rows on screen exist, however long
/// the folder is, and a redraw of the page costs the table nothing unless the
/// list or the selection changed.
private struct FileTable: UIViewRepresentable {
    typealias File = FileTransferContext.RemoteFile

    let files: [File]
    /// The folder `files` came from once `revision` has moved on.
    let folder: String
    let revision: Int
    let selection: File?
    let select: (File) -> Void
    let open: (File) -> Void
    let menu: (File) -> UIMenu

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITableView {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.rowHeight = RX.denseRowHeight
        table.estimatedRowHeight = RX.denseRowHeight
        table.sectionHeaderTopPadding = 0
        // Clicks and hover are the rows' own.
        table.allowsSelection = false
        table.allowsFocus = false
        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        table.register(FileCell.self, forCellReuseIdentifier: Coordinator.reuse)
        return table
    }

    // Nothing is done to the table here. Moving it re-tests what the pointer is
    // over, and that test reads the SwiftUI graph this update is in the middle
    // of: entering a folder with the pointer over the list never returned.
    func updateUIView(_ table: UITableView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.enabled = context.environment.isEnabled
        coordinator.schedule(table)
    }

    final class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {
        static var reuse: String { "file" }
        var parent: FileTable
        var enabled = true
        /// What the table shows, which is `parent`'s once `apply` has run.
        private var rows: [File]
        private var shownRevision: Int
        private var shownSelection: File?
        private var shownFolder: String?
        private var scheduled = false

        init(_ parent: FileTable) {
            self.parent = parent
            rows = parent.files
            shownRevision = parent.revision
            shownSelection = parent.selection
        }

        func schedule(_ table: UITableView) {
            guard !scheduled else { return }
            scheduled = true
            DispatchQueue.main.async { [weak self, weak table] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.scheduled = false
                    if let table { self.apply(to: table) }
                }
            }
        }

        private func apply(to table: UITableView) {
            if table.isUserInteractionEnabled != enabled { table.isUserInteractionEnabled = enabled }
            if shownRevision != parent.revision {
                // Another folder starts at its top and fades in; a reload or the
                // filter changes the rows in place.
                let entered = shownFolder != parent.folder && shownFolder != nil
                rows = parent.files
                if entered, !UIAccessibility.isReduceMotionEnabled {
                    UIView.transition(with: table, duration: 0.18, options: [.transitionCrossDissolve, .allowUserInteraction]) {
                        table.reloadData()
                        table.contentOffset = .zero
                    }
                } else {
                    table.reloadData()
                    if entered { table.contentOffset = .zero }
                }
                shownRevision = parent.revision
                shownFolder = parent.folder
            } else if shownSelection != parent.selection {
                for case let cell as FileCell in table.visibleCells {
                    cell.setChosen(cell.file == parent.selection, animated: true)
                }
            }
            shownSelection = parent.selection
        }

        func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
            rows.count
        }

        func tableView(_ table: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = table.dequeueReusableCell(withIdentifier: Self.reuse, for: indexPath)
            guard let cell = cell as? FileCell else { return cell }
            let file = rows[indexPath.row]
            cell.show(file, chosen: file == parent.selection)
            cell.onClick = { [weak self] in self?.parent.select(file) }
            cell.onDoubleClick = { [weak self] in self?.parent.open(file) }
            return cell
        }

        func tableView(_: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point _: CGPoint) -> UIContextMenuConfiguration? {
            guard rows.indices.contains(indexPath.row) else { return nil }
            let file = rows[indexPath.row]
            let menu = parent.menu
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in menu(file) }
        }
    }
}

/// A line of text drawn as SwiftUI's `Text` draws it. A label pulls the letters
/// of a truncated name together and so cuts it a character later, and it
/// spaces the digits of a size a fraction of a point apart.
private final class FileCellText: UIView {
    var text = "" { didSet { if text != oldValue { setNeedsDisplay() } } }
    var textColor = UIColor.label { didSet { if textColor != oldValue { setNeedsDisplay() } } }
    var font = UIFont.systemFont(ofSize: 13)
    var trailing = false

    private static let paragraph: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingMiddle
        style.allowsDefaultTighteningForTruncation = false
        return style
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        contentMode = .redraw
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: textColor, .paragraphStyle: Self.paragraph,
        ]
        let string = text as NSString
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        let scale = max(traitCollection.displayScale, 1)
        let fitted = string.boundingRect(
            with: CGSize(width: bounds.width, height: .greatestFiniteMagnitude),
            options: options, attributes: attributes, context: nil
        )
        let width = min(bounds.width, (fitted.width * scale).rounded(.up) / scale)
        let height = (fitted.height * scale).rounded(.up) / scale
        let y = ((bounds.height - height) / 2 * scale).rounded() / scale
        string.draw(
            with: CGRect(x: trailing ? bounds.width - width : 0, y: y, width: trailing ? width : bounds.width, height: height),
            options: options, attributes: attributes, context: nil
        )
    }
}

/// One file: symbol and name, size, date, permissions, owner. Drawn with UIKit
/// views to the measurements of the SwiftUI rows elsewhere in the app.
private final class FileCell: UITableViewCell {
    private(set) var file: FileTransferContext.RemoteFile?
    var onClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?

    private var isChosen = false
    private var isHovered = false

    private let row = UIView()
    private let icon = UIImageView()
    private let name = FileCellText()
    private let size = FileCellText()
    private let modified = UILabel()
    private let permissions = UILabel()
    private let owner = UILabel()

    private static let ink = UIColor(Color.rxInk)
    private static let inkSecondary = UIColor(Color.rxInkSecondary)
    private static let accent = UIColor(Color.rxAccent)
    private static let rowSelected = UIColor(Color.rxRowSelected)
    private static let rowHover = UIColor(Color.rxRowHover)
    private static let body = UIFont.systemFont(ofSize: 13)
    private static let digits = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
    private static let code = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private static let symbol = UIImage.SymbolConfiguration(font: .systemFont(ofSize: 14))
    private static let symbols: [String: UIImage] = ["folder", "link", "doc"].reduce(into: [:]) {
        $0[$1] = UIImage(systemName: $1, withConfiguration: symbol)
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    private static let ownerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundConfiguration = .clear()
        focusEffect = nil

        row.layer.cornerRadius = RX.Radius.lg
        row.layer.cornerCurve = .continuous
        contentView.addSubview(row)

        icon.contentMode = .center
        name.font = Self.body
        name.textColor = Self.ink
        size.font = Self.digits
        size.trailing = true
        modified.font = Self.body
        modified.textColor = Self.inkSecondary
        permissions.font = Self.code
        permissions.textColor = Self.inkSecondary
        owner.font = Self.digits
        owner.textColor = Self.inkSecondary
        for view in [icon, name, size, modified, permissions, owner] { row.addSubview(view) }

        let click = UITapGestureRecognizer(target: self, action: #selector(clicked))
        let doubleClick = UITapGestureRecognizer(target: self, action: #selector(doubleClicked))
        doubleClick.numberOfTapsRequired = 2
        // The first click selects at once; it doesn't wait to see whether a
        // second follows.
        click.delegate = self
        doubleClick.delegate = self
        contentView.addGestureRecognizer(click)
        contentView.addGestureRecognizer(doubleClick)
        contentView.addGestureRecognizer(UIHoverGestureRecognizer(target: self, action: #selector(hovered(_:))))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(_ file: FileTransferContext.RemoteFile, chosen: Bool) {
        self.file = file
        let stat = file.fstat
        let isDirectory = stat.isDirectory
        icon.image = Self.symbols[isDirectory ? "folder" : (stat.isLink ? "link" : "doc")]
        icon.tintColor = isDirectory ? Self.accent : Self.inkSecondary
        name.text = file.name
        size.text = isDirectory ? "—" : RXFormat.bytesString(Double(truncating: stat.size ?? 0))
        size.textColor = isDirectory ? Self.inkSecondary : Self.ink
        modified.text = stat.modificationDate.map { Self.dateFormatter.string(from: $0) } ?? "—"
        permissions.text = stat.permissionDescription
        owner.text = Self.ownerFormatter.string(from: NSNumber(value: stat.ownerUID))
        isHovered = false
        isChosen = chosen
        refreshBackground(animated: false)
        setNeedsLayout()
    }

    func setChosen(_ chosen: Bool, animated: Bool) {
        guard chosen != isChosen else { return }
        isChosen = chosen
        refreshBackground(animated: animated)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        row.frame = contentView.bounds
        let height = row.bounds.height
        var trailing = row.bounds.width - RX.Space.s3
        func place(_ view: UIView, width: CGFloat) {
            trailing -= width
            view.frame = CGRect(x: trailing, y: 0, width: width, height: height)
        }
        place(owner, width: 70)
        place(permissions, width: 110)
        place(modified, width: 150)
        trailing -= RX.Space.s4
        place(size, width: 90)
        icon.frame = CGRect(x: RX.Space.s3, y: 0, width: 18, height: height)
        let nameLeading = icon.frame.maxX + RX.Space.s2
        name.frame = CGRect(x: nameLeading, y: 0, width: max(0, trailing - nameLeading), height: height)
    }

    private func refreshBackground(animated: Bool) {
        let color = isChosen ? Self.rowSelected : (isHovered ? Self.rowHover : .clear)
        guard animated else { return row.backgroundColor = color }
        UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]) {
            self.row.backgroundColor = color
        }
    }

    @objc private func clicked() { onClick?() }
    @objc private func doubleClicked() { onDoubleClick?() }

    @objc private func hovered(_ recognizer: UIHoverGestureRecognizer) {
        let hovering = recognizer.state == .began || recognizer.state == .changed
        guard hovering != isHovered else { return }
        isHovered = hovering
        refreshBackground(animated: true)
    }

    override func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
        true
    }
}

/// The current remote folder: one clickable segment per folder, the last in `ink` semibold.
/// Long paths collapse middle segments into "…".
struct Breadcrumb: View {
    let url: URL
    let navigate: (String) -> Void

    var body: some View {
        let components = url.pathComponents
        let indices = Array(components.indices)
        let shown: [Int?] = indices.count > 5
            ? [indices[0], nil] + indices.suffix(3).map { Optional($0) }
            : indices.map { Optional($0) }
        HStack(spacing: 2) {
            ForEach(Array(shown.enumerated()), id: \.offset) { position, index in
                if position > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.rxInkTertiary)
                }
                if let index {
                    let isLast = index == components.count - 1
                    Button {
                        navigate(path(upTo: index))
                    } label: {
                        Text(components[index])
                            .font(.system(size: 13, weight: isLast ? .semibold : .regular))
                            .foregroundStyle(isLast ? Color.rxInk : Color.rxInkSecondary)
                            .lineLimit(1)
                            .padding(.horizontal, 4)
                            .frame(height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isLast)
                } else {
                    Text("…").foregroundStyle(.rxInkSecondary)
                }
            }
        }
        .layoutPriority(1)
    }

    func path(upTo index: Int) -> String {
        let components = url.pathComponents.prefix(index + 1)
        guard components.count > 1 else { return "/" }
        return "/" + components.dropFirst().joined(separator: "/")
    }
}

// MARK: - Prompts

enum FilePrompt: Identifiable {
    case goTo
    case newFolder
    case rename(String)

    var id: String {
        switch self {
        case .goTo: return "goto"
        case .newFolder: return "folder"
        case let .rename(name): return "rename-\(name)"
        }
    }
}

/// Go to Folder, New Folder and Rename as small sheets.
private struct FilePromptSheet: View {
    let prompt: FilePrompt
    @ObservedObject var context: FileTransferContext
    let close: () -> Void

    @State private var text = ""

    var title: String {
        switch prompt {
        case .goTo: return "Go to Folder"
        case .newFolder: return "New Folder"
        case .rename: return "Rename"
        }
    }

    var error: String? {
        switch prompt {
        case .goTo:
            return text.hasPrefix("/") || text.isEmpty ? nil : "Use an absolute path starting with /."
        case .newFolder, .rename:
            if text.isEmpty { return nil }
            if !text.isValidAsFilename { return "That name contains characters a file name cannot have." }
            if case let .rename(original) = prompt, original == text { return nil }
            if context.currentFileList.contains(where: { $0.name == text }) { return "“\(text)” already exists in this folder." }
            return nil
        }
    }

    var body: some View {
        SheetScaffold(title) {
            RXField(prompt.label, error: error) {
                TextField(prompt.placeholder, text: $text)
                    .textFieldStyle(prompt.isPath ? .rxMono : .rx)
                    .disableAutocorrection(true)
                    .onSubmit(confirm)
            }
        } footer: {
            Spacer()
            Button("Cancel", action: close)
                .buttonStyle(.rx)
                .keyboardShortcut(.cancelAction)
            Button(prompt.confirmTitle, action: confirm)
                .buttonStyle(.rxPrimary)
                .keyboardShortcut(.defaultAction)
                .disabled(text.isEmpty || error != nil)
        }
        .frame(width: 420)
        .onAppear {
            switch prompt {
            case .goTo: text = context.currentDir
            case .newFolder: text = ""
            case let .rename(name): text = name
            }
        }
    }

    func confirm() {
        guard !text.isEmpty, error == nil else { return }
        switch prompt {
        case .goTo:
            context.navigate(path: text)
        case .newFolder:
            context.createFolder(with: text)
        case let .rename(original):
            if original != text {
                let base = context.currentUrl
                context.rename(from: base.appendingPathComponent(original), to: base.appendingPathComponent(text))
            }
        }
        close()
    }
}

private extension FilePrompt {
    var label: String {
        switch self {
        case .goTo: return "Path"
        case .newFolder, .rename: return "Name"
        }
    }

    var placeholder: String {
        switch self {
        case .goTo: return "/var/log"
        case .newFolder: return "untitled folder"
        case .rename: return "Name"
        }
    }

    var confirmTitle: String {
        switch self {
        case .goTo: return "Go"
        case .newFolder: return "Create"
        case .rename: return "Rename"
        }
    }

    var isPath: Bool {
        if case .goTo = self { return true }
        return false
    }
}

enum FileTransferSessionActions {
    /// Closes a server's SFTP session, and with it the editor that works over it.
    @MainActor
    static func close(_ context: FileTransferContext) {
        let unsaved = EditorCenter.shared.workspaces.first { $0.id == context.id }?.hasUnsavedChanges == true
        if context.isProgressRunning || unsaved {
            UIBridge.requiresConfirmation(
                message: "Close the file transfer on \(context.machine.name)?",
                informative: unsaved
                    ? "Files open in the editor have changes that are not saved. They are lost if you close."
                    : "A transfer is still running and will be interrupted.",
                confirmTitle: unsaved ? "Discard Changes" : "Close",
                destructive: true,
                always: unsaved
            ) { confirmed in
                if confirmed { FileTransferManager.shared.end(for: context.id) }
            }
        } else {
            FileTransferManager.shared.end(for: context.id)
        }
    }
}
