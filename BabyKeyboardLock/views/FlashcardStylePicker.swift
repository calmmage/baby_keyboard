import SwiftUI

struct FlashcardStylePicker: View {
    @Binding var enabledStyles: Set<FlashcardStyle>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Style")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 8)
            ], spacing: 8) {
                Button(action: {
                    enabledStyles = []
                }) {
                    Text("No Image")
                        .font(.system(size: 12))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity)
                        .background(enabledStyles.isEmpty ? Color.accentColor : Color.gray.opacity(0.2))
                        .foregroundColor(enabledStyles.isEmpty ? .white : .primary)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                ForEach(FlashcardStyle.allCases, id: \.self) { style in
                    Button(action: {
                        if enabledStyles.contains(style) {
                            enabledStyles.remove(style)
                        } else {
                            enabledStyles.insert(style)
                        }
                    }) {
                        Text(style.title)
                            .font(.system(size: 12))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity)
                            .background(enabledStyles.contains(style) ? Color.accentColor : Color.gray.opacity(0.2))
                            .foregroundColor(enabledStyles.contains(style) ? .white : .primary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
} 
