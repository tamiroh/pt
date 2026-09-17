import Foundation

struct Walker {
    static let gravity: Double = 1_200

    var x: Double = 0
    var direction: Double = -1
    private(set) var distance: Double = 0
    private(set) var height: Double = 0
    private var fallSpeed: Double = 0
    let speed: Double = 27

    var swing: Double { sin(distance / 26 * .pi) * 10 }
    var isFalling: Bool { height > 0 }

    mutating func drop(from height: Double) {
        self.height = max(0, height)
        fallSpeed = 0
    }

    mutating func advance(seconds: Double, width: Double, walking: Bool = true) {
        guard seconds > 0 else { return }
        let walkingTime = advanceFall(seconds: seconds)
        guard walking, width > 0, walkingTime > 0 else { return }
        let travel = speed * walkingTime
        distance = (distance + travel).truncatingRemainder(dividingBy: 52)
        // Unfold the round trip so even a step crossing multiple edges reflects correctly.
        let phase = ((direction > 0 ? x : 2 * width - x) + travel)
            .truncatingRemainder(dividingBy: 2 * width)
        x = phase <= width ? phase : 2 * width - phase
        direction = phase < width ? 1 : -1
    }

    private mutating func advanceFall(seconds: Double) -> Double {
        guard isFalling else { return seconds }
        let landingTime = 2 * height
            / (sqrt(fallSpeed * fallSpeed + 2 * Self.gravity * height) + fallSpeed)
        if seconds < landingTime {
            height -= fallSpeed * seconds + 0.5 * Self.gravity * seconds * seconds
            fallSpeed += Self.gravity * seconds
            return 0
        }
        height = 0
        fallSpeed = 0
        return seconds - landingTime
    }

    mutating func constrain(to width: Double) {
        x = min(max(0, x), max(0, width))
    }
}
