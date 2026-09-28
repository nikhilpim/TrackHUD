import SwiftUI

/// Mirrors the native menu-bar button in Settings without any track metadata.
struct StatusItemView: View {
    var body: some View {
        Image(nsImage: SpotMenuLogo.image)
            .renderingMode(.template)
            .frame(width: 24, height: 24)
            .accessibilityLabel("SpotMenu")
    }
}

#Preview {
    StatusItemView()
}
