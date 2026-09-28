import SwiftUI

struct MenuBarPreferencesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("A quieter menu bar")
                .font(.title2.weight(.semibold))
            HStack(spacing: 16) {
                StatusItemView()
                    .padding(12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) {
                    Text("SpotMenu").font(.headline)
                    Text("One small logo. No track titles, badges, or moving indicators.")
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            Label("Click to show or hide the player", systemImage: "cursorarrow.click")
            Label("Right-click for preferences and other options", systemImage: "line.3.horizontal")
            Text("Track details and playback controls live in the player. The logo automatically adapts to your menu bar’s appearance.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    MenuBarPreferencesView()
}
