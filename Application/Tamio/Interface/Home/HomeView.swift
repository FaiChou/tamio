//
//  HomeView.swift
//  Tamio (macOS)
//
//  Start page: every server's live status card in a dense grid, straight
//  under the toolbar (search and New Server at the top right, no title row),
//  and beside them the inspector of the card that is selected.
//

import MachineStatusView
import SwiftUI
import TamioDesign
import TamioModule

struct HomeView: View {
    @State private var search = ""

    var body: some View {
        // The toolbar is set here, on a view that redraws only when the
        // search changes: rebuilding toolbar items on every resize makes
        // AppKit lay the title bar out as two rows.
        HomeContent(search: search)
            .pageChrome()
            .pageToolbar(
                primary: ToolbarAction("New Server", systemImage: "plus", primary: true) {
                    AppRouter.shared.presentNewServer = true
                },
                trailingMetrics: .group,
                search: ($search, "Search servers")
            ) {} trailing: {}
    }
}

private struct HomeContent: View {
    let search: String

    @EnvironmentObject var store: TamioStore
    @State private var selection: RDMachine.ID?
    /// The page's width, to share it between the cards and the inspector.
    @State private var pageWidth: CGFloat = 900

    /// The inspector gives up width before the cards go too narrow.
    var inspectorWidth: CGFloat {
        min(ServerInspector.width, max(300, pageWidth - StatusCard.minimumWidth - RX.Space.s4 * 2))
    }

    var machines: [RDMachine] {
        let all = store.machineGroup.machines
        let needle = search.trimmingCharacters(in: .whitespaces)
        return needle.isEmpty ? all : all.filter { $0.isQualifiedForSearch(text: needle) }
    }

    var body: some View {
        // The inspector is a panel beside the cards under the toolbar, never
        // under it: the toolbar's search and New Server stay on their own row
        // and take every click.
        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                content
                    .padding(.horizontal, RX.Space.s4)
                    .padding(.top, RX.Space.s1)
                    .padding(.bottom, RX.Space.s6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeInOut(duration: 0.25), value: machines.map(\.id))
            }
            .frame(minWidth: StatusCard.minimumWidth + RX.Space.s4 * 2, maxWidth: .infinity)
            if let selection, store.machineGroup.machines.contains(where: { $0.id == selection }) {
                ServerInspector(machine: selection) { self.selection = nil }
                    .frame(width: inspectorWidth)
                    // Only the panel moves: the cards take their new width at
                    // once, not frame by frame, so they never stutter.
                    .transition(.move(edge: .trailing).combined(with: .opacity)
                        .animation(.spring(response: 0.3, dampingFraction: 0.9)))
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width.rounded() } action: { pageWidth = $0 }
        .background {
            // Esc closes the inspector.
            if selection != nil {
                Button("Close Inspector") { selection = nil }
                    .keyboardShortcut(.cancelAction)
                    .hidden()
            }
        }
    }

    @ViewBuilder var content: some View {
        if store.machineGroup.machines.isEmpty {
            EmptyStateView(
                "Save a server to reach it in one click",
                systemImage: "server.rack",
                message: "Its live load, CPU, memory, disk and traffic show here, and it opens a terminal or files in one click.",
                actionTitle: "New Server"
            ) {
                AppRouter.shared.presentNewServer = true
            }
            .frame(maxWidth: 640)
            .rxCard()
        } else if machines.isEmpty {
            EmptyStateView("No servers match “\(search)”", systemImage: "magnifyingglass")
                .rxCard()
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: StatusCard.minimumWidth, maximum: StatusCard.maximumWidth), spacing: RX.Space.s3, alignment: .top)],
                alignment: .leading,
                spacing: RX.Space.s3
            ) {
                ForEach(Array(machines.enumerated()), id: \.element.id) { index, machine in
                    // A click shows the card's server in the panel; the panel's
                    // close button and Esc put it away.
                    StatusCard(machine: machine.id, selected: selection == machine.id) {
                        if selection != machine.id { selection = machine.id }
                    }
                    .rxRise(index)
                    .transition(.scale(scale: 0.97).combined(with: .opacity))
                }
            }
        }
    }
}
