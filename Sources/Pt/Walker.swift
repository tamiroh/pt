import Foundation

struct Walker {
    static let gravity: Double = 1_200

    var x: Double = 0
    var direction: Double = -1
    private(set) var distance: Double = 0
    private(set) var height: Double = 0
    private var fallSpeed: Double = 0
    private var support: WindowPlatform?
    private var departedPlatformID: UInt32?
    private var randomNumberGenerator: any RandomNumberGenerator
    let speed: Double = 27

    var swing: Double { sin(distance / 26 * .pi) * 10 }
    var isFalling: Bool { height > 0 && support == nil }

    init(x: Double = 0, direction: Double = -1,
         randomNumberGenerator: any RandomNumberGenerator = SystemRandomNumberGenerator()) {
        self.x = x
        self.direction = direction
        self.randomNumberGenerator = randomNumberGenerator
    }

    mutating func drop(from height: Double) {
        self.height = max(0, height)
        fallSpeed = 0
        support = nil
        departedPlatformID = nil
    }

    mutating func advance(seconds: Double, width: Double, walking: Bool = true,
                          platforms: [WindowPlatform] = []) {
        guard seconds > 0 else { return }
        updateSupport(platforms, width: width)
        let walkingTime = advanceFall(seconds: seconds, platforms: platforms)
        guard walking, width > 0, walkingTime > 0 else { return }
        let span = support?.span(at: x) ?? (0...width)
        let left = max(0, span.lowerBound)
        let right = min(width, span.upperBound)
        guard right > left else { return }
        if support != nil {
            walkOnPlatform(seconds: walkingTime, left: left, right: right,
                           width: width, platforms: platforms)
            return
        }
        let spanWidth = right - left
        let travel = speed * walkingTime
        distance = (distance + travel).truncatingRemainder(dividingBy: 52)
        // Unfold the round trip so even a step crossing multiple edges reflects correctly.
        let phase = ((direction > 0 ? x - left : 2 * spanWidth - (x - left)) + travel)
            .truncatingRemainder(dividingBy: 2 * spanWidth)
        x = left + (phase <= spanWidth ? phase : 2 * spanWidth - phase)
        direction = phase < spanWidth ? 1 : -1
    }

    private mutating func walkOnPlatform(seconds: Double, left: Double, right: Double,
                                        width: Double, platforms: [WindowPlatform]) {
        var remaining = seconds
        while remaining > 0 {
            let edge = direction > 0 ? right : left
            let timeToEdge = abs(edge - x) / speed
            let elapsed = min(remaining, timeToEdge)
            x += direction * speed * elapsed
            distance = (distance + speed * elapsed).truncatingRemainder(dividingBy: 52)
            remaining = max(0, remaining - elapsed)
            guard elapsed == timeToEdge else { return }
            x = edge
            if Bool.random(using: &randomNumberGenerator) {
                // Keep the departing edge from immediately catching us again.
                departedPlatformID = support?.id
                support = nil
                fallSpeed = 0
                let walkingTime = advanceFall(seconds: remaining, platforms: platforms)
                if walkingTime > 0 {
                    advance(seconds: walkingTime, width: width, platforms: platforms)
                }
                return
            }
            direction = -direction
        }
    }

    private mutating func updateSupport(_ platforms: [WindowPlatform], width: Double) {
        guard let previous = support else { return }
        guard let current = platforms.first(where: { $0.id == previous.id }) else {
            support = nil
            return
        }
        let carriedX = x + current.frame.minX - previous.frame.minX
        guard carriedX >= 0, carriedX <= width, current.span(at: carriedX) != nil else {
            support = nil
            return
        }
        x = carriedX
        height = current.frame.maxY
        support = current
    }

    private mutating func advanceFall(seconds: Double, platforms: [WindowPlatform]) -> Double {
        guard isFalling else { return seconds }
        let landing = platforms.filter {
            $0.id != departedPlatformID && $0.frame.maxY <= height && $0.span(at: x) != nil
        }
            .max { $0.frame.maxY < $1.frame.maxY }
        let floor = landing?.frame.maxY ?? 0
        let gap = height - floor
        let landingTime = gap > 0 ? 2 * gap
            / (sqrt(fallSpeed * fallSpeed + 2 * Self.gravity * gap) + fallSpeed) : 0
        if seconds < landingTime {
            height -= fallSpeed * seconds + 0.5 * Self.gravity * seconds * seconds
            fallSpeed += Self.gravity * seconds
            return 0
        }
        height = floor
        fallSpeed = 0
        support = landing
        departedPlatformID = nil
        return seconds - landingTime
    }

    mutating func constrain(to width: Double) {
        x = min(max(0, x), max(0, width))
    }
}
