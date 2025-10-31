import SwiftUI

struct FlashcardStylePicker: View {
    @Binding var selectedStyle: FlashcardStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Style")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 8)
            ], spacing: 8) {
                ForEach(FlashcardStyle.allCases, id: \.self) { style in
                    Button(action: {
                        selectedStyle = style
                    }) {
                        Text(style.title)
                            .font(.system(size: 12))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity)
                            .background(selectedStyle == style ? Color.accentColor : Color.gray.opacity(0.2))
                            .foregroundColor(selectedStyle == style ? .white : .primary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
} 