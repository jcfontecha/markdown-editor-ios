import UIKit
import FluentUI

public class MarkdownCommandBar: UIView {
    private var commandBar: CommandBar!
    private var gradientView: UIView!
    private var gradientLayer: CAGradientLayer!
    
    public weak var editor: MarkdownEditor? {
        didSet {
            updateButtonStates()
        }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradientBackground()
        setupCommandBar()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradientBackground()
        setupCommandBar()
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