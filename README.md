# DynamicBottomSheet

A flexible and customizable bottom sheet component for iOS applications built with UIKit.

## Features

- 🎯 **Multiple Detents**: Support for medium, large, and custom detents
- 🎨 **Customizable Appearance**: Configurable colors, corner radius, and dragger
- 📱 **Gesture Support**: Swipe to dismiss and tap to dismiss
- 🔄 **Smooth Animations**: Spring and system animation styles
- 📜 **ScrollView Integration**: Seamless integration with UIScrollView
- 🎛️ **Event Handling**: Comprehensive event callbacks
- 🔧 **Easy Integration**: Simple API with UIViewController extensions

## Requirements

- iOS 13.0+
- Xcode 12.0+
- Swift 5.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/DynamicBottomSheet.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select the version and add to your target

## Quick Start

### Basic Usage

```swift
import DynamicBottomSheet

// Create a bottom sheet
let bottomSheet = DynamicBottomSheetController(
    detents: [.medium, .large],
    initialDetentID: .medium
)

// Configure and present
bottomSheet.configure(
    superview: view,
    contentView: yourContentView,
    contentScrollView: yourScrollView
)

bottomSheet.present {
    print("Bottom sheet presented")
}
```

### Using UIViewController Extension

```swift
// Present a view controller as bottom sheet
presentDynamicBottomSheet(
    yourViewController,
    detents: [.medium, .large],
    animated: true
)
```

## Configuration

### Detents

```swift
// Predefined detents
let mediumDetent = DynamicBottomSheetController.Detent.medium
let largeDetent = DynamicBottomSheetController.Detent.large
let hiddenDetent = DynamicBottomSheetController.Detent.hidden

// Custom detent
let customDetent = DynamicBottomSheetController.Detent.custom { context in
    return min(300, context.contentSize.height * 0.3)
}
```

### Configuration Options

```swift
let config = DynamicBottomSheetController.Config(
    shouldDismissByTap: true,           // Allow tap to dismiss
    shouldDismissBySwipe: true,         // Allow swipe to dismiss
    dimmingViewColor: .black,           // Dimming view color
    dimmingViewAlpha: 0.4,              // Dimming view opacity
    cornerRadius: 16,                   // Corner radius
    needsShowDragger: true,             // Show dragger handle
    draggerColor: .systemGray3,         // Dragger color
    animationStyle: .spring             // Animation style
)
```

### Event Handling

```swift
let events = DynamicBottomSheetController.Events(
    didChangeDetent: { detentID in
        print("Detent changed to: \(detentID)")
    },
    didTapDimmingView: {
        print("Dimming view tapped")
    },
    swipeWillDismiss: {
        print("Will dismiss by swipe")
    },
    willDismiss: {
        print("Will dismiss")
    },
    didDismiss: {
        print("Did dismiss")
    }
)

bottomSheet.registerEvents(events)
```

## Advanced Usage

### Custom Content View Controller

```swift
class MyContentViewController: UIViewController, DynamicBottomSheetContentViewController {
    var dynamicBottomSheetBridge: DynamicBottomSheetBridge?
    
    var detents: [DynamicBottomSheetController.Detent] {
        [.medium, .large]
    }
    
    var contentScrollView: UIScrollView? {
        return scrollView
    }
}
```

### Self-Sized Detent

```swift
// Automatically size based on content
let selfSizedDetent = viewController.selfSizedDynamiBottomSheetDetent()
```

### Programmatic Control

```swift
// Change detent programmatically
bottomSheet.setDetent(id: .large, animated: true)

// Update detents
bottomSheet.invalidateDetents(newDetents: [.medium, .large, customDetent])

// Dismiss
bottomSheet.dismiss {
    print("Dismissed")
}
```

## Animation Styles

- **`.system`**: Uses system spring animation
- **`.spring`**: Custom spring animation with configurable parameters

## API Reference

### DynamicBottomSheetController

Main controller class for managing bottom sheet behavior.

#### Methods

- `init(detents:initialDetentID:config:)` - Initialize with detents and configuration
- `configure(superview:contentView:contentScrollView:)` - Configure the bottom sheet
- `present(completion:)` - Present the bottom sheet
- `dismiss(completion:)` - Dismiss the bottom sheet
- `setDetent(id:animated:)` - Change current detent
- `invalidateDetents(newDetents:)` - Update available detents
- `registerEvents(_:)` - Register event callbacks

### DynamicBottomSheetController.Detent

Represents different height states of the bottom sheet.

#### Cases

- `.medium` - Half screen height
- `.large` - Full screen minus safe area
- `.hidden` - Minimal height (for programmatic hiding)
- `.custom(id:resolver:)` - Custom height calculation

### DynamicBottomSheetController.Config

Configuration options for the bottom sheet.

#### Properties

- `shouldDismissByTap: Bool` - Allow tap to dismiss
- `shouldDismissBySwipe: Bool` - Allow swipe to dismiss
- `dimmingViewColor: UIColor` - Background dimming color
- `dimmingViewAlpha: CGFloat` - Background dimming opacity
- `cornerRadius: CGFloat` - Corner radius
- `needsShowDragger: Bool` - Show dragger handle
- `draggerColor: UIColor` - Dragger color
- `animationStyle: DynamicBottomSheetAnimationStyle` - Animation style

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

If you encounter any issues or have questions, please open an issue on GitHub.
