import UIKit

// MARK: - Toolbar Configuration

public struct ToolbarStyle {
    public let spacing: CGFloat
    public let buttonSize: CGFloat
    public let selectedColor: UIColor
    public let buttonTintColor: UIColor
    
    public static let `default` = ToolbarStyle(
        spacing: 16,
        buttonSize: 32, // Fixed size like DanceNotes
        selectedColor: UIColor.systemBlue,
        buttonTintColor: UIColor.label
    )
    
    public static let compact = ToolbarStyle(
        spacing: 12,
        buttonSize: 32, // Fixed size like DanceNotes
        selectedColor: UIColor.systemBlue,
        buttonTintColor: UIColor.label
    )
    
    public static let spacious = ToolbarStyle(
        spacing: 20,
        buttonSize: 32, // Fixed size like DanceNotes
        selectedColor: UIColor.systemBlue,
        buttonTintColor: UIColor.label
    )
}

// MARK: - Formatting Toolbar

public final class MarkdownFormattingToolbar: UIView {
    
    public weak var editor: MarkdownEditor? {
        didSet { setupEditorObservation() }
    }
    
    public var style: ToolbarStyle = .default {
        didSet { applyStyle() }
    }
    
    private let stackView: UIStackView
    private var formattingButtons: [UIButton] = []
    private var headingButtons: [UIButton] = []
    
    public init(style: ToolbarStyle = .default) {
        self.style = style
        self.stackView = UIStackView()
        super.init(frame: .zero)
        setupView()
        setupButtons()
        applyStyle()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        backgroundColor = .systemBackground
        layer.borderColor = UIColor.separator.cgColor
        layer.borderWidth = 0.33
        
        addSubview(stackView)
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 8
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            heightAnchor.constraint(equalToConstant: 48) // Fixed height for 32px buttons + padding
        ])
    }
    
    private func applyStyle() {
        stackView.spacing = style.spacing
        
        // Update all buttons with clean styling
        updateButtonStyles()
    }
    
    private func updateButtonStyles() {
        for button in formattingButtons + headingButtons {
            styleButton(button)
        }
    }
    
    private func styleButton(_ button: UIButton) {
        // Clean, modern button styling - no background, no borders
        button.backgroundColor = UIColor.clear
        button.layer.cornerRadius = 0
        button.layer.borderWidth = 0
        button.tintColor = style.buttonTintColor
        
        // Set fixed 32x32 size like DanceNotes for clean, consistent appearance
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 32),
            button.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        // Remove all padding/insets for clean look
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            button.configuration = config
        } else {
            button.contentEdgeInsets = UIEdgeInsets.zero
        }
    }
    
    private func setupButtons() {
        // Heading buttons
        let h1Button = createHeadingButton(level: .h1, title: "H1")
        let h2Button = createHeadingButton(level: .h2, title: "H2")
        let h3Button = createHeadingButton(level: .h3, title: "H3")
        
        headingButtons = [h1Button, h2Button, h3Button]
        headingButtons.forEach { stackView.addArrangedSubview($0) }
        
        // Separator
        stackView.addArrangedSubview(createSeparator())
        
        // Formatting buttons
        let boldButton = createFormattingButton(
            formatting: .bold,
            image: UIImage(systemName: "bold"),
            accessibilityLabel: "Bold"
        )
        
        let italicButton = createFormattingButton(
            formatting: .italic,
            image: UIImage(systemName: "italic"),
            accessibilityLabel: "Italic"
        )
        
        let strikethroughButton = createFormattingButton(
            formatting: .strikethrough,
            image: UIImage(systemName: "strikethrough"),
            accessibilityLabel: "Strikethrough"
        )
        
        formattingButtons = [boldButton, italicButton, strikethroughButton]
        formattingButtons.forEach { stackView.addArrangedSubview($0) }
        
        // Separator
        stackView.addArrangedSubview(createSeparator())
        
        // Block type buttons
        let listButton = createBlockTypeButton(
            blockType: .unorderedList,
            image: UIImage(systemName: "list.bullet"),
            accessibilityLabel: "Bullet List"
        )
        
        let numberedListButton = createBlockTypeButton(
            blockType: .orderedList,
            image: UIImage(systemName: "list.number"),
            accessibilityLabel: "Numbered List"
        )
        
        let quoteButton = createBlockTypeButton(
            blockType: .quote,
            image: UIImage(systemName: "quote.opening"),
            accessibilityLabel: "Quote"
        )
        
        stackView.addArrangedSubview(listButton)
        stackView.addArrangedSubview(numberedListButton)
        stackView.addArrangedSubview(quoteButton)
        
        // Add flexible space
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stackView.addArrangedSubview(spacer)
    }
    
    private func createFormattingButton(
        formatting: InlineFormatting,
        image: UIImage?,
        accessibilityLabel: String
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(image, for: .normal)
        button.accessibilityLabel = accessibilityLabel
        
        styleButton(button)
        
        button.addAction(UIAction { [weak self] _ in
            self?.editor?.applyFormatting(formatting)
            self?.updateButtonStates()
        }, for: .touchUpInside)
        
        return button
    }
    
    private func createHeadingButton(level: MarkdownBlockType.HeadingLevel, title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.accessibilityLabel = "Heading \(level.rawValue)"
        
        styleButton(button)
        
        button.addAction(UIAction { [weak self] _ in
            self?.editor?.setBlockType(.heading(level: level))
            self?.updateButtonStates()
        }, for: .touchUpInside)
        
        return button
    }
    
    private func createBlockTypeButton(
        blockType: MarkdownBlockType,
        image: UIImage?,
        accessibilityLabel: String
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(image, for: .normal)
        button.accessibilityLabel = accessibilityLabel
        
        styleButton(button)
        
        button.addAction(UIAction { [weak self] _ in
            self?.editor?.setBlockType(blockType)
            self?.updateButtonStates()
        }, for: .touchUpInside)
        
        return button
    }
    
    private func createSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = UIColor.separator.withAlphaComponent(0.3)
        separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
        separator.heightAnchor.constraint(equalToConstant: 20).isActive = true
        return separator
    }
    
    private func setupEditorObservation() {
        // Set up observation of editor state changes
        // This would be enhanced to observe selection changes in a real implementation
        updateButtonStates()
    }
    
    private func updateButtonStates() {
        guard let editor = editor else { return }
        
        let currentFormatting = editor.getCurrentFormatting()
        let currentBlockType = editor.getCurrentBlockType()
        
        // Update formatting button states with clean tint color changes
        if let boldButton = formattingButtons.first(where: { $0.accessibilityLabel == "Bold" }) {
            boldButton.tintColor = currentFormatting.contains(.bold) ? style.selectedColor : style.buttonTintColor
        }
        
        if let italicButton = formattingButtons.first(where: { $0.accessibilityLabel == "Italic" }) {
            italicButton.tintColor = currentFormatting.contains(.italic) ? style.selectedColor : style.buttonTintColor
        }
        
        if let strikethroughButton = formattingButtons.first(where: { $0.accessibilityLabel == "Strikethrough" }) {
            strikethroughButton.tintColor = currentFormatting.contains(.strikethrough) ? style.selectedColor : style.buttonTintColor
        }
        
        // Update heading button states
        for button in headingButtons {
            button.tintColor = style.buttonTintColor
        }
        
        if case .heading(let level) = currentBlockType {
            if let headingButton = headingButtons.first(where: { $0.accessibilityLabel == "Heading \(level.rawValue)" }) {
                headingButton.tintColor = style.selectedColor
            }
        }
    }
}