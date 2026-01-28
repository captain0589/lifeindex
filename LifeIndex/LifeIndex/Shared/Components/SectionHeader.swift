import SwiftUI

struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        Label(title, systemImage: icon)
            .font(Theme.title)
            .foregroundStyle(color)
    }
}
