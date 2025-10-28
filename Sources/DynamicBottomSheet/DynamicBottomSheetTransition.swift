import UIKit

// MARK: - HitTestView

private class HitTestView: UIView {
    private let hitTestHandler: (UIView, CGPoint, UIEvent?) -> UIView?
    
    init(hitTestHandler: @escaping (UIView, CGPoint, UIEvent?) -> UIView?) {
        self.hitTestHandler = hitTestHandler
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return hitTestHandler(self, point, event)
    }
}

public extension UIViewController {
    /// Detent calculated from the height of the current UIViewController content
    func selfSizedDynamiBottomSheetDetent() -> DynamicBottomSheetController.Detent {
        .custom(
            resolver: { [weak self] context in
                let selfHeight = self?.view.systemLayoutSizeFitting(
                    context.contentSize,
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                ).height ?? 0

                return min(selfHeight, context.contentSize.height)
            }
        )
    }
}

public extension UIViewController {
    func presentDynamicBottomSheet(
        _ viewController: UIViewController,
        detents: [DynamicBottomSheetController.Detent] = [],
        initialDetentID: DynamicBottomSheetController.Detent.Identifier? = nil,
        config: DynamicBottomSheetController.Config = .init(),
        events: DynamicBottomSheetController.Events? = nil,
        forwardOutsideTaps: Bool = false,
        animated: Bool,
        completionHandler: (() -> Void)? = nil
    ) {
        let contentController = viewController as? DynamicBottomSheetContentViewController
        let detents = detents.isEmpty
        ? (contentController?.detents ?? [viewController.selfSizedDynamiBottomSheetDetent()])
        : detents

        let delegate = BottomScreenModalTransitionDelegate(
            initialDetentID: initialDetentID,
            detents: detents,
            config: config,
            events: events,
            forwardOutsideTaps: forwardOutsideTaps
        )

        contentController?.dynamicBottomSheetBridge = delegate.animator.bridge

        delegate.dismissHandler = { [weak delegate] in
            if let delegate = delegate {
                UIViewController.transitionDelegates.remove(delegate)
            }
        }

        viewController.modalPresentationStyle = .overCurrentContext
        viewController.transitioningDelegate = delegate

        UIViewController.transitionDelegates.insert(delegate)

        present(viewController, animated: animated, completion: completionHandler)
    }
}

// MARK: - Transition delegate

private final class BottomScreenModalTransitionDelegate: NSObject, UIViewControllerTransitioningDelegate {
    let animator: BottomScreenModalTransition

    var dismissHandler: (() -> Void)? {
        didSet {
            animator.dismissHandler = dismissHandler
        }
    }

    init(
        initialDetentID: DynamicBottomSheetController.Detent.Identifier?,
        detents: [DynamicBottomSheetController.Detent],
        config: DynamicBottomSheetController.Config,
        events: DynamicBottomSheetController.Events?,
        forwardOutsideTaps: Bool
    ) {
        animator = BottomScreenModalTransition(
            initialDetentID: initialDetentID,
            detents: detents,
            config: config,
            events: events,
            forwardOutsideTaps: forwardOutsideTaps
        )

        super.init()
    }

    func animationController(forPresented _: UIViewController, presenting _: UIViewController, source _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        animator
    }

    func animationController(forDismissed _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        animator
    }
}

// MARK: - Transition

private final class BottomScreenModalTransition: NSObject, UIViewControllerAnimatedTransitioning {
    var bridge: DynamicBottomSheetBridge { dynamicBottomSheetController }

    private var isPresented: Bool = false

    private weak var fromViewController: UIViewController?
    private weak var toViewController: UIViewController?

    private weak var transitionContext: UIViewControllerContextTransitioning?

    var dismissHandler: (() -> Void)?

    private let dynamicBottomSheetController: DynamicBottomSheetController
    private let forwardOutsideTaps: Bool

    init(
        initialDetentID: DynamicBottomSheetController.Detent.Identifier?,
        detents: [DynamicBottomSheetController.Detent],
        config: DynamicBottomSheetController.Config,
        events: DynamicBottomSheetController.Events?,
        forwardOutsideTaps: Bool
    ) {
        dynamicBottomSheetController = .init(
            detents: detents,
            initialDetentID: initialDetentID,
            config: config
        )

        if let events {
            dynamicBottomSheetController.registerEvents(events)
        }

        self.forwardOutsideTaps = forwardOutsideTaps && !config.shouldDismissByTap

        super.init()
    }

    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        dynamicBottomSheetController.animationDuration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        self.transitionContext = transitionContext

        toViewController = transitionContext.viewController(forKey: .to)
        fromViewController = transitionContext.viewController(forKey: .from)

        if isPresented == false {
            preparePresentation()
            present()
            isPresented.toggle()
        } else {
            dismiss()
        }
    }

    private func preparePresentation() {
        guard !isPresented else {
            return
        }

        guard
            let containerView = transitionContext?.containerView,
            let toViewController
        else {
            return
        }

        if forwardOutsideTaps {
            let hitTestView = HitTestView { [weak fromViewController] view, point, event in
                if fromViewController?.view.frame.contains(point) == true {
                    return fromViewController?.view.hitTest(point, with: event)
                } else {
                    return view
                }
            }

            containerView.addSubview(hitTestView)

            hitTestView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hitTestView.topAnchor.constraint(equalTo: containerView.topAnchor),
                hitTestView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                hitTestView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                hitTestView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
        }

        toViewController.loadViewIfNeeded()

        dynamicBottomSheetController.configure(
            superview: containerView,
            contentView: toViewController.view,
            contentScrollView: (toViewController as? DynamicBottomSheetContentViewController)?.contentScrollView
        )

        dynamicBottomSheetController.registerEvents(.init(didDismiss: { [weak self] in
            self?.toViewController?.dismiss(animated: true)
        }))
    }

    private func present() {
        dynamicBottomSheetController.present(completion: { [weak self] in
            self?.finishTransition()
        })
    }

    private func dismiss() {
        dynamicBottomSheetController.dismiss(completion: { [weak self] in
            self?.dynamicBottomSheetController.invalidate()
            self?.dismissHandler?()
            self?.finishTransition()
        })
    }

    private func finishTransition() {
        transitionContext?.completeTransition(true)
    }
}

// MARK: - Private transition delegates storage

private extension UIViewController {
    static var transitionDelegates = Set<BottomScreenModalTransitionDelegate>()
}
