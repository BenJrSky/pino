import SwiftUI

private struct CategoryLoopItem: Hashable {
    let copy: Int
    let category: PinCategory
}

private enum CategoryLoop {
    static let copies = 5
    static var middle: Int { copies / 2 }

    static func items(_ categories: [PinCategory]) -> [CategoryLoopItem] {
        (0..<copies).flatMap { copy in
            categories.map { CategoryLoopItem(copy: copy, category: $0) }
        }
    }

    static func middleItem(for category: PinCategory) -> CategoryLoopItem {
        CategoryLoopItem(copy: middle, category: category)
    }

    static func step(from item: CategoryLoopItem, to category: PinCategory, categories: [PinCategory]) -> CategoryLoopItem {
        let count = categories.count
        guard count > 0,
              let origin = categories.firstIndex(of: item.category),
              let target = categories.firstIndex(of: category)
        else { return middleItem(for: category) }
        if origin == target { return item }
        var delta = target - origin
        if delta > count / 2 { delta -= count }
        if delta < -count / 2 { delta += count }
        return clamped(flat: item.copy * count + origin + delta, categories: categories)
    }

    static func recentered(_ item: CategoryLoopItem) -> CategoryLoopItem {
        item.copy == 0 || item.copy == copies - 1 ? middleItem(for: item.category) : item
    }

    private static func clamped(flat: Int, categories: [PinCategory]) -> CategoryLoopItem {
        let count = max(categories.count, 1)
        let total = copies * count
        let index = ((flat % total) + total) % total
        return CategoryLoopItem(copy: index / count, category: categories[index % count])
    }
}

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
                CategoryEmoji(category: category, fontSize: 40, swipeAxis: .horizontal)
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
            isContinuous: true,
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
                let count = categories.count
                guard count > 0 else { return }
                var index = Int(raw.rounded()) % count
                if index < 0 { index += count }
                selection = categories[index]
            }
        )
    }

    private func nudgeSelection(_ direction: AccessibilityAdjustmentDirection) {
        let count = categories.count
        guard count > 0, let index = categories.firstIndex(of: selection) else { return }
        switch direction {
        case .increment:
            selection = categories[(index + 1) % count]
        case .decrement:
            selection = categories[(index - 1 + count) % count]
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
        let count = categories.count
        guard count > 0, let index = categories.firstIndex(of: selection) else { return }
        switch direction {
        case .increment:
            selection = categories[(index + 1) % count]
        case .decrement:
            selection = categories[(index - 1 + count) % count]
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
            CategoryEmoji(category: category, fontSize: size * 0.52, swipeAxis: .vertical)
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
    @State private var positioned: CategoryLoopItem
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
        _positioned = State(initialValue: CategoryLoop.middleItem(for: selection.wrappedValue))
    }

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > 32 {
                let card = min(max(geo.size.width * 0.34, 92), 128)
                let inset = max((geo.size.width - card) / 2, 0)
                let items = CategoryLoop.items(categories)
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(items, id: \.self) { item in
                                PhoneCategoryItem(
                                    category: item.category,
                                    card: card,
                                    centerSize: centerSize,
                                    isSelected: item.category == selection,
                                    onTap: { tap(item.category) }
                                )
                                .id(item)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: scrollID, anchor: .center)
                    .contentMargins(.horizontal, inset, for: .scrollContent)
                    .task { await reveal(proxy) }
                }
            }
        }
        .onChange(of: selection) { _, value in
            guard canSync, positioned.category != value else { return }
            apply(CategoryLoop.step(from: positioned, to: value, categories: categories))
        }
    }

    private var scrollID: Binding<CategoryLoopItem?> {
        Binding(
            get: { positioned },
            set: { newValue in
                guard canSync, let newValue else { return }
                if newValue.category != selection {
                    selection = newValue.category
                }
                apply(newValue)
            }
        )
    }

    private func apply(_ item: CategoryLoopItem) {
        let target = CategoryLoop.recentered(item)
        guard target != positioned else { return }
        if target.copy != item.copy {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                positioned = target
            }
        } else {
            positioned = target
        }
    }

    private func reveal(_ proxy: ScrollViewProxy) async {
        canSync = false
        let target = CategoryLoop.middleItem(for: selection)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            positioned = target
        }
        proxy.scrollTo(target, anchor: .center)
        try? await Task.sleep(for: .milliseconds(50))
        proxy.scrollTo(target, anchor: .center)
        try? await Task.sleep(for: .milliseconds(200))
        proxy.scrollTo(target, anchor: .center)
        canSync = true
    }

    private func tap(_ category: PinCategory) {
        if category == selection, let onConfirm {
            onConfirm(category)
        } else {
            canSync = true
            apply(CategoryLoop.step(from: positioned, to: category, categories: categories))
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
            CategoryEmoji(category: category, fontSize: card * (isSelected ? 0.46 : 0.38), swipeAxis: .vertical)
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

private struct CategoryEmoji: View {
    let category: PinCategory
    var fontSize: CGFloat
    var swipeAxis: Axis
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        Text(category.emoji(tone: category.takesSkinTone ? settings.skinTone : .none))
            .font(.system(size: fontSize))
            .overlay(alignment: .top) {
                if category.takesSkinTone {
                    Color.clear
                        .frame(height: fontSize * 0.52)
                        .contentShape(Rectangle())
                        .simultaneousGesture(swipe)
                }
            }
            .accessibilityAdjustableAction(adjust)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 14)
            .onEnded { value in
                switch swipeAxis {
                case .vertical:
                    guard abs(value.translation.height) > abs(value.translation.width) else { return }
                    shift(value.translation.height < 0 ? 1 : -1)
                case .horizontal:
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    shift(value.translation.width < 0 ? 1 : -1)
                }
            }
    }

    private func adjust(_ direction: AccessibilityAdjustmentDirection) {
        guard category.takesSkinTone else { return }
        switch direction {
        case .increment: shift(1)
        case .decrement: shift(-1)
        @unknown default: break
        }
    }

    private func shift(_ delta: Int) {
        settings.skinTone = settings.skinTone.advanced(by: delta)
        PinoHaptics.click()
    }
}
