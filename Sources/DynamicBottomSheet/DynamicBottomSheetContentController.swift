import UIKit

public protocol DynamicBottomSheetBridge {
    var currentDetentID: DynamicBottomSheetController.Detent.Identifier { get }

    func registerEvents(_ events: DynamicBottomSheetController.Events)
    func setDetent(id: DynamicBottomSheetController.Detent.Identifier, animated: Bool)
    func invalidateDetents(newDetents: [DynamicBottomSheetController.Detent])
}

public protocol DynamicBottomSheetContentViewController: UIViewController {
    var dynamicBottomSheetBridge: DynamicBottomSheetBridge? { get set }
    var detents: [DynamicBottomSheetController.Detent] { get }
    var contentScrollView: UIScrollView? { get }
}

public extension DynamicBottomSheetContentViewController {
    var contentScrollView: UIScrollView? { nil }
}
