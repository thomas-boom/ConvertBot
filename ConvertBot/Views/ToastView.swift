import SwiftUI

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundColor(.primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
            )
            .padding(.top, 8)
    }
}
