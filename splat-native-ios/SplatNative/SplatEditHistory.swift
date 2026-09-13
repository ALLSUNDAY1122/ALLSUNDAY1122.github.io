import Foundation

/// Session-local non-destructive edit history. Persisted viewer settings remain the source of truth
/// across launches; this bounded stack exists only to make interactive crop/color adjustments
/// reversible without rewriting or duplicating the source Gaussian asset.
struct SplatEditHistory: Equatable, Sendable {
    private(set) var current: SplatEditSettings
    private(set) var undoStack: [SplatEditSettings] = []
    private(set) var redoStack: [SplatEditSettings] = []
    let maximumDepth: Int

    init(current: SplatEditSettings = .default, maximumDepth: Int = 256) {
        self.current = current.normalized()
        self.maximumDepth = max(1, maximumDepth)
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    mutating func reset(to settings: SplatEditSettings) {
        current = settings.normalized()
        undoStack.removeAll(keepingCapacity: true)
        redoStack.removeAll(keepingCapacity: true)
    }

    mutating func commit(_ settings: SplatEditSettings) {
        let normalized = settings.normalized()
        guard normalized != current else { return }
        undoStack.append(current)
        if undoStack.count > maximumDepth {
            undoStack.removeFirst(undoStack.count - maximumDepth)
        }
        current = normalized
        redoStack.removeAll(keepingCapacity: true)
    }

    mutating func undo() -> SplatEditSettings? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        if redoStack.count > maximumDepth {
            redoStack.removeFirst(redoStack.count - maximumDepth)
        }
        current = previous
        return previous
    }

    mutating func redo() -> SplatEditSettings? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        if undoStack.count > maximumDepth {
            undoStack.removeFirst(undoStack.count - maximumDepth)
        }
        current = next
        return next
    }
}

@MainActor
extension SplatViewerState {
    func applyHistorySettings(_ settings: SplatEditSettings) {
        let value = settings.normalized()
        exposureEV = value.exposureEV
        contrast = value.contrast
        cropXMin = value.cropXMin
        cropXMax = value.cropXMax
        cropYMin = value.cropYMin
        cropYMax = value.cropYMax
        cropZMin = value.cropZMin
        cropZMax = value.cropZMax
    }
}
