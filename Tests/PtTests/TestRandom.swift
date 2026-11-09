struct FixedRandom: RandomNumberGenerator {
    let value: UInt64

    mutating func next() -> UInt64 { value }
}

final class CountingRandom: RandomNumberGenerator {
    private(set) var calls = 0

    func next() -> UInt64 {
        calls += 1
        return .max
    }
}
