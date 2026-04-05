# Scroll Edge Effect Analysis: MarkdownEditor vs AIKit/Geppetto

**Date:** 2026-04-04
**Status:** Root cause identified, fix implemented

## Executive Summary

The bottom scroll edge effect (iOS 26 liquid glass progressive blur) is visible in Geppetto and AIKit demo app but **missing** in the MarkdownEditor. The root cause is two co-required architectural differences that must both be addressed.

---

## Root Cause

### Difference 1: SwiftUI `ScrollView` with `.scrollEdgeEffectStyle` vs UIKit `UIScrollView` with nothing

**AIKit (`Conversation.swift:96-199`):**
```swift
ScrollView {                         // SwiftUI native ScrollView
    VStack { /* messages */ }
}
.modifier(ScrollEdgeEffectCompat())  // line 193
```
Where `ScrollEdgeEffectCompat` (lines 596-600) applies:
```swift
content.scrollEdgeEffectStyle(.soft, for: .bottom)
```

**MarkdownEditor (`MarkdownEditor.swift:1723-1800`):**
```swift
private let scrollView: UIScrollView  // UIKit UIScrollView
self.scrollView = UIScrollView()
scrollView.keyboardDismissMode = .interactive
scrollView.alwaysBounceVertical = true
// No scroll edge effect configured anywhere
```

The `.scrollEdgeEffectStyle(.soft, for: .bottom)` that exists in the MarkdownEditor codebase (`MarkdownCommandBar.swift:137`) is applied to the **horizontal** `ScrollView(.horizontal)` inside the command bar's button strip -- completely unrelated to the main content scroll.

### Difference 2: `.safeAreaBar(edge: .bottom)` vs `inputAccessoryView`

**AIKit (`PromptInput.swift:1046-1080`):**
```swift
content
    .ignoresSafeArea(.container, edges: .bottom)
    .safeAreaBar(edge: .bottom) {       // iOS 26 API
        PromptInput(...)
    }
```

`.safeAreaBar` is the iOS 26 API that creates a bar the scroll edge effect system recognizes. Content scrolling behind this bar gets the blur/fade treatment.

**Geppetto (`SidebarScaffold.swift:59-90`):**
```swift
func bottomBar<Content>(_ content: Content) -> some View {
    if #available(iOS 26.0, *) {
        self.safeAreaBar(edge: .bottom, ...) { content }  // iOS 26
    } else {
        self.safeAreaInset(edge: .bottom, ...) { content } // fallback
    }
}
```

**MarkdownEditor (`MarkdownEditor.swift:1232-1243`):**
```swift
private func setupCommandBar() {
    let commandBar = MarkdownCommandBar()
    commandBar.frame = CGRect(x: 0, y: 0, width: screenWidth, height: intrinsicHeight)
    textView.inputAccessoryView = commandBar  // keyboard-attached
}
```

`inputAccessoryView` is keyboard-managed. It:
- Lives in the keyboard's coordinate space, not the view hierarchy
- Doesn't create a safe area inset
- Doesn't register as an "edge" in the scroll edge effect system
- Is invisible to the iOS 26 liquid glass system

---

## Comparison Table

| Aspect | AIKit / Geppetto | MarkdownEditor |
|--------|-----------------|----------------|
| **Scroll container** | SwiftUI `ScrollView` | UIKit `UIScrollView` in `UIViewRepresentable` |
| **Edge effect** | `.scrollEdgeEffectStyle(.soft, for: .bottom)` | None on main content scroll |
| **Bottom bar API** | `.safeAreaBar(edge: .bottom)` (iOS 26) | `textView.inputAccessoryView` |
| **Bar -> scroll relationship** | Bar creates safe area; scroll system sees the edge | Keyboard-attached; scroll system unaware |
| **Content scrolls behind bar** | Yes (with blur) | No (bar moves with keyboard) |
| **UIViewController integration** | SwiftUI manages via hosting controller | No `contentScrollView(for:)` override |

---

## iOS 26 Scroll Edge Effect Deep Dive

### What It Is

A gradual blur and fade (progressive blur) applied to scrolling content at edges where it passes underneath system chrome (navigation bars, tab bars, toolbars). It improves legibility of translucent Liquid Glass components.

### SwiftUI API

```swift
// Modifier
.scrollEdgeEffectStyle(_ style: ScrollEdgeEffectStyle, for edges: Edge.Set)

// Styles
.automatic  // Platform-specific default
.soft       // Gradual fade with variable blur (more immersive)
.hard       // Sharp cutoff with dividing line

// Hide entirely
.scrollEdgeEffectHidden(true, for: .bottom)
```

**Automatic behavior:** SwiftUI ScrollView, List, and Form automatically have scroll edge effects in iOS 26. No opt-in required.

### UIKit API

```swift
// UIScrollView properties (read-only, all subclasses including UITextView)
var topEdgeEffect: UIScrollEdgeEffect { get }
var bottomEdgeEffect: UIScrollEdgeEffect { get }
var leftEdgeEffect: UIScrollEdgeEffect { get }
var rightEdgeEffect: UIScrollEdgeEffect { get }

// UIScrollEdgeEffect configuration
edgeEffect.style = .automatic  // or .hard
edgeEffect.isHidden = true     // disable

// Custom container interaction (for non-system bars)
let interaction = UIScrollEdgeElementContainerInteraction()
interaction.scrollView = scrollView
interaction.edge = .bottom
overlayView.addInteraction(interaction)
```

### What Triggers the Bottom Edge Effect

| Mechanism | Triggers Bottom Effect? |
|-----------|------------------------|
| System tab bar | Yes (automatic) |
| `ToolbarItem(placement: .bottomBar)` | Yes |
| `.safeAreaBar(edge: .bottom)` | Yes |
| `.safeAreaInset(edge: .bottom)` | **No** (disables it) |
| `inputAccessoryView` | **No** (keyboard space) |
| `UIScrollEdgeElementContainerInteraction` | Yes (UIKit custom bars) |
| `contentScrollView(for:)` override | Enables system bar detection |

### `safeAreaBar` vs `safeAreaInset`

**Critical difference for scroll edge effects:**
- `safeAreaInset` adjusts safe area but does NOT activate the scroll edge effect. Using it effectively **disables** the bottom edge effect.
- `safeAreaBar` (iOS 26) works the same way but DOES activate the scroll edge effect.

### `contentScrollView(for:)` on UIViewController

The system calls `contentScrollView(for:)` to find the scroll view to apply edge effects to. If a view controller doesn't return the correct scroll view, the system can't connect it to system bars (nav bar, tab bar).

```swift
override func contentScrollView(for edge: NSDirectionalRectEdge) -> UIScrollView? {
    return myScrollView
}
```

Available since iOS 15, but the scroll edge effect behavior tied to it is iOS 26+.

### `UIScrollEdgeElementContainerInteraction`

For custom UI elements that overlay a scroll view (not system bars):

```swift
let interaction = UIScrollEdgeElementContainerInteraction()
interaction.scrollView = scrollView
interaction.edge = .bottom
customBarView.addInteraction(interaction)
```

Inserts an edge effect behind custom overlay views. Descendants of the container (labels, glass views, controls) automatically affect the effect shape.

---

## View Hierarchies

### AIKit/Geppetto Chat

```
NavigationStack
  ChatView
    ZStack
      Conversation (SwiftUI ScrollView)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .defaultScrollAnchor(.top)
        .scrollDismissesKeyboard(.interactively)
        VStack
          LazyVStack (messages)
          bottomSentinelView (inset spacer + sentinel)
      .chatComposer modifier
        .ignoresSafeArea(.container, edges: .bottom)
        .safeAreaBar(edge: .bottom) {
          PromptInput (GlassEffectContainer + glassEffect)
        }
        .overlay { scroll-to-latest button }
```

### MarkdownEditor (isScrollEnabled: true)

```
MarkdownEditor (SwiftUI View)
  MarkdownEditorRepresentable (UIViewRepresentable)
    MarkdownEditorView (UIView)
      UIScrollView
        MarkdownEditorContentView (UIView)
          LexicalView (UIView)
            UITextView (isScrollEnabled: false)
              inputAccessoryView = MarkdownCommandBar
                NonStealingHostingController
                  CommandBarContentView (SwiftUI)
                    HStack
                      ScrollView(.horizontal)
                        .scrollEdgeEffectStyle(.soft, for: .bottom)  // on horizontal scroll only!
                      dismiss keyboard button
```

### MarkdownEditor (isScrollEnabled: false)

```
Parent SwiftUI ScrollView (gets automatic edge effects)
  MarkdownEditor (SwiftUI View)
    MarkdownEditorRepresentable (UIViewRepresentable)
      MarkdownEditorContentView (UIView)
        LexicalView (UIView)
          UITextView (isScrollEnabled: false)
            inputAccessoryView = MarkdownCommandBar
```

---

## AIKit Scroll Management Details

### Conversation ScrollView Configuration
- **Coordinate space:** Named `"chat-scroll"` for position tracking
- **Scroll disable:** Temporarily disabled during programmatic scroll animations
- **User intervention:** DragGesture detects manual scroll to cancel auto-follow
- **Default anchor:** `.top` (prevents visual shift during streaming)
- **Keyboard:** `.scrollDismissesKeyboard(.interactively)`

### Bottom Inset Strategy
The `Conversation` view adds a `bottomInset` spacer inside the ScrollView content:
```swift
var bottomInset: CGFloat {
    max(1, extraBottomPadding + bottomOverlayHeight)
    // extraBottomPadding = 24, bottomOverlayHeight = measured PromptInput height
}
```
This ensures content can scroll up past the bottom bar overlay.

### Height Communication
```
PromptInput (GeometryReader measures height)
  → ChatComposerModifier.measuredHeight
  → .conversationBottomOverlayHeight(resolvedHeight + overlayPadding)
  → Environment key → Conversation reads it
  → ConversationScrollViewModel.bottomOverlayHeight
  → bottomInset spacer in content
```

### Streaming Follow
- Throttled at 50ms intervals
- Uses `.easeOut(duration: 0.10)` animation
- Scrolls to bottom sentinel or reserved tail sentinel
- Cancelled on user drag gesture

### Message Anchoring
- New user messages anchored to top with reserved tail space
- Reserved space shrinks as assistant response grows
- Exits reserve mode when response exceeds viewport

---

## Geppetto-Specific Patterns

### SidebarScaffold (reused across views)
```swift
ScrollView {
    LazyVStack { content }
}
.softScrollEdgeEffectIfAvailable()  // .scrollEdgeEffectStyle(.soft, for: .all)
.topBar(header)     // .safeAreaBar(edge: .top) on iOS 26, .safeAreaInset fallback
.bottomBar(footer)  // .safeAreaBar(edge: .bottom) on iOS 26, .safeAreaInset fallback
```

### Glass Effect Usage
- `GlassEffectContainer` wraps groups of glass elements for morphing
- `.glassEffect(.clear.interactive(), in: .capsule)` for buttons
- `.glassEffect(.regular, in: .rect(cornerRadius: 22))` for cards
- Pre-iOS 26 fallback: `.background(.ultraThinMaterial, in: shape)`

---

## Fix Strategy

### The Fix: `contentScrollView(for:)` Override

**Core insight:** The UIKit `UIScrollView` inside `MarkdownEditorView` has scroll edge effect capability in iOS 26, but the system can't find it because there's no `contentScrollView(for:)` override connecting it to the view controller hierarchy.

**Implementation:**
1. Change `MarkdownEditorRepresentable` from `UIViewRepresentable` to `UIViewControllerRepresentable`
2. Create `MarkdownEditorHostingController` that overrides `contentScrollView(for:)` to return the editor's UIScrollView
3. Expose `scrollViewForEdgeEffects` on `MarkdownEditorView` for UIKit consumers
4. For `isScrollEnabled: false`, no change needed (parent SwiftUI ScrollView handles edge effects)

**What this enables:**
- System bars (navigation bar, tab bar) automatically trigger edge effects
- The UIScrollView participates in the iOS 26 scroll edge system
- Works for both UIKit and SwiftUI consumers
- No behavioral changes to existing functionality

### For UIKit consumers (direct MarkdownEditorView usage)
Override `contentScrollView(for:)` in their view controller:
```swift
override func contentScrollView(for edge: NSDirectionalRectEdge) -> UIScrollView? {
    return markdownEditor.scrollViewForEdgeEffects
}
```

---

## Sources

- [Apple Documentation: scrollEdgeEffectStyle](https://developer.apple.com/documentation/SwiftUI/View/scrollEdgeEffectStyle(_:for:))
- [Apple Documentation: UIScrollEdgeEffect](https://developer.apple.com/documentation/UIKit/UIScrollEdgeEffect)
- [Apple Documentation: UIScrollEdgeElementContainerInteraction](https://developer.apple.com/documentation/uikit/uiscrolledgeelementcontainerinteraction)
- [Apple Documentation: safeAreaBar](https://developer.apple.com/documentation/swiftui/view/safeareabar(edge:alignment:spacing:content:))
- [Apple Documentation: contentScrollView(for:)](https://developer.apple.com/documentation/uikit/uiviewcontroller/contentscrollview(for:))
- [WWDC25 Session 323: Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/)
- [WWDC25 Session 284: Build a UIKit app with the new design](https://developer.apple.com/videos/play/wwdc2025/284/)
- [Seb Vidal: What's New in UIKit 26](https://sebvidal.com/blog/whats-new-in-uikit-26/)
- [Fatbobman: Grow on iOS 26](https://fatbobman.com/en/posts/grow-on-ios26/)
- [Threads @alpennec: safeAreaBar vs safeAreaInset](https://www.threads.com/@alpennec/post/DNm1LGqslaa/)
