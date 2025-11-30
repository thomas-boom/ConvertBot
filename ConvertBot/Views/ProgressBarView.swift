import SwiftUI

struct ProgressBarView: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            // Determine a sensible bar height based on container; fall back to a compact size
            let containerHeight = geo.size.height > 0 ? geo.size.height : 16
            let barHeight = max(6, min(containerHeight, 18))
            let cornerRadius = max(4, barHeight / 2)
            let inset: CGFloat = max(1, barHeight * 0.12)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .frame(height: barHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )

                RoundedRectangle(cornerRadius: cornerRadius - inset)
                    .fill(Color.accentColor.opacity(0.9))
                    .frame(width: max((geo.size.width * CGFloat(progress)) - inset * 2, 0), height: barHeight - inset * 2)
                    .animation(.easeInOut(duration: 0.18), value: progress)
                    .padding(.leading, inset)
                    .padding(.vertical, inset)
            }
            // Hide percentage text in compact bars (keeps the layout balanced when embedded small)
            .overlay(alignment: .trailing) {
                if containerHeight >= 20 {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
            }
        }
        // Prefer a compact default height when not constrained by parent
        .frame(height: UIConstants.progressBarHeight)
    }
}
