import UIKit
import FluentUI

public class MarkdownCommandBar: UIView {
    private var commandBar: CommandBar!
    private var gradientView: UIView!
    private var gradientLayer: CAGradientLayer!
    
    public weak var editor: MarkdownEditorView? {
        didSet {
            updateButtonStates()
        }
    }
    
    public override init(frame: CGRect) {
        print("🔵 MarkdownCommandBar.init(frame:) - Creating CommandBar with frame: \(frame)")
        super.init(frame: frame)
        self.backgroundColor = .clear
        setupGradientBackground()
        setupCommandBar()
        print("🔵 MarkdownCommandBar.init(frame:) - Setup complete")
    }
    
    public required init?(coder: NSCoder) {
        print("🔵 MarkdownCommandBar.init(coder:) - Creating CommandBar from coder")
        super.init(coder: coder)
        setupGradientBackground()
        setupCommandBar()
        print("🔵 MarkdownCommandBar.init(coder:) - Setup complete")
    }
    
    deinit {
        print("🔴 MarkdownCommandBar.deinit - CommandBar being deallocated")
    }
    
    private func setupGradientBackground() {
        gradientView = UIView()
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        
        gradientLayer = CAGradientLayer()
        updateGradientColors() // Set initial colors
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)  // Top
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)    // Bottom
        
        gradientView.layer.addSublayer(gradientLayer)
        insertSubview(gradientView, at: 0) // Behind CommandBar
        
        NSLayoutConstraint.activate([
            gradientView.topAnchor.constraint(equalTo: topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func updateGradientColors() {
        guard let gradientLayer = gradientLayer else { return }
        
        // Use systemBackground with varying alpha - same color family, no gray!
        gradientLayer.colors = [
            UIColor.systemBackground.withAlphaComponent(0.0).cgColor,  // Top: transparent systemBackground
            UIColor.systemBackground.cgColor                           // Bottom: solid systemBackground
        ]
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateGradientColors()
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer?.frame = gradientView.bounds
    }
    
    public override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: 56)
    }
    
    // MARK: - Lifecycle Logging
    
    public override func willMove(toSuperview newSuperview: UIView?) {
        print("🟡 MarkdownCommandBar.willMove(toSuperview:) - Moving to superview: \(newSuperview?.description ?? "nil")")
        super.willMove(toSuperview: newSuperview)
    }
    
    public override func didMoveToSuperview() {
        print("🟡 MarkdownCommandBar.didMoveToSuperview() - Moved to superview: \(superview?.description ?? "nil")")
        super.didMoveToSuperview()
    }
    
    public override func willMove(toWindow newWindow: UIWindow?) {
        print("🟡 MarkdownCommandBar.willMove(toWindow:) - Moving to window: \(newWindow?.description ?? "nil")")
        super.willMove(toWindow: newWindow)
    }
    
    public override func didMoveToWindow() {
        print("🟡 MarkdownCommandBar.didMoveToWindow() - Moved to window: \(window?.description ?? "nil")")
        super.didMoveToWindow()
    }
    
    private func setupCommandBar() {
        // Create formatting items
        let formattingItems = [
            createCommandBarItem(icon: UIImage(systemName: "bold")) { [weak self] in
                self?.editor?.applyFormatting(.bold)
            },
            createCommandBarItem(icon: UIImage(systemName: "italic")) { [weak self] in
                self?.editor?.applyFormatting(.italic)
            },
            createCommandBarItem(icon: UIImage(systemName: "strikethrough")) { [weak self] in
                self?.editor?.applyFormatting(.strikethrough)
            }
        ]
        
        let listItems = [
            createCommandBarItem(icon: UIImage(systemName: "list.bullet")) { [weak self] in
                self?.editor?.setBlockType(.unorderedList)
            },
            createCommandBarItem(icon: UIImage(systemName: "list.number")) { [weak self] in
                self?.editor?.setBlockType(.orderedList)
            }
        ]
        
        // Create heading items with text labels (in main scrollable area)
        let headingItems = [
            createCommandBarItemWithTitle("Title") { [weak self] in
                self?.editor?.setBlockType(.heading(level: .h1))
            },
            createCommandBarItemWithTitle("Subtitle") { [weak self] in
                self?.editor?.setBlockType(.heading(level: .h2))
            }
        ]
        
        let dismissKeyboardItem = createCommandBarItem(
            icon: UIImage(systemName: "keyboard.chevron.compact.down")
        ) { [weak self] in
            print("🔥 MarkdownCommandBar dismiss button tapped")
            self?.editor?.textView.resignFirstResponder()
        }
        
        // Create command bar groups - all in main scrollable area except dismiss keyboard
        let formattingGroup = CommandBarItemGroup(formattingItems)
        let listGroup = CommandBarItemGroup(listItems)
        let headingGroup = CommandBarItemGroup(headingItems)
        
        // Initialize CommandBar with headings in main scrollable area
        commandBar = CommandBar(
            itemGroups: [formattingGroup, listGroup, headingGroup],
            trailingItemGroups: [CommandBarItemGroup([dismissKeyboardItem])]
        )
        
        addSubview(commandBar)
        commandBar.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            commandBar.topAnchor.constraint(equalTo: topAnchor),
            commandBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            commandBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            commandBar.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func createCommandBarItem(icon: UIImage?, action: @escaping () -> Void) -> CommandBarItem {
        let item = CommandBarItem(
            iconImage: icon,
            itemTappedHandler: { _, _ in action() }
        )
        return item
    }
    
    private func createCommandBarItemWithTitle(_ title: String, action: @escaping () -> Void) -> CommandBarItem {
        let item = CommandBarItem(
            iconImage: nil,
            title: title,
            itemTappedHandler: { _, _ in action() }
        )
        return item
    }
    
    private func updateButtonStates() {
        // Update button states based on current editor selection
        // This would need to be implemented based on FluentUI's CommandBarItem state management
    }
}
