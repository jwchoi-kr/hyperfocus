import SwiftUI

struct PopoverNavBar: View {
    let title: String
    let backLabel: String
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.headline)
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(backLabel)
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}
