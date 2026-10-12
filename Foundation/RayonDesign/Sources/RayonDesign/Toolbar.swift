//
//  Toolbar.swift
//  RayonDesign
//
//  Window toolbar controls for Mac Catalyst, drawn to AppKit's measurements.
//  UIKit's Mac toolbar gives every button a glass circle of its own and packs
//  them edge to edge, where AppKit puts the buttons of a group in one capsule,
//  sets the primary action apart and centres a view switcher in the window.
//  Each control here goes in a toolbar item whose shared background is hidden.
//

#if targetEnvironment(macCatalyst)
    import SwiftUI
    import UIKit

    public enum RXToolbar {
        /// Height of every toolbar control.
        public static let height: CGFloat = 36
        /// Between the plain actions and the primary one.
        public static let spacing: CGFloat = 8
    }

    // MARK: - Capsule of symbols

    /// Symbol buttons sharing one glass capsule. Give the buttons `Label`s; only
    /// the icon is drawn, the title is the tooltip and accessibility label.
    @available(iOS 26.0, *)
    public struct RXToolbarCapsule<Content: View>: View {
        let spacing: CGFloat
        let minSlot: CGFloat
        let content: Content
        @State private var isEmpty = false

        public init(spacing: CGFloat = 0, minSlot: CGFloat = 35, @ViewBuilder content: () -> Content) {
            self.spacing = spacing
            self.minSlot = minSlot
            self.content = content()
        }

        public var body: some View {
            HStack(spacing: spacing) { content }
                .rxToolbarGlyphs(minSlot: minSlot)
                // Content that is conditional may be absent: no capsule then.
                .onGeometryChange(for: Bool.self) { $0.size.width < 1 } action: { isEmpty = $0 }
                .padding(.horizontal, 1.75)
                .frame(height: RXToolbar.height)
                .glassEffect(.regular.interactive(), in: Capsule())
                .opacity(isEmpty ? 0 : 1)
        }
    }

    public extension View {
        /// Draws the buttons inside as toolbar symbols, each in its own slot.
        func rxToolbarGlyphs(minSlot: CGFloat = 35) -> some View {
            labelStyle(RXToolbarGlyphLabelStyle(minSlot: minSlot))
                .buttonStyle(RXToolbarGlyphButtonStyle())
        }
    }

    struct RXToolbarGlyphLabelStyle: LabelStyle {
        let minSlot: CGFloat

        func makeBody(configuration: Configuration) -> some View {
            configuration.icon
                .font(.system(size: 13))
                .padding(.horizontal, 7.75)
                .frame(minWidth: minSlot, minHeight: RXToolbar.height)
                .contentShape(Rectangle())
        }
    }

    struct RXToolbarGlyphButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            GlyphBody(configuration: configuration)
        }

        struct GlyphBody: View {
            let configuration: ButtonStyleConfiguration
            @Environment(\.isEnabled) private var isEnabled

            var body: some View {
                configuration.label
                    .foregroundStyle(Color.primary.opacity(isEnabled ? 0.85 : 0.3))
                    .opacity(configuration.isPressed ? 0.55 : 1)
            }
        }
    }

    // MARK: - Trailing actions

    /// What a page's primary toolbar action needs to be drawn.
    public struct RXToolbarPrimary {
        let title: String
        let systemImage: String
        let isEnabled: Bool
        let action: () -> Void

        public init(_ title: String, systemImage: String, isEnabled: Bool = true, action: @escaping () -> Void) {
            self.title = title
            self.systemImage = systemImage
            self.isEnabled = isEnabled
            self.action = action
        }
    }

    /// The trailing end of a toolbar: the plain actions in one capsule, then the
    /// primary action in an accent capsule of its own. A primary action that is
    /// unavailable loses its tint and joins the capsule, as AppKit draws it.
    @available(iOS 26.0, *)
    public struct RXToolbarActions<Plain: View>: View {
        let spacing: CGFloat
        let minSlot: CGFloat
        let primary: RXToolbarPrimary?
        let plain: Plain

        public init(spacing: CGFloat = 0, minSlot: CGFloat = 35, primary: RXToolbarPrimary? = nil, @ViewBuilder plain: () -> Plain) {
            self.spacing = spacing
            self.minSlot = minSlot
            self.primary = primary
            self.plain = plain()
        }

        private var hasPlain: Bool { Plain.self != EmptyView.self }

        public var body: some View {
            if let primary, !primary.isEnabled, hasPlain {
                HStack(spacing: 0) {
                    HStack(spacing: spacing) { plain }
                        .rxToolbarGlyphs(minSlot: minSlot)
                        .padding(.leading, 1.75)
                    primaryLabel(primary)
                        .foregroundStyle(Color.primary.opacity(0.3))
                        .background(Capsule().fill(Color.primary.opacity(0.07)))
                        .padding(.leading, -3)
                        .help(primary.title)
                        .accessibilityLabel(primary.title)
                        .accessibilityAddTraits(.isButton)
                }
                .frame(height: RXToolbar.height)
                .glassEffect(.regular, in: Capsule())
            } else {
                HStack(spacing: RXToolbar.spacing) {
                    if hasPlain {
                        RXToolbarCapsule(spacing: spacing, minSlot: minSlot) { plain }
                    }
                    if let primary {
                        Button(action: primary.action) {
                            primaryLabel(primary)
                                .foregroundStyle(primary.isEnabled ? Color.white : Color.primary.opacity(0.3))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(primary.isEnabled ? .regular.tint(.rxAccent).interactive() : .regular, in: Capsule())
                        .disabled(!primary.isEnabled)
                        .help(primary.title)
                        .accessibilityLabel(primary.title)
                    }
                }
            }
        }

        private func primaryLabel(_ primary: RXToolbarPrimary) -> some View {
            Image(systemName: primary.systemImage)
                .font(.system(size: 10))
                .frame(width: 49.5, height: RXToolbar.height)
        }
    }

    // MARK: - View switcher

    /// A view switcher for the middle of the toolbar: equal segments in a glass
    /// capsule, the current one on a lighter pill.
    @available(iOS 26.0, *)
    public struct RXToolbarSegmented<Value: Hashable>: View {
        public struct Option {
            let value: Value
            let title: String
            let help: String

            public init(_ value: Value, _ title: String, help: String = "") {
                self.value = value
                self.title = title
                self.help = help
            }
        }

        let selection: Value
        let options: [Option]
        let select: (Value) -> Void
        /// Where the selection is drawn: it trails `selection` by the slide.
        @State private var drawn: Value?
        @Namespace private var pill
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        public init(selection: Value, options: [Option], select: @escaping (Value) -> Void) {
            self.selection = selection
            self.options = options
            self.select = select
        }

        private var memoryKey: AnyHashable { AnyHashable(options.map(\.value)) }

        public var body: some View {
            // A toolbar that has just replaced another starts where that one's
            // selection was, and slides from there.
            let drawn = drawn ?? (RXSegmentedMemory.last[memoryKey]?.base as? Value) ?? selection
            RXEqualWidths {
                ForEach(options.indices, id: \.self) { index in
                    let option = options[index]
                    let isSelected = option.value == selection
                    let isDrawn = option.value == drawn
                    Text(option.title)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.primary.opacity(0.92))
                        .lineLimit(1)
                        .padding(.horizontal, 10.6)
                        .frame(maxWidth: .infinity, minHeight: RXToolbar.height, maxHeight: RXToolbar.height)
                        .background {
                            if isDrawn {
                                Capsule()
                                    .fill(Color.primary.opacity(0.12))
                                    .matchedGeometryEffect(id: "selection", in: pill)
                                    .padding(.vertical, 4)
                                    .padding(.leading, index == 0 ? 4 : 3)
                                    .padding(.trailing, index == options.count - 1 ? 4 : 2.3)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { select(option.value) }
                        .help(option.help)
                        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .fixedSize()
            .glassEffect(.regular.interactive(), in: Capsule())
            .accessibilityElement(children: .contain)
            .onAppear { slide(to: selection) }
            .onChange(of: selection) { slide(to: $0) }
        }

        private func slide(to value: Value) {
            RXSegmentedMemory.last[memoryKey] = AnyHashable(value)
            withAnimation(reduceMotion ? nil : .rxMove) { drawn = value }
        }
    }

    // MARK: - Pull-down menu

    /// A choice in an `RXToolbarMenu`.
    public struct RXToolbarMenuItem {
        let title: String
        let systemImage: String
        let isOn: Bool
        let action: () -> Void

        public init(_ title: String, systemImage: String, isOn: Bool, action: @escaping () -> Void) {
            self.title = title
            self.systemImage = systemImage
            self.isOn = isOn
            self.action = action
        }
    }

    /// A symbol that opens a menu of exclusive choices, for a toolbar capsule.
    /// A SwiftUI `Menu` inside a toolbar item takes the item over (the toolbar
    /// shows the menu alone, with a chevron), so the menu belongs to a UIKit
    /// button, which the toolbar leaves where it is.
    public struct RXToolbarMenu: UIViewRepresentable {
        let title: String
        let systemImage: String
        let items: [RXToolbarMenuItem]

        public init(_ title: String, systemImage: String, items: [RXToolbarMenuItem]) {
            self.title = title
            self.systemImage = systemImage
            self.items = items
        }

        public func makeUIView(context _: Context) -> UIButton {
            let button = UIButton(type: .custom)
            button.preferredBehavioralStyle = .pad
            button.showsMenuAsPrimaryAction = true
            button.tintColor = UIColor.label.withAlphaComponent(0.85)
            button.setContentHuggingPriority(.required, for: .horizontal)
            return button
        }

        public func updateUIView(_ button: UIButton, context _: Context) {
            // AppKit draws a pull-down's symbol larger than a button's.
            let symbol = UIImage.SymbolConfiguration(pointSize: 16)
            button.setImage(UIImage(systemName: systemImage, withConfiguration: symbol)?.withRenderingMode(.alwaysTemplate), for: .normal)
            button.accessibilityLabel = title
            button.menu = UIMenu(children: items.map { item in
                UIAction(title: item.title, image: UIImage(systemName: item.systemImage), state: item.isOn ? .on : .off) { _ in
                    item.action()
                }
            })
        }

        public func sizeThatFits(_: ProposedViewSize, uiView: UIButton, context _: Context) -> CGSize? {
            let image = uiView.image(for: .normal)?.size.width ?? 20
            return CGSize(width: max(35, image + 15.5), height: RXToolbar.height)
        }
    }
#endif

#if targetEnvironment(macCatalyst)
    // MARK: - Search

    public extension Notification.Name {
        /// Focuses the toolbar search of the frontmost page: post it from a
        /// Find command (⌘F). A button inside the field's toolbar item would
        /// turn the whole item into a bar button.
        static let rxFocusToolbarSearch = Notification.Name("RXFocusToolbarSearch")
    }

    /// The search field at the trailing end of the toolbar. UIKit's toolbar
    /// search is lighter than AppKit's and sets its contents further in, and
    /// its placeholder is darker. Escape clears it.
    @available(iOS 26.0, *)
    public struct RXToolbarSearchField: View {
        @Binding var text: String
        let prompt: String
        @FocusState private var focused: Bool

        public init(text: Binding<String>, prompt: String) {
            _text = text
            self.prompt = prompt
        }

        public var body: some View {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(0.6))
                    .frame(width: 18)
                TextField(text: $text, prompt: Text(prompt).foregroundStyle(Color(uiColor: .secondaryLabel))) {
                    Text(prompt)
                }
                .textFieldStyle(.plain)
                .font(.system(size: 13.5))
                .focused($focused)
                .onKeyPress(.escape) {
                    guard !text.isEmpty else { return .ignored }
                    text = ""
                    return .handled
                }
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.primary.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                    .help("Clear")
                    .accessibilityLabel("Clear")
                }
            }
            .padding(.leading, 8.3)
            .padding(.trailing, 10)
            .frame(width: 325, height: RXToolbar.height)
            .fixedSize()
            .contentShape(Capsule())
            .onTapGesture { focused = true }
            .glassEffect(.regular.interactive(), in: Capsule())
            // AppKit sets search further from the items before it and from
            // the window edge than UIKit's toolbar spaces items.
            .padding(.leading, 8)
            .padding(.trailing, 4)
            .onReceive(NotificationCenter.default.publisher(for: .rxFocusToolbarSearch)) { _ in
                focused = true
            }
        }
    }

    public extension View {
        /// Search at the trailing end of the window toolbar, drawn as AppKit's.
        @ViewBuilder
        func rxToolbarSearch(text: Binding<String>, prompt: String, active: Bool = true) -> some View {
            if #available(iOS 26.0, *) {
                toolbar {
                    if active {
                        ToolbarItem(placement: .automatic) {
                            RXToolbarSearchField(text: text, prompt: prompt)
                        }
                        .sharedBackgroundVisibility(.hidden)
                    }
                }
            } else {
                searchable(text: text, placement: .toolbar, prompt: prompt)
            }
        }
    }
#endif
