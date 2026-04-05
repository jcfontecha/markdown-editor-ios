import UIKit
import SwiftUI

// MARK: - Bridge

@Observable
@MainActor
final class CommandBarActions {
    weak var editor: (any MarkdownEditorInterface)?

    func undo() { editor?.undo() }
    func redo() { editor?.redo() }
    func toggleBold() { editor?.applyFormatting(.bold) }
    func toggleItalic() { editor?.applyFormatting(.italic) }
    func toggleStrikethrough() { editor?.applyFormatting(.strikethrough) }
    func setUnorderedList() { editor?.setBlockType(.unorderedList) }
    func setOrderedList() { editor?.setBlockType(.orderedList) }
    func setHeading1() { editor?.setBlockType(.heading(level: .h1)) }
    func setHeading2() { editor?.setBlockType(.heading(level: .h2)) }
    func dismissKeyboard() { editor?.textView.resignFirstResponder() }
}

// MARK: - SwiftUI Content

struct CommandBarContentView: View {
    var actions: CommandBarActions

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Undo / Redo
                    iconGroup {
                        iconButton("arrow.uturn.left", label: "Undo", action: actions.undo)
                        iconButton("arrow.uturn.right", label: "Redo", action: actions.redo)
                    }

                    // Formatting
                    iconGroup {
                        iconButton("bold", label: "Bold", action: actions.toggleBold)
                        iconButton("italic", label: "Italic", action: actions.toggleItalic)
                        iconButton("strikethrough", label: "Strikethrough", action: actions.toggleStrikethrough)
                    }

                    // Lists
                    iconGroup {
                        iconButton("list.bullet", label: "Bullet List", action: actions.setUnorderedList)
                        iconButton("list.number", label: "Numbered List", action: actions.setOrderedList)
                    }

                    // Headings
                    HStack(spacing: 0) {
                        textButton("Title", action: actions.setHeading1)
                        textButton("Subtitle", action: actions.setHeading2)
                    }
                    .commandBarGlass(.capsule)
                }
                .padding(.horizontal, 16)
            }
            .commandBarScrollEffect()
            .scrollClipDisabled()

            // Pinned dismiss keyboard
            iconButton("keyboard.chevron.compact.down", label: "Dismiss Keyboard", action: actions.dismissKeyboard)
                .commandBarGlass(.circle)
                .padding(.trailing, 12)
        }
        .frame(height: 56)
    }

    // MARK: - Buttons

    private func iconGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) {
            content()
        }
        .commandBarGlass(.capsule)
    }

    private func iconButton(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        UIKitCommandBarButton(
            label: label,
            content: .icon(systemName),
            action: action
        )
        .frame(width: 44, height: 44)
    }

    private func textButton(_ title: String, action: @escaping () -> Void) -> some View {
        UIKitCommandBarButton(
            label: title,
            content: .title(title),
            action: action
        )
        .frame(height: 44)
    }
}

private enum CommandBarGlassShape {
    case capsule
    case circle
}

private extension View {
    @ViewBuilder
    func commandBarGlass(_ shape: CommandBarGlassShape) -> some View {
        if #available(iOS 26.0, *) {
            switch shape {
            case .capsule:
                self.glassEffect(.regular.interactive(), in: .capsule)
            case .circle:
                self.glassEffect(.regular.interactive(), in: .circle)
            }
        } else {
            switch shape {
            case .capsule:
                self
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.18), lineWidth: 0.75)
                    }
            case .circle:
                self
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.18), lineWidth: 0.75)
                    }
            }
        }
    }

    @ViewBuilder
    func commandBarScrollEffect() -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            self
        }
    }
}

private enum CommandBarButtonContent {
    case icon(String)
    case title(String)
}

private struct UIKitCommandBarButton: UIViewRepresentable {
    let label: String
    let content: CommandBarButtonContent
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = .clear
        button.tintColor = .label
        button.accessibilityLabel = label
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleTap), for: .touchUpInside)

        switch content {
        case .icon(let systemName):
            let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
            button.setImage(UIImage(systemName: systemName, withConfiguration: configuration), for: .normal)
            button.contentHorizontalAlignment = .center
            button.contentVerticalAlignment = .center

        case .title(let title):
            button.setTitle(title, for: .normal)
            button.setTitleColor(.label, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
            button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        }

        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        context.coordinator.action = action
        button.accessibilityLabel = label
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func handleTap() {
            action()
        }
    }
}

// MARK: - Non-stealing hosting controller

/// Prevents the hosting controller from stealing first responder from the text editor.
/// Without this, tapping SwiftUI buttons in the inputAccessoryView causes the UITextView
/// to resign first responder, which corrupts the Lexical editor state.
private class NonStealingHostingController<Content: View>: UIHostingController<Content> {
    override var canBecomeFirstResponder: Bool { false }
    override var canResignFirstResponder: Bool { false }
}

// MARK: - UIView Wrapper

public class MarkdownCommandBar: UIView {
    public weak var editor: (any MarkdownEditorInterface)? {
        didSet { actions.editor = editor }
    }

    private let actions = CommandBarActions()
    private var _hostingController: NonStealingHostingController<CommandBarContentView>?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupContent()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupContent()
    }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 56)
    }

    private func setupContent() {
        backgroundColor = .clear

        let hc = NonStealingHostingController(rootView: CommandBarContentView(actions: actions))
        hc.view.backgroundColor = .clear
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        hc.sizingOptions = .intrinsicContentSize

        addSubview(hc.view)
        NSLayoutConstraint.activate([
            hc.view.topAnchor.constraint(equalTo: topAnchor),
            hc.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hc.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        _hostingController = hc
    }
}
