import Foundation

public enum DynamicBottomSheetAnimationStyle {
    case system, spring

    func animator(for animationDuration: TimeInterval) -> DynamicBottomSheetAnimator {
        switch self {
        case .system:
            SystemDynamicBottomSheetAnimator(animationDuration: animationDuration)
        case .spring:
            SpringDynamicBottomSheetAnimator(animationDuration: animationDuration)
        }
    }
}
