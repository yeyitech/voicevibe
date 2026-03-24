import SwiftUI

struct KeyboardRootView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let showsNextKeyboardButton: Bool
    let hostHasText: Bool
    let onNextKeyboard: () -> Void
    let onPrimaryAction: () -> Void
    let onContextVoiceAction: () -> Void
    let onInsertAtSign: () -> Void
    let onInsertCommittedTranscript: (String) -> Void
    let onUndoInsertedTranscript: (String) -> Void
    let onInsertNewLine: () -> Void
    let onDeleteBackward: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let metrics = Metrics(size: geometry.size)
            let keyboardBackground = Color(uiColor: .systemBackground)

            ZStack {
                keyboardBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if viewModel.shouldShowHeader {
                        headerRow(metrics: metrics)
                            .padding(.top, metrics.headerTopPadding)
                    }

                    Spacer(minLength: viewModel.visualState == .processing ? metrics.processingTopGap : metrics.contentTopGap)

                    centerContent(metrics: metrics)

                    if let detailText = viewModel.detailText {
                        Text(detailText)
                            .font(.system(size: metrics.detailFontSize, weight: .regular))
                            .foregroundStyle(viewModel.visualState == .error ? .red : .secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.top, metrics.detailTopPadding)
                            .padding(.horizontal, metrics.horizontalPadding)
                    }

                    if viewModel.shouldShowSecondaryAction {
                        Spacer(minLength: metrics.secondaryRowTopGap)

                        secondaryActionRow(metrics: metrics)
                    }

                    Spacer(minLength: metrics.bottomSpacer)

                    bottomBar(metrics: metrics)
                }
                .padding(metrics.containerPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(keyboardBackground)
        }
    }

    private func headerRow(metrics: Metrics) -> some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                TypelessMark()
                    .frame(width: metrics.logoSize, height: metrics.logoSize)

                Text("Typeless")
                    .font(.system(size: metrics.titleFontSize, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer()

            if viewModel.shouldShowTopActions {
                HStack(spacing: metrics.topActionSpacing) {
                    circleActionButton(symbol: "@", action: onInsertAtSign, metrics: metrics)
                    circleActionButton(symbol: "return", action: onInsertNewLine, metrics: metrics)
                    circleActionButton(symbol: "delete.left", action: onDeleteBackward, metrics: metrics)
                }
            }
        }
    }

    private func centerContent(metrics: Metrics) -> some View {
        VStack(spacing: metrics.centerStackSpacing) {
            if viewModel.visualState != .processing {
                Text(viewModel.primaryPrompt)
                    .font(.system(size: metrics.promptFontSize, weight: .medium))
                    .foregroundStyle(viewModel.visualState == .error ? .red : .black.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Button(action: onPrimaryAction) {
                Group {
                    switch viewModel.visualState {
                    case .unavailable:
                        unavailablePrimaryButton(metrics: metrics)
                    case .idle:
                        idlePrimaryButton(metrics: metrics)
                    case .recording:
                        recordingOrb(metrics: metrics)
                    case .processing:
                        thinkingPill(metrics: metrics)
                    case .completed:
                        completedPrimaryButton(metrics: metrics)
                    case .error:
                        errorPrimaryButton(metrics: metrics)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canPerformPrimaryAction)
        }
        .frame(maxWidth: .infinity)
    }

    private func thinkingPill(metrics: Metrics) -> some View {
        ZStack(alignment: .trailing) {
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.6))
                .frame(width: metrics.thinkingWidth, height: metrics.thinkingHeight)

            Text("Thinking")
                .font(.system(size: metrics.thinkingFontSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: metrics.thinkingWidth, height: metrics.thinkingHeight)

            Capsule(style: .continuous)
                .fill(.black)
                .frame(width: metrics.thinkingAccentWidth, height: metrics.thinkingHeight)
        }
    }

    private func unavailablePrimaryButton(metrics: Metrics) -> some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.82))
                .frame(width: metrics.primaryWidth, height: metrics.primaryHeight)

            Image(systemName: viewModel.primaryButtonSystemImage)
                .font(.system(size: metrics.primaryIconSize, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private func idlePrimaryButton(metrics: Metrics) -> some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(.black)
                .frame(width: metrics.primaryWidth, height: metrics.primaryHeight)

            Image(systemName: viewModel.primaryButtonSystemImage)
                .font(.system(size: metrics.primaryIconSize, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    private func completedPrimaryButton(metrics: Metrics) -> some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(.black)
                .frame(width: metrics.completedWidth, height: metrics.primaryHeight)

            Image(systemName: viewModel.primaryButtonSystemImage)
                .font(.system(size: metrics.completedIconSize, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    private func errorPrimaryButton(metrics: Metrics) -> some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(.black)
                .frame(width: metrics.primaryWidth, height: metrics.primaryHeight)

            Image(systemName: viewModel.primaryButtonSystemImage)
                .font(.system(size: metrics.completedIconSize, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    private func recordingOrb(metrics: Metrics) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.55))
                .frame(width: metrics.recordingOuter, height: metrics.recordingOuter)

            Circle()
                .fill(.black)
                .frame(width: metrics.recordingInner, height: metrics.recordingInner)

            RecordingWaveformView(metrics: metrics)
        }
    }

    private func secondaryActionRow(metrics: Metrics) -> some View {
        HStack {
            if hostHasText {
                toolbarCircleButton(
                    symbol: "arrow.uturn.backward",
                    fillColor: Color(red: 0.89, green: 0.89, blue: 0.92),
                    foregroundColor: .black.opacity(0.7),
                    metrics: metrics,
                    action: {
                        if viewModel.canUndoLastInsert {
                            onUndoInsertedTranscript(viewModel.lastInsertedText)
                        } else {
                            onDeleteBackward()
                        }
                    }
                )
            } else {
                Color.clear
                    .frame(width: 72, height: 72)
            }

            Spacer()

            Button(action: onInsertNewLine) {
                Text("换行")
                    .font(.system(size: metrics.secondaryFontSize, weight: .medium))
                    .foregroundStyle(.black.opacity(0.86))
                    .frame(width: metrics.secondaryWidth, height: metrics.secondaryHeight)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(red: 0.89, green: 0.89, blue: 0.92))
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            if hostHasText {
                toolbarCircleButton(
                    symbol: "mic.fill",
                    fillColor: .white,
                    foregroundColor: .black.opacity(0.82),
                    metrics: metrics,
                    action: onContextVoiceAction
                )
            } else {
                Color.clear
                    .frame(width: 72, height: 72)
            }
        }
    }

    private func bottomBar(metrics: Metrics) -> some View {
        HStack {
            if showsNextKeyboardButton {
                Button(action: onNextKeyboard) {
                    Image(systemName: "globe")
                        .font(.system(size: metrics.globeSize, weight: .regular))
                        .foregroundStyle(.black)
                        .frame(width: metrics.globeTapSize, height: metrics.globeTapSize)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    private func circleActionButton(symbol: String, action: @escaping () -> Void, metrics: Metrics) -> some View {
        toolbarCircleButton(
            symbol: symbol,
            fillColor: Color(red: 0.91, green: 0.91, blue: 0.93),
            foregroundColor: .black.opacity(0.72),
            metrics: metrics,
            action: action
        )
    }

    private func toolbarCircleButton(
        symbol: String,
        fillColor: Color,
        foregroundColor: Color,
        metrics: Metrics,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(fillColor)
                    .frame(width: metrics.toolButtonSize, height: metrics.toolButtonSize)

                if symbol == "@" {
                    Text("@")
                        .font(.system(size: metrics.toolIconSize, weight: .medium))
                        .foregroundStyle(foregroundColor)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: metrics.toolIconSize, weight: .medium))
                        .foregroundStyle(foregroundColor)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct RecordingWaveformView: View {
    let metrics: KeyboardRootView.Metrics
    private let heights: [CGFloat] = [8, 12, 8, 20, 28, 20, 12, 18, 14]

    var body: some View {
        PhaseAnimator([0.82, 1.0, 1.16]) { scale in
            HStack(spacing: metrics.waveSpacing) {
                ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                    let multiplier: CGFloat = index.isMultiple(of: 2) ? CGFloat(scale) : CGFloat(2 - scale / 1.2)
                    Capsule(style: .continuous)
                        .fill(index == 0 || index == 1 ? Color.white.opacity(0.88) : .white)
                        .frame(width: metrics.waveWidth, height: max(metrics.waveMinHeight, height * metrics.waveScale * multiplier))
                }
            }
        } animation: { _ in
            .easeInOut(duration: 0.72).repeatForever(autoreverses: true)
        }
    }
}

private struct TypelessMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.clear)

            Path { path in
                path.move(to: CGPoint(x: 3, y: 15))
                path.addQuadCurve(to: CGPoint(x: 14, y: 4), control: CGPoint(x: 4, y: 5))
                path.addQuadCurve(to: CGPoint(x: 25, y: 13), control: CGPoint(x: 23, y: 3))
                path.addQuadCurve(to: CGPoint(x: 15, y: 24), control: CGPoint(x: 24, y: 22))
                path.addQuadCurve(to: CGPoint(x: 7, y: 20), control: CGPoint(x: 11, y: 25))
            }
            .stroke(.black, style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))

            Path { path in
                path.move(to: CGPoint(x: 8, y: 16))
                path.addQuadCurve(to: CGPoint(x: 13, y: 10), control: CGPoint(x: 9, y: 10))
                path.addQuadCurve(to: CGPoint(x: 18, y: 14), control: CGPoint(x: 17, y: 10))
            }
            .stroke(.black, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
        }
    }
}

extension KeyboardRootView {
    struct Metrics {
        let scale: CGFloat
        let panelCornerRadius: CGFloat
        let containerPadding: CGFloat
        let horizontalPadding: CGFloat
        let headerTopPadding: CGFloat
        let titleFontSize: CGFloat
        let logoSize: CGFloat
        let topActionSpacing: CGFloat
        let contentTopGap: CGFloat
        let processingTopGap: CGFloat
        let centerStackSpacing: CGFloat
        let promptFontSize: CGFloat
        let detailFontSize: CGFloat
        let detailTopPadding: CGFloat
        let secondaryRowTopGap: CGFloat
        let bottomSpacer: CGFloat
        let primaryWidth: CGFloat
        let completedWidth: CGFloat
        let primaryHeight: CGFloat
        let primaryIconSize: CGFloat
        let completedIconSize: CGFloat
        let thinkingWidth: CGFloat
        let thinkingHeight: CGFloat
        let thinkingAccentWidth: CGFloat
        let thinkingFontSize: CGFloat
        let recordingOuter: CGFloat
        let recordingInner: CGFloat
        let waveWidth: CGFloat
        let waveSpacing: CGFloat
        let waveMinHeight: CGFloat
        let waveScale: CGFloat
        let secondaryWidth: CGFloat
        let secondaryHeight: CGFloat
        let secondaryFontSize: CGFloat
        let toolButtonSize: CGFloat
        let toolIconSize: CGFloat
        let globeSize: CGFloat
        let globeTapSize: CGFloat

        init(size: CGSize) {
            let widthScale = min(max(size.width / 390, 0.8), 1.0)
            let heightScale = min(max(size.height / 236, 0.78), 1.0)
            let scale = min(widthScale, heightScale)
            self.scale = scale
            panelCornerRadius = 18 * scale
            containerPadding = 10 * scale
            horizontalPadding = 14 * scale
            headerTopPadding = 2 * scale
            titleFontSize = 18 * scale
            logoSize = 20 * scale
            topActionSpacing = 8 * scale
            contentTopGap = 10 * scale
            processingTopGap = 20 * scale
            centerStackSpacing = 10 * scale
            promptFontSize = 16 * scale
            detailFontSize = 12 * scale
            detailTopPadding = 8 * scale
            secondaryRowTopGap = 10 * scale
            bottomSpacer = 2 * scale
            primaryWidth = 148 * scale
            completedWidth = 166 * scale
            primaryHeight = 64 * scale
            primaryIconSize = 26 * scale
            completedIconSize = 24 * scale
            thinkingWidth = 152 * scale
            thinkingHeight = 60 * scale
            thinkingAccentWidth = 22 * scale
            thinkingFontSize = 17 * scale
            recordingOuter = 118 * scale
            recordingInner = 98 * scale
            waveWidth = 5 * scale
            waveSpacing = 5 * scale
            waveMinHeight = 4 * scale
            waveScale = 0.6 * scale
            secondaryWidth = 116 * scale
            secondaryHeight = 44 * scale
            secondaryFontSize = 15 * scale
            toolButtonSize = 42 * scale
            toolIconSize = 17 * scale
            globeSize = 22 * scale
            globeTapSize = 34 * scale
        }
    }
}
