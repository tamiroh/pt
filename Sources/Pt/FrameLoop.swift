import Foundation
import QuartzCore

@MainActor
final class FrameLoop: NSObject {
    struct Frame {
        let time: Double
        let seconds: Double

        init(time: Double, previousTime: Double) {
            self.time = time
            seconds = min(max(0, time - previousTime), 0.1)
        }
    }

    private var timer: Timer?
    private var previousTime = CACurrentMediaTime()
    private var onFrame: ((Frame) -> Void)?

    func start(_ onFrame: @escaping (Frame) -> Void) {
        stop()
        self.onFrame = onFrame
        resetTime()
        let timer = Timer(timeInterval: 1.0 / 60, target: self,
                          selector: #selector(tick), userInfo: nil, repeats: true)
        timer.tolerance = 1.0 / 600
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        onFrame = nil
    }

    func resetTime() {
        previousTime = CACurrentMediaTime()
    }

    @objc private func tick() {
        let frame = Frame(time: CACurrentMediaTime(), previousTime: previousTime)
        previousTime = frame.time
        onFrame?(frame)
    }
}
