import Combine
import SnapKit
import UIKit

public final class DynamicBottomSheetController: NSObject, DynamicBottomSheetBridge {
    public var currentDetentID: Detent.Identifier {
        model.currentDetent.id
    }

    public var animationDuration: TimeInterval {
        animator.animationDuration
    }

    private let dimmingView = UIView()
    private var scrollView: UIScrollView?
    private var superview: UIView?
    private lazy var draggerView = UIView()
    private let contentWrapperView = UIView()

    private var topContentWrapperViewConstraint: Constraint?
    private var scrollViewContentOffsetSubscription: AnyCancellable?
    private var scrollViewPanGestureRecognizer: UIPanGestureRecognizer?
    private let panGestureRecognizer = UIPanGestureRecognizer()

    private let model: DynamicBottomSheetModel
    private let animator: DynamicBottomSheetAnimator

    public init(
        detents: [Detent],
        initialDetentID: DynamicBottomSheetController.Detent.Identifier? = nil,
        config: Config = .init()
    ) {
        model = .init(detents: detents, initialDetentID: initialDetentID, config: config)
        animator = config.animationStyle.animator(for: Spec.animationDuration)
    }

    public func registerEvents(_ events: Events) {
        model.events.append(events)
    }

    public func configure(
        superview: UIView,
        contentView: UIView,
        contentScrollView: UIScrollView?
    ) {
        invalidate()
        self.superview = superview
        setupLayout(superview: superview, contentView: contentView)
        setupViews()
        setupInitialDetents()
        setupGestures()
        scrollView = contentScrollView
        setupScrollViewSubscriptionsIfNeeded()
    }

    public func present(completion: (() -> Void)?) {
        guard model.state != .presented else {
            completion?()
            return
        }

        contentWrapperView.transform = CGAffineTransform.identity.translatedBy(x: 0.0, y: contentWrapperView.bounds.height)
        contentWrapperView.isHidden = false

        animator.execute(
            type: .present,
            animated: true,
            animations: {
                self.dimmingView.alpha = self.model.config.dimmingViewAlpha
                self.contentWrapperView.transform = .identity
            }, completion: { _ in
                self.model.state = .presented
                completion?()
            }
        )
    }

    public func dismiss(completion: (() -> Void)?) {
        model.events.forEach { $0.willDismiss?() }

        guard model.state == .presented else {
            completion?()
            return
        }

        animator.execute(
            type: .dismiss,
            animated: true,
            animations: {
                self.dimmingView.alpha = 0
                self.contentWrapperView.transform = CGAffineTransform.identity.translatedBy(x: 0.0, y: self.contentWrapperView.bounds.height)
            }, completion: { _ in
                self.model.state = .dismissed
                self.model.events.forEach { $0.didDismiss?() }
                self.contentWrapperView.isHidden = true
                completion?()
            }
        )
    }

    public func setDetent(id: Detent.Identifier, animated: Bool) {
        guard let detent = model.detent(for: id), detent != model.currentDetent else {
            return
        }

        set(detent: detent, animated: animated)
    }

    public func invalidateDetents(newDetents: [Detent]) {
        guard let superview else { return }

        let currentDetentID = model.currentDetent.id

        guard !newDetents.isEmpty else {
            print("Can't invalidate without any detents.")
            return
        }

        model.setResortedDetents(
            resort(detents: newDetents),
            contentSize: superview.bounds.size
        )

        guard let newDetent = model.detent(for: currentDetentID) ?? model.detents.first else {
            return
        }

        set(detent: newDetent, animated: true)
    }

    public func invalidate() {
        model.invalidateHeightCache()
        scrollViewContentOffsetSubscription?.cancel()
        scrollViewContentOffsetSubscription = nil
        contentWrapperView.subviews.forEach { $0.removeFromSuperview() }
        contentWrapperView.removeFromSuperview()
        dimmingView.removeFromSuperview()
        
        if let scrollViewPanGestureRecognizer = scrollViewPanGestureRecognizer {
            scrollViewPanGestureRecognizer.removeTarget(self, action: #selector(handleScrollViewPanGestureRecognizer(_:)))
            scrollViewPanGestureRecognizer.view?.removeGestureRecognizer(scrollViewPanGestureRecognizer)
            self.scrollViewPanGestureRecognizer = nil
        }
        
        panGestureRecognizer.removeTarget(self, action: #selector(handlePanGestureRecognizer(_:)))
        panGestureRecognizer.view?.removeGestureRecognizer(panGestureRecognizer)
        
        model.events.removeAll()
    }

    private func setupGestures() {
        if model.config.shouldDismissByTap {
            let tapGestureRecognizer = UITapGestureRecognizer()
            tapGestureRecognizer.addTarget(self, action: #selector(handleTapGestureRecognizer(_:)))
            dimmingView.addGestureRecognizer(tapGestureRecognizer)
        }

        dimmingView.isUserInteractionEnabled = model.config.shouldDismissByTap

        panGestureRecognizer.delegate = self
        panGestureRecognizer.addTarget(self, action: #selector(handlePanGestureRecognizer(_:)))
        contentWrapperView.addGestureRecognizer(panGestureRecognizer)
    }

    private func setupScrollViewSubscriptionsIfNeeded() {
        guard let scrollView else {
            return
        }

        scrollViewContentOffsetSubscription = scrollView
            .publisher(for: \.contentOffset)
            .removeDuplicates()
            .sink { [weak self] in
                if self?.scrollView?.isTracking == false, self?.scrollView?.isDecelerating == false {
                    self?.model.scrollViewUnhandledOffset = $0
                }
            }

        let scrollViewPanGestureRecognizer = UIPanGestureRecognizer()
        scrollViewPanGestureRecognizer.addTarget(self, action: #selector(handleScrollViewPanGestureRecognizer(_:)))
        scrollViewPanGestureRecognizer.delegate = self
        scrollView.addGestureRecognizer(scrollViewPanGestureRecognizer)
        self.scrollViewPanGestureRecognizer = scrollViewPanGestureRecognizer
    }

    private func setupInitialDetents() {
        guard let superview else { return }

        model.setResortedDetents(
            resort(detents: model.detents),
            contentSize: superview.bounds.size
        )

        set(detent: model.currentDetent, animated: false)
    }

    private func resort(detents: [Detent]) -> [Detent] {
        guard detents.count > 1 else { return detents }

        return detents
            .sorted(by: {
                heightForDetent($0) < heightForDetent($1)
            })
    }

    @objc
    private func handleTapGestureRecognizer(_ sender: UITapGestureRecognizer) {
        model.events.forEach { $0.didTapDimmingView?() }
        dismiss(completion: nil)
    }

    @objc
    private func handleScrollViewPanGestureRecognizer(_ sender: UIPanGestureRecognizer) {
        guard let scrollView else {
            return
        }

        if let scrollViewUnhandledOffset = model.scrollViewUnhandledOffset, scrollView.contentOffset.y > -scrollView.contentInset.top, scrollViewUnhandledOffset.y > -scrollView.contentInset.top {
            return
        } else {
            model.scrollViewUnhandledOffset = nil
        }

        func resetContentOffsetAndHandlePan() {
            scrollView.setContentOffset(
                .init(x: 0, y: -scrollView.contentInset.top),
                animated: false
            )

            if !model.isTracking {
                sender.setTranslation(.zero, in: sender.view)
            }

            handlePanGestureRecognizer(sender)
        }

        if model.isTracking {
            resetContentOffsetAndHandlePan()
            return
        }

        switch sender.state {
        case .began, .changed:
            let velocity = sender.velocity(in: sender.view)

            if model.reachedMaxDetent {
                if velocity.y > 0, scrollView.contentOffset.y <= -scrollView.contentInset.top {
                    resetContentOffsetAndHandlePan()
                }
            } else {
                resetContentOffsetAndHandlePan()
            }
        case .ended, .cancelled, .failed, .possible:
            if model.isTracking {
                handlePanGestureRecognizer(sender)
            }
        @unknown default:
            break
        }
    }

    @objc
    private func handlePanGestureRecognizer(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: contentWrapperView)
        let velocity = sender.velocity(in: contentWrapperView)

        switch sender.state {
        case .changed, .began:
            model.isTracking = true
            let currentDetentHeight = heightForDetent(model.currentDetent)

            let newConstant: CGFloat

            if translation.y > 0 {
                newConstant = -(currentDetentHeight - translation.y.magnitude)
            } else {
                newConstant = -(currentDetentHeight + translation.y.magnitude)
            }

            let maxDetent = model.detents.last ?? .default
            let maxDetentHeight = heightForDetent(maxDetent)
            let newHeight = min(abs(newConstant), maxDetentHeight)

            if newHeight == maxDetentHeight, translation.y < 0 {
                model.currentDetent = maxDetent
                model.isTracking = false
            }

            topContentWrapperViewConstraint?.update(offset: -newHeight)
        case .cancelled, .failed, .ended:
            model.isTracking = false

            let height = abs(topContentWrapperViewConstraint?.layoutConstraints.first?.constant ?? 0)

            if canDismiss(velocity: velocity, translation: translation, currentHeight: height) {
                model.events.forEach { $0.swipeWillDismiss?() }
                dismiss(completion: nil)
            } else {
                let detent = findClosestDetent(currentHeight: height, velocity: velocity)
                set(detent: detent, animated: true)
            }
        case .recognized, .possible:
            break
        @unknown default:
            break
        }
    }

    private func canDismiss(
        velocity: CGPoint,
        translation: CGPoint,
        currentHeight: CGFloat
    ) -> Bool {
        guard model.config.shouldDismissBySwipe else {
            return false
        }

        var detents = model.detents
        detents.removeAll(where: { $0 == .hidden })

        if model.currentDetent == detents.first {
            return velocity.y >= Spec.minVelocityToSoftDismiss
        } else {
            let percent = max(translation.y, 0) / currentHeight
            return percent > 0.5 && velocity.y > Spec.minVelocityToHardDismiss
        }
    }

    private func findClosestDetent(currentHeight: CGFloat, velocity: CGPoint) -> Detent {
        guard let superview, !model.detents.isEmpty else {
            return .default
        }

        guard model.detents.count > 1 else {
            return model.detents.first ?? .default
        }

        guard let indexOfCurrentDetent = model.detents.firstIndex(of: model.currentDetent) else {
            return model.currentDetent
        }

        var nextDetent = model.currentDetent

        if abs(velocity.y) >= Spec.minVelocityToSwitchDetent {
            let possibleNextIndex = velocity.y > 0 ? indexOfCurrentDetent - 1 : indexOfCurrentDetent + 1
            let possibleNextDetent = model.detents[safe: possibleNextIndex]
            nextDetent = possibleNextDetent != .hidden ? (possibleNextDetent ?? nextDetent) : nextDetent
        }

        guard model.detents.count > 0 else { return .default }
        let partHeight = superview.bounds.height / CGFloat(model.detents.count)
        let index = model.detents.indices.firstIndex {
            let detentMinY = CGFloat($0) * partHeight
            let detentMaxY = detentMinY + partHeight

            return (detentMinY ... detentMaxY).contains(currentHeight)
        }

        if let index {
            let detentByPosition = model.detents[index]
            nextDetent = detentByPosition != nextDetent && detentByPosition != model.currentDetent && detentByPosition != .hidden ? detentByPosition : nextDetent
        }

        return nextDetent
    }

    private func set(detent: Detent, animated: Bool) {
        guard let superview else {
            return
        }

        let detentHeight = heightForDetent(detent)

        model.currentDetent = detent

        if detentHeight != abs(topContentWrapperViewConstraint?.layoutConstraints.first?.constant ?? 0) {
            topContentWrapperViewConstraint?.update(offset: -detentHeight)

            model.isDecelerating = true

            animator.execute(
                type: .heightChange,
                animated: animated,
                animations: {
                    superview.layoutIfNeeded()
                },
                completion: { [weak self] _ in
                    guard let self else { return }

                    model.isDecelerating = false

                    if (scrollView?.contentOffset.y ?? 0) > -(scrollView?.contentInset.top ?? 0) {
                        model.scrollViewUnhandledOffset = scrollView?.contentOffset
                    }
                }
            )
        }
    }

    private func heightForDetent(_ detent: Detent) -> CGFloat {
        guard let superview else {
            return 0
        }

        let contentSize = superview.bounds.size

        if let cachedSize = model.height(for: detent.id, contentSize: contentSize) {
            return cachedSize
        }

        let maxHeight = superview.bounds.height
        let result: CGFloat

        switch detent {
        case .medium:
            result = maxHeight / 2
        case .large:
            result = maxHeight - superview.safeAreaInsets.top
        case .hidden:
            result = 1
        case let .custom(_, resolver):
            result = resolver(.init(contentSize: contentSize, safeAreaInsets: superview.safeAreaInsets))
        }

        model.set(height: result, for: detent.id, contentSize: contentSize)
        return result
    }

    private func setupLayout(
        superview: UIView,
        contentView: UIView
    ) {
        superview.addSubview(dimmingView)
        dimmingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentWrapperView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().priority(.low)
        }

        superview.addSubview(contentWrapperView)
        contentWrapperView.snp.makeConstraints { make in
            topContentWrapperViewConstraint = make.top.equalTo(superview.snp.bottom).offset(0).constraint
            make.leading.trailing.bottom.equalToSuperview()
        }

        if model.config.needsShowDragger {
            contentWrapperView.addSubview(draggerView)
            draggerView.snp.makeConstraints { make in
                make.top.equalToSuperview().inset(8)
                make.centerX.equalToSuperview()
                make.size.equalTo(Spec.draggerSize)
            }
        }

        superview.layoutIfNeeded()
    }

    private func setupViews() {
        dimmingView.alpha = 0.0
        dimmingView.backgroundColor = model.config.dimmingViewColor

        contentWrapperView.isHidden = true
        contentWrapperView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        contentWrapperView.layer.cornerRadius = model.config.cornerRadius
        contentWrapperView.clipsToBounds = true

        if model.config.needsShowDragger {
            draggerView.backgroundColor = model.config.draggerColor
            draggerView.layer.cornerRadius = Spec.draggerSize.height / 2
            draggerView.clipsToBounds = true
        }
    }
}

extension DynamicBottomSheetController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer == panGestureRecognizer {
            return false
        }

        if otherGestureRecognizer == scrollView?.panGestureRecognizer {
            return true
        }

        return false
    }
}

private extension DynamicBottomSheetController {
    enum Spec {
        static let animationDuration: TimeInterval = 0.3
        static let darkViewShownAlpha: CGFloat = 0.4
        static let minVelocityToHardDismiss: CGFloat = 1500
        static let minVelocityToSoftDismiss: CGFloat = 300
        static let minVelocityToSwitchDetent: CGFloat = 300
        static let draggerSize = CGSize(width: 24, height: 4)
    }
}

public extension DynamicBottomSheetController {
    struct Events {
        let didChangeDetent: ((Detent.Identifier) -> Void)?
        let didTapDimmingView: (() -> Void)?
        let swipeWillDismiss: (() -> Void)?
        let willDismiss: (() -> Void)?
        let didDismiss: (() -> Void)?

        public init(
            didChangeDetent: ((Detent.Identifier) -> Void)? = nil,
            didTapDimmingView: (() -> Void)? = nil,
            swipeWillDismiss: (() -> Void)? = nil,
            willDismiss: (() -> Void)? = nil,
            didDismiss: (() -> Void)? = nil
        ) {
            self.didChangeDetent = didChangeDetent
            self.didTapDimmingView = didTapDimmingView
            self.swipeWillDismiss = swipeWillDismiss
            self.willDismiss = willDismiss
            self.didDismiss = didDismiss
        }
    }

    enum Detent: Equatable {
        case medium, large, custom(id: Identifier = .init(rawValue: UUID().uuidString), resolver: (_ context: ResolverContext) -> CGFloat)

        /// For programmatic hide
        case hidden

        static let `default`: Self = .medium

        public static func == (lhs: Detent, rhs: Detent) -> Bool {
            return lhs.id == rhs.id
        }

        public var id: Identifier {
            switch self {
            case .medium:
                return Detent.Identifier.medium
            case .large:
                return Detent.Identifier.large
            case .hidden:
                return Detent.Identifier.hidden
            case let .custom(id, _):
                return id
            }
        }
    }

    struct Config {
        let shouldDismissByTap: Bool
        let shouldDismissBySwipe: Bool
        let dimmingViewColor: UIColor
        let dimmingViewAlpha: CGFloat
        let cornerRadius: CGFloat
        let needsShowDragger: Bool
        let draggerColor: UIColor
        let animationStyle: DynamicBottomSheetAnimationStyle

        public init(
            shouldDismissByTap: Bool = true,
            shouldDismissBySwipe: Bool = true,
            dimmingViewColor: UIColor = .clear,
            dimmingViewAlpha: CGFloat = 0.4,
            cornerRadius: CGFloat = 0,
            needsShowDragger: Bool = false,
            draggerColor: UIColor = .systemGray3,
            animationStyle: DynamicBottomSheetAnimationStyle = .spring
        ) {
            self.shouldDismissByTap = shouldDismissByTap
            self.shouldDismissBySwipe = shouldDismissBySwipe
            self.dimmingViewColor = dimmingViewColor
            self.dimmingViewAlpha = dimmingViewAlpha
            self.cornerRadius = cornerRadius
            self.needsShowDragger = needsShowDragger
            self.draggerColor = draggerColor
            self.animationStyle = animationStyle
        }
    }
}

public extension DynamicBottomSheetController.Detent {
    struct ResolverContext {
        public let contentSize: CGSize
        public let safeAreaInsets: UIEdgeInsets
    }

    struct Identifier: Hashable {
        public static let medium: Self = .init(rawValue: "medium")
        public static let large: Self = .init(rawValue: "large")
        public static let hidden: Self = .init(rawValue: "hidden")

        private let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}

// MARK: - Array Safe Access Extension
private extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
