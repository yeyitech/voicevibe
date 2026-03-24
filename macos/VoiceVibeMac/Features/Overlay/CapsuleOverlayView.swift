import SwiftUI

struct CapsuleOverlayView: View {
    let state: OverlayState

    var body: some View {
        HStack(spacing: 8) {
            stateDot
            compactIndicator
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        )
    }

    private var stateDot: some View {
        Circle()
            .fill(state.tint)
            .frame(width: 7, height: 7)
    }

    @ViewBuilder
    private var compactIndicator: some View {
        switch state {
        case .recording:
            AnimatedBarsView(tint: state.tint)
        case .transcribing:
            AnimatedDotsView(tint: state.tint)
        case .readyToInsert:
            Image(systemName: "doc.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(state.tint)
        case .inserted:
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(state.tint)
        case .error:
            Image(systemName: "exclamationmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(state.tint)
        }
    }
}

private struct AnimatedBarsView: View {
    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(tint)
                        .frame(width: 3, height: barHeight(index: index, time: time))
                }
            }
            .frame(width: 18, height: 14, alignment: .center)
        }
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        let phase = time * 7 + Double(index) * 0.8
        let normalized = (sin(phase) + 1) / 2
        return 5 + normalized * 8
    }
}

private struct AnimatedDotsView: View {
    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.16)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(tint.opacity(dotOpacity(index: index, time: time)))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 18, height: 14, alignment: .center)
        }
    }

    private func dotOpacity(index: Int, time: TimeInterval) -> Double {
        let phase = time * 5 + Double(index) * 0.9
        return 0.3 + ((sin(phase) + 1) / 2) * 0.7
    }
}
