import SwiftUI

struct CategoryPicker: View {
    @Binding var selection: PinCategory?

    var body: some View {
        CategoryGallery(
            selection: Binding(
                get: { selection ?? .place },
                set: { selection = $0 }
            ),
            horizontal: true
        )
#if os(watchOS)
        .frame(height: 52)
#else
        .frame(height: 168)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
#endif
    }
}

struct CategoryGallery: View {
    @Binding var selection: PinCategory
    var hint: String?
    var showsChrome: Bool = false
    var horizontal: Bool = false
    var onConfirm: ((PinCategory) -> Void)?

    private let categories = PinCategory.alphabetically

#if os(watchOS)
    private let centerSize: CGFloat = 64
#else
    private let centerSize: CGFloat = 108
#endif

    var body: some View {
#if os(watchOS)
        if horizontal {
            watchHorizontal
        } else {
            watchGallery
        }
#else
        phoneGallery
#endif
    }

#if os(watchOS)
    private var watchGallery: some View {
        TabView(selection: $selection) {
            ForEach(categories, id: \.self) { category in
                watchPage(category)
            }
        }
        .tabViewStyle(.verticalPage)
        .onChange(of: selection) { _, _ in
            PinoHaptics.click()
        }
    }

    private func watchPage(_ category: PinCategory) -> some View {
        VStack(spacing: 6) {
            Button {
                confirmOrSelect(category)
            } label: {
                Text(category.emoji)
                    .font(.system(size: 40))
                    .frame(width: centerSize, height: centerSize)
                    .background(Circle().fill(Color.pino))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(category.label)
            .accessibilityHint(hint ?? category.label)
            Text(category.label)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if let hint {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tag(category)
    }

    private var watchHorizontal: some View {
        WatchHorizontalScroll(
            selection: $selection,
            categories: categories,
            onConfirm: onConfirm
        )
        .focusable()
        .digitalCrownRotation(
            crownIndex,
            from: 0,
            through: Double(max(categories.count - 1, 0)),
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: false
        )
        .onChange(of: selection) { _, _ in
            PinoHaptics.click()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(selection.label)
        .accessibilityAdjustableAction(nudgeSelection)
    }

    private var crownIndex: Binding<Double> {
        Binding(
            get: { Double(categories.firstIndex(of: selection) ?? 0) },
            set: { raw in
                let index = min(max(Int(raw.rounded()), 0), categories.count - 1)
                selection = categories[index]
            }
        )
    }

    private func nudgeSelection(_ direction: AccessibilityAdjustmentDirection) {
        guard let index = categories.firstIndex(of: selection) else { return }
        switch direction {
        case .increment:
            if index + 1 < categories.count { selection = categories[index + 1] }
        case .decrement:
            if index > 0 { selection = categories[index - 1] }
        @unknown default:
            break
        }
    }

    private func confirmOrSelect(_ category: PinCategory) {
        if let onConfirm {
            onConfirm(category)
        } else {
            selection = category
        }
    }
#else
    private var phoneGallery: some View {
        VStack(spacing: 8) {
            Text(selection.label)
                .font(.headline)
            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            PhoneCategoryScroll(
                selection: $selection,
                categories: categories,
                centerSize: centerSize,
                onConfirm: onConfirm
            )
            .frame(height: centerSize + 12)
        }
        .padding(.top, showsChrome ? 14 : 4)
        .padding(.bottom, showsChrome ? 28 : 4)
        .frame(maxWidth: .infinity)
        .background {
            if showsChrome {
                Rectangle().fill(.ultraThinMaterial)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(selection.label)
        .accessibilityHint(hint ?? "")
        .accessibilityAdjustableAction(nudgeSelection)
        .onChange(of: selection) { _, _ in
            PinoHaptics.click()
        }
    }

    private func nudgeSelection(_ direction: AccessibilityAdjustmentDirection) {
        guard let index = categories.firstIndex(of: selection) else { return }
        switch direction {
        case .increment:
            if index + 1 < categories.count { selection = categories[index + 1] }
        case .decrement:
            if index > 0 { selection = categories[index - 1] }
        @unknown default:
            break
        }
    }
#endif
}

#if os(watchOS)
private struct WatchHorizontalScroll: View {
    @Binding var selection: PinCategory
    let categories: [PinCategory]
    var onConfirm: ((PinCategory) -> Void)?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let card = min(max(width * 0.42, 52), 70)
            WatchCategoryRow(
                selection: $selection,
                categories: categories,
                card: card,
                inset: max((width - card) / 2, 0),
                onConfirm: onConfirm
            )
        }
    }
}

private struct WatchCategoryRow: View {
    @Binding var selection: PinCategory
    let categories: [PinCategory]
    var card: CGFloat
    var inset: CGFloat
    var onConfirm: ((PinCategory) -> Void)?
    @State private var positioned: PinCategory?
    @State private var canSync = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { category in
                        WatchCategoryItem(
                            category: category,
                            card: card,
                            isSelected: category == selection,
                            onTap: { tap(category) }
                        )
                        .id(category)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $positioned)
            .contentMargins(.horizontal, inset, for: .scrollContent)
            .onAppear { reveal(proxy) }
            .onChange(of: positioned) { _, value in
                guard canSync, let value else { return }
                selection = value
            }
            .onChange(of: selection) { _, value in
                guard positioned != value else { return }
                positioned = value
                proxy.scrollTo(value, anchor: .center)
            }
        }
    }

    private func reveal(_ proxy: ScrollViewProxy) {
        positioned = selection
        proxy.scrollTo(selection, anchor: .center)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            canSync = true
        }
    }

    private func tap(_ category: PinCategory) {
        if category == selection, let onConfirm {
            onConfirm(category)
        } else {
            selection = category
        }
    }
}

private struct WatchCategoryItem: View {
    let category: PinCategory
    var card: CGFloat
    var isSelected: Bool
    var onTap: () -> Void

    private var size: CGFloat { isSelected ? 44 : 30 }

    var body: some View {
        Button(action: onTap) {
            Text(category.emoji)
                .font(.system(size: size * 0.52))
                .frame(width: card, height: 44)
                .background {
                    Circle()
                        .fill(isSelected ? Color.pino : Color.white.opacity(0.2))
                        .frame(width: size, height: size)
                }
        }
        .buttonStyle(.plain)
        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.82)
                .opacity(phase.isIdentity ? 1 : 0.5)
        }
        .accessibilityLabel(category.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
#else
private struct PhoneCategoryScroll: View {
    @Binding var selection: PinCategory
    let categories: [PinCategory]
    var centerSize: CGFloat
    var onConfirm: ((PinCategory) -> Void)?
    @State private var positioned: PinCategory
    @State private var canSync = false

    init(
        selection: Binding<PinCategory>,
        categories: [PinCategory],
        centerSize: CGFloat,
        onConfirm: ((PinCategory) -> Void)?
    ) {
        self._selection = selection
        self.categories = categories
        self.centerSize = centerSize
        self.onConfirm = onConfirm
        _positioned = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > 32 {
                let card = min(max(geo.size.width * 0.34, 92), 128)
                let inset = max((geo.size.width - card) / 2, 0)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(categories, id: \.self) { category in
                            PhoneCategoryItem(
                                category: category,
                                card: card,
                                centerSize: centerSize,
                                isSelected: category == selection,
                                onTap: { tap(category) }
                            )
                            .id(category)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollPosition(id: scrollID, anchor: .center)
                .contentMargins(.horizontal, inset, for: .scrollContent)
            }
        }
        .task { await reveal() }
        .onChange(of: selection) { _, value in
            guard positioned != value else { return }
            positioned = value
        }
    }

    private var scrollID: Binding<PinCategory?> {
        Binding(
            get: { positioned },
            set: { newValue in
                guard canSync, let newValue else { return }
                positioned = newValue
                if newValue != selection {
                    selection = newValue
                }
            }
        )
    }

    private func reveal() async {
        positioned = selection
        try? await Task.sleep(for: .milliseconds(80))
        positioned = selection
        try? await Task.sleep(for: .milliseconds(220))
        positioned = selection
        canSync = true
    }

    private func tap(_ category: PinCategory) {
        if category == selection, let onConfirm {
            onConfirm(category)
        } else {
            canSync = true
            positioned = category
            selection = category
        }
    }
}

private struct PhoneCategoryItem: View {
    let category: PinCategory
    var card: CGFloat
    var centerSize: CGFloat
    var isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(category.emoji)
                .font(.system(size: card * (isSelected ? 0.46 : 0.38)))
                .frame(width: card, height: centerSize)
                .background {
                    Circle()
                        .fill(isSelected ? Color.pino : Color.white.opacity(0.92))
                        .frame(
                            width: isSelected ? centerSize : centerSize * 0.72,
                            height: isSelected ? centerSize : centerSize * 0.72
                        )
                        .shadow(color: .black.opacity(isSelected ? 0.28 : 0.12), radius: isSelected ? 10 : 4, y: 3)
                }
        }
        .buttonStyle(.plain)
        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.78)
                .opacity(phase.isIdentity ? 1 : 0.55)
        }
        .accessibilityLabel(category.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
#endif
