import UIKit

enum DynamicBottomSheetAnimationType {
    case present, dismiss, heightChange
}

protocol DynamicBottomSheetAnimator {
    var animationDuration: TimeInterval { get }

    func execute(
        type: DynamicBottomSheetAnimationType,
        animated: Bool,
        animations: @escaping () -> Void,
        completion: @escaping (Bool) -> Void
    )
}

struct SystemDynamicBottomSheetAnimator: DynamicBottomSheetAnimator {
    let animationDuration: TimeInterval

    func execute(
        type: DynamicBottomSheetAnimationType,
        animated: Bool,
        animations: @escaping () -> Void,
        completion: @escaping (Bool) -> Void
    ) {
        UIView.animate(
            withDuration: animated ? animationDuration : 0,
            delay: 0,
            options: .systemSpringCurve,
            animations: animations,
            completion: completion
        )
    }
}

final class SpringDynamicBottomSheetAnimator: DynamicBottomSheetAnimator {
    let animationDuration: TimeInterval

    private var animator: UIViewPropertyAnimator?

    init(animationDuration: TimeInterval) {
        self.animationDuration = animationDuration
    }
    
    deinit {
        animator?.stopAnimation(true)
        animator?.finishAnimation(at: .current)
        animator = nil
    }

    func execute(
        type: DynamicBottomSheetAnimationType,
        animated: Bool,
        animations: @escaping () -> Void,
        completion: @escaping (Bool) -> Void
    ) {
        switch type {
        case .present:
            present(animated: animated, animations: animations, completion: completion)
        case .dismiss, .heightChange:
            UIView.animate(
                withDuration: animated ? animationDuration : 0,
                delay: 0,
                options: .systemSpringCurve,
                animations: animations,
                completion: completion
            )
        }
    }

    private func present(
        animated: Bool,
        animations: @escaping () -> Void,
        completion: @escaping (Bool) -> Void
    ) {
        if animated {
            animator?.stopAnimation(true)
            animator?.finishAnimation(at: .current)
            animator = nil
            
            let parameters = UISpringTimingParameters(
                mass: 1.0,
                stiffness: 200.0,
                damping: 20.0,
                initialVelocity: .zero
            )
            animator = UIViewPropertyAnimator(duration: animationDuration, timingParameters: parameters)
            animator?.addAnimations(animations)
            animator?.addCompletion { [weak self] _ in
                self?.animator = nil
                completion(true)
            }
            animator?.startAnimation()
        } else {
            animations()
            completion(true)
        }
    }
}

private extension UIView.AnimationOptions {
    static let systemSpringCurve = UIView.AnimationOptions(rawValue: 7 << 16)
}
