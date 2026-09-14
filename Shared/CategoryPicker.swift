import SwiftUI

struct CategoryPicker: View {
    @Binding var selection: PinCategory?

#if os(watchOS)
    private let columns = 4
#else
    private let columns = 6
#endif

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 6) {
            ForEach(PinCategory.allCases) { category in
                Button {
                    selection = category
                } label: {
                    VStack(spacing: 2) {
                        Text(category.emoji)
                            .font(.title2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(selection == category ? Color.primary.opacity(0.18) : Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
				.accessibilityLabel(category.label)
            }
        }
    }
}
