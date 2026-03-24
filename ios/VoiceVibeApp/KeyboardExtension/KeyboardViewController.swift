import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
    private static let keyboardHeight: CGFloat = 236
    private static let keyboardBackgroundColor = UIColor.systemGray5
    private let commandStore = SharedRecorderCommandStore()
    private let viewModel = KeyboardViewModel()
    private var hostingController: UIHostingController<KeyboardRootView>?
    private var heightConstraint: NSLayoutConstraint?

    override func loadView() {
        super.loadView()
        view.backgroundColor = Self.keyboardBackgroundColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboardView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshRootView()
        viewModel.refresh()
        viewModel.handleKeyboardPresented()
    }

    override func textDidChange(_ textInput: (any UITextInput)?) {
        super.textDidChange(textInput)
        refreshRootView()
    }

    override func updateViewConstraints() {
        super.updateViewConstraints()

        if heightConstraint == nil {
            let constraint = view.heightAnchor.constraint(equalToConstant: Self.keyboardHeight)
            constraint.priority = .required
            constraint.isActive = true
            heightConstraint = constraint
        }
    }

    private func setupKeyboardView() {
        let controller = UIHostingController(rootView: makeRootView())
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.backgroundColor = Self.keyboardBackgroundColor

        addChild(controller)
        view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        controller.didMove(toParent: self)

        hostingController = controller
    }

    private func refreshRootView() {
        hostingController?.rootView = makeRootView()
    }

    private func makeRootView() -> KeyboardRootView {
        KeyboardRootView(
            viewModel: viewModel,
            showsNextKeyboardButton: needsInputModeSwitchKey,
            hostHasText: hasHostText,
            onNextKeyboard: { [weak self] in
                self?.advanceToNextInputMode()
            },
            onPrimaryAction: { [weak self] in
                guard let self else { return }
                print("[Keyboard] Primary tapped. visualState=\(self.viewModel.statusTitle)")

                switch self.viewModel.visualState {
                case .idle, .error:
                    guard self.viewModel.isHostReachable else {
                        print("[Keyboard] Host unavailable, ignoring START")
                        return
                    }
                    print("[Keyboard] Requesting START")
                    self.commandStore.save(SharedRecorderCommand(action: .start))
                case .recording:
                    print("[Keyboard] Requesting STOP")
                    self.commandStore.save(SharedRecorderCommand(action: .stop))
                case .processing:
                    print("[Keyboard] Ignored tap while processing")
                    break
                case .unavailable:
                    print("[Keyboard] Host unavailable visual state, ignoring tap")
                    break
                case .completed:
                    guard self.viewModel.canPerformPrimaryAction else { return }
                    let text = self.viewModel.insertableText
                    guard !text.isEmpty else { return }
                    print("[Keyboard] Inserting final transcript, count=\(text.count)")
                    self.textDocumentProxy.insertText(text)
                    self.viewModel.markInsertedCurrentResult()
                }
            },
            onContextVoiceAction: { [weak self] in
                guard let self, self.viewModel.isHostReachable else {
                    print("[Keyboard] Host unavailable, ignoring context voice action")
                    return
                }
                self.commandStore.save(SharedRecorderCommand(action: .start))
            },
            onInsertAtSign: { [weak self] in
                self?.textDocumentProxy.insertText("@")
            },
            onInsertCommittedTranscript: { [weak self] text in
                guard !text.isEmpty else { return }
                self?.textDocumentProxy.insertText(text)
                self?.viewModel.markInsertedCurrentResult()
            },
            onUndoInsertedTranscript: { [weak self] text in
                guard !text.isEmpty else { return }
                for _ in text {
                    self?.textDocumentProxy.deleteBackward()
                }
                self?.viewModel.clearInsertedResult()
            },
            onInsertNewLine: { [weak self] in
                self?.textDocumentProxy.insertText("\n")
            },
            onDeleteBackward: { [weak self] in
                self?.textDocumentProxy.deleteBackward()
            }
        )
    }

    private var hasHostText: Bool {
        let beforeText = textDocumentProxy.documentContextBeforeInput?.isEmpty == false
        let afterText = textDocumentProxy.documentContextAfterInput?.isEmpty == false
        return beforeText || afterText
    }
}
