import Foundation

struct Walker {
    var x: Double = 0
    var direction: Double = -1
    private(set) var distance: Double = 0
    let speed: Double = 27

    var swing: Double { sin(distance / 26 * .pi) * 10 }

    mutating func advance(seconds: Double, width: Double) {
        guard width > 0, seconds > 0 else { return }
        let travel = speed * seconds
        distance = (distance + travel).truncatingRemainder(dividingBy: 52)
        // Unfold the round trip so even a step crossing multiple edges reflects correctly.
        let phase = ((direction > 0 ? x : 2 * width - x) + travel)
            .truncatingRemainder(dividingBy: 2 * width)
        x = phase <= width ? phase : 2 * width - phase
        direction = phase < width ? 1 : -1
    }

    mutating func constrain(to width: Double) {
        x = min(max(0, x), max(0, width))
    }
}
