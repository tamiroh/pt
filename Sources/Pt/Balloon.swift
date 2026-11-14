import Foundation

struct Balloon {
    private enum State {
        case hidden
        case attached
        case released(since: Double)
        case popped(since: Double)
    }

    private var state = State.hidden
    private(set) var origin = CGPoint.zero
    private(set) var sway: Double = 0

    var attached: Bool {
        if case .attached = state { return true }
        return false
    }

    func opacity(at now: Double) -> Double {
        switch state {
        case .hidden: 0
        case .attached, .popped: 1
        case .released(let start): max(0, 1 - (now - start) / 1.5)
        }
    }

    func burst(at now: Double) -> Double? {
        guard case .popped(let start) = state else { return nil }
        return min(1, max(0, (now - start) / 0.25))
    }

    mutating func pop(at now: Double) {
        state = .popped(since: now)
    }

    mutating func advance(at now: Double, elapsed: Double, floatingOrigin: CGPoint?, sway: Double) {
        if let floatingOrigin {
            state = .attached
            origin = floatingOrigin
            self.sway = sway
            return
        }
        switch state {
        case .hidden:
            break
        case .attached:
            state = .released(since: now)
            origin.y += 70 * elapsed
        case .released(let start):
            if now - start >= 1.5 {
                state = .hidden
            } else {
                origin.y += 70 * elapsed
            }
        case .popped(let start):
            if now - start >= 0.25 { state = .hidden }
        }
    }
}
