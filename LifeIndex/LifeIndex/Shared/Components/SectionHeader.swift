import SwiftUI

struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: Theme.IconSize.md, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(Theme.title)
                .foregroundStyle(color)
        }
    }
}
