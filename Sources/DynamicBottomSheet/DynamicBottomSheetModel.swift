import Foundation

final class DynamicBottomSheetModel {
    enum State {
        case idle, presented, dismissed
    }

    var reachedMaxDetent: Bool {
        currentDetent == detents.last
    }

    var events: [DynamicBottomSheetController.Events] = []
    var scrollViewUnhandledOffset: CGPoint?
    var isTracking = false
    var isDecelerating = false
    var state: State = .idle
    var currentDetent: DynamicBottomSheetController.Detent {
        didSet {
            guard oldValue != currentDetent else {
                return
            }

            events.forEach { $0.didChangeDetent?(currentDetent.id) }
        }
    }

    let config: DynamicBottomSheetController.Config
    private(set) var detents: [DynamicBottomSheetController.Detent]

    private var heightCache: [DynamicBottomSheetController.Detent.Identifier: CGFloat] = [:]
    private var contentSize = CGSize.zero
    private let initialDetent: DynamicBottomSheetController.Detent?

    init(
        detents: [DynamicBottomSheetController.Detent],
        initialDetentID: DynamicBottomSheetController.Detent.Identifier?,
        config: DynamicBottomSheetController.Config
    ) {
        if let initialDetentID {
            initialDetent = detents.first(where: { $0.id == initialDetentID })
        } else {
            initialDetent = nil
        }
        currentDetent = initialDetent ?? detents.first ?? .default
        self.detents = detents
        self.config = config
    }

    func setResortedDetents(_ detents: [DynamicBottomSheetController.Detent], contentSize: CGSize) {
        self.contentSize = contentSize
        self.detents = detents
        currentDetent = initialDetent ?? detents.first ?? currentDetent
    }

    func detent(for id: DynamicBottomSheetController.Detent.Identifier) -> DynamicBottomSheetController.Detent? {
        detents.first(where: { $0.id == id })
    }

    func set(height: CGFloat, for id: DynamicBottomSheetController.Detent.Identifier, contentSize: CGSize) {
        if self.contentSize != contentSize {
            self.contentSize = contentSize
            invalidateHeightCache()
        }

        heightCache[id] = height
    }

    func height(for id: DynamicBottomSheetController.Detent.Identifier, contentSize: CGSize) -> CGFloat? {
        if contentSize != self.contentSize {
            self.contentSize = contentSize
            invalidateHeightCache()
            return nil
        }

        return heightCache[id]
    }

    func invalidateHeightCache() {
        heightCache.removeAll(keepingCapacity: true)
    }
}
