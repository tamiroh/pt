import Foundation

struct Walker {
    static let gravity: Double = 1_200
    // Far enough past a screen edge that none of the body is left showing.
    static let offstageMargin: Double = 48
    static let awayTime: ClosedRange<Double> = 5...20
    static let floatSpeed: Double = 50
    static let balloonTrigger: Double = 400
    static let balloonBrake: Double = 1_500

    var x: Double = 0
    var direction: Double = -1
    private(set) var distance: Double = 0
    private(set) var height: Double = 0
    private(set) var isOffstage = false
    // Drifting down under a balloon instead of falling freely.
    private(set) var isFloating = false
    private var floatTime: Double = 0
    private var leaving = false
    private var awayRemaining: Double = 0
    private var fallSpeed: Double = 0
    private var support: WindowPlatform?
    private var departedPlatformID: UInt32?
    private var randomNumberGenerator: any RandomNumberGenerator
    let speed: Double = 27

    var swing: Double { sin(distance / 26 * .pi) * 10 }
    var isFalling: Bool { height > 0 && support == nil }
    // Pendulum angle in degrees beneath the balloon; positive swings to the right.
    var sway: Double { isFloating ? sin(floatTime / 3.2 * 2 * .pi) * 9 : 0 }

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
        leaving = false
        isOffstage = false
        isFloating = false
    }

    // `ceiling` is the height the walker drops back in from after a trip offstage.
    mutating func advance(seconds: Double, width: Double, walking: Bool = true,
                          platforms: [WindowPlatform] = [], ceiling: Double = 0) {
        guard seconds > 0 else { return }
        if isOffstage {
            guard walking else { return }
            awayRemaining -= seconds
            guard awayRemaining <= 0 else { return }
            x = random(in: 0...max(0, width))
            direction = Bool.random(using: &randomNumberGenerator) ? 1 : -1
            drop(from: ceiling)
            if height > 0 { startFloating() }
            return
        }
        updateSupport(platforms, width: width)
        let walkingTime = advanceFall(seconds: seconds, platforms: platforms)
        guard walking, width > 0, walkingTime > 0 else { return }
        if leaving {
            walkOffstage(seconds: walkingTime, width: width)
            return
        }
        let span = support?.span(at: x) ?? (0...width)
        let left = max(0, span.lowerBound)
        let right = min(width, span.upperBound)
        guard right > left else { return }
        walk(seconds: walkingTime, left: left, right: right, width: width, platforms: platforms)
    }

    private mutating func walk(seconds: Double, left: Double, right: Double,
                               width: Double, platforms: [WindowPlatform]) {
        var remaining = seconds
        while remaining > 0 {
            let edge = direction > 0 ? right : left
            let timeToEdge = abs(edge - x) / speed
            let elapsed = min(remaining, timeToEdge)
            step(elapsed)
            remaining = max(0, remaining - elapsed)
            guard elapsed == timeToEdge else { return }
            x = edge
            if Bool.random(using: &randomNumberGenerator) {
                guard support != nil else {
                    // At a screen edge on the ground, keep going and leave the screen.
                    leaving = true
                    walkOffstage(seconds: remaining, width: width)
                    return
                }
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

    private mutating func walkOffstage(seconds: Double, width: Double) {
        step(seconds)
        guard x <= -Self.offstageMargin || x >= width + Self.offstageMargin else { return }
        leaving = false
        isOffstage = true
        awayRemaining = random(in: Self.awayTime)
    }

    private mutating func step(_ seconds: Double) {
        x += direction * speed * seconds
        distance = (distance + speed * seconds).truncatingRemainder(dividingBy: 52)
    }

    // Uses the raw bits directly; the standard library's float sampling can retry forever
    // on a constant generator.
    private mutating func random(in range: ClosedRange<Double>) -> Double {
        let unit = Double(randomNumberGenerator.next() >> 11) / Double(1 << 53)
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
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
        if isFloating {
            return advanceFloat(seconds: seconds, gap: gap, landing: landing)
        }
        let landingTime = gap > 0 ? 2 * gap
            / (sqrt(fallSpeed * fallSpeed + 2 * Self.gravity * gap) + fallSpeed) : 0
        let triggerTime = max(0, Self.balloonTrigger - fallSpeed) / Self.gravity
        if triggerTime < landingTime, triggerTime <= seconds {
            descend(triggerTime, acceleration: Self.gravity)
            startFloating(speed: fallSpeed)
            return advanceFloat(seconds: seconds - triggerTime, gap: height - floor, landing: landing)
        }
        if seconds < landingTime {
            descend(seconds, acceleration: Self.gravity)
            return 0
        }
        land(on: landing, at: floor)
        return seconds - landingTime
    }

    private mutating func advanceFloat(seconds: Double, gap: Double,
                                       landing: WindowPlatform?) -> Double {
        let floor = height - gap
        var remaining = seconds
        if fallSpeed > Self.floatSpeed {
            let brakingTime = (fallSpeed - Self.floatSpeed) / Self.balloonBrake
            let brakingDistance = (fallSpeed + Self.floatSpeed) / 2 * brakingTime
            if gap <= brakingDistance {
                let landingTime = 2 * gap / (fallSpeed + sqrt(max(0,
                    fallSpeed * fallSpeed - 2 * Self.balloonBrake * gap)))
                if remaining < landingTime {
                    descend(remaining, acceleration: -Self.balloonBrake)
                    return 0
                }
                land(on: landing, at: floor)
                return remaining - landingTime
            }
            if remaining < brakingTime {
                descend(remaining, acceleration: -Self.balloonBrake)
                return 0
            }
            descend(brakingTime, acceleration: -Self.balloonBrake)
            fallSpeed = Self.floatSpeed
            remaining -= brakingTime
        }
        let landingTime = (height - floor) / Self.floatSpeed
        if remaining < landingTime {
            descend(remaining, acceleration: 0)
            return 0
        }
        land(on: landing, at: floor)
        return remaining - landingTime
    }

    private mutating func descend(_ seconds: Double, acceleration: Double) {
        height -= fallSpeed * seconds + 0.5 * acceleration * seconds * seconds
        fallSpeed += acceleration * seconds
        if isFloating { floatTime += seconds }
    }

    private mutating func startFloating(speed: Double = floatSpeed) {
        isFloating = true
        floatTime = 0
        fallSpeed = speed
    }

    private mutating func land(on landing: WindowPlatform?, at floor: Double) {
        isFloating = false
        height = floor
        fallSpeed = 0
        support = landing
        departedPlatformID = nil
    }

    mutating func constrain(to width: Double) {
        guard !leaving, !isOffstage else { return }
        x = min(max(0, x), max(0, width))
    }
}
