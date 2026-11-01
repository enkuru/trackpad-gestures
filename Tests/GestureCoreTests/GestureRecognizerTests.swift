import GestureCore
import Testing

/// A finger on the trackpad from `down` until `up`, sliding in a straight line from `from` to `to`.
private struct Finger {
    let id: Int
    let down: Double
    let up: Double
    let from: (x: Double, y: Double)
    var to: (x: Double, y: Double)?

    func position(at time: Double) -> TouchPoint {
        let end = to ?? from
        let progress = (time - down) / (up - down)
        return TouchPoint(id: id, x: from.x + (end.x - from.x) * progress, y: from.y + (end.y - from.y) * progress)
    }
}

/// Replays the fingers as 100 Hz frames, ending with the empty frame the trackpad sends when the last finger lifts.
private func gestures(for fingers: [Finger], tuning: GestureTuning = GestureTuning()) -> [Gesture] {
    var recognizer = GestureRecognizer(tuning: tuning)
    let lastFrame = Int((fingers.map(\.up).max() ?? 0) * 100) + 1

    return (0...lastFrame).compactMap { frame in
        let time = Double(frame) / 100
        let touches = fingers.filter { $0.down <= time && time < $0.up }.map { $0.position(at: time) }
        return recognizer.process(touches, at: time)
    }
}

@Test func threeFingersTappingTogetherAreAThreeFingerTap() {
    let fingers = [
        Finger(id: 1, down: 0.00, up: 0.12, from: (0.40, 0.5)),
        Finger(id: 2, down: 0.01, up: 0.13, from: (0.50, 0.5)),
        Finger(id: 3, down: 0.02, up: 0.14, from: (0.60, 0.5)),
    ]

    #expect(gestures(for: fingers) == [.threeFingerTap])
}

@Test func threeFingersHeldTooLongAreNotATap() {
    let fingers = [
        Finger(id: 1, down: 0.00, up: 0.60, from: (0.40, 0.5)),
        Finger(id: 2, down: 0.01, up: 0.60, from: (0.50, 0.5)),
        Finger(id: 3, down: 0.02, up: 0.60, from: (0.60, 0.5)),
    ]

    #expect(gestures(for: fingers).isEmpty)
}

@Test func threeFingerSwipeIsNotATap() {
    let fingers = [
        Finger(id: 1, down: 0.00, up: 0.15, from: (0.30, 0.5), to: (0.60, 0.5)),
        Finger(id: 2, down: 0.01, up: 0.15, from: (0.40, 0.5), to: (0.70, 0.5)),
        Finger(id: 3, down: 0.02, up: 0.15, from: (0.50, 0.5), to: (0.80, 0.5)),
    ]

    #expect(gestures(for: fingers).isEmpty)
}

@Test func fourFingerTapIsNotAThreeFingerTap() {
    let fingers = (1...4).map { Finger(id: $0, down: 0, up: 0.12, from: (0.2 * Double($0), 0.5)) }

    #expect(gestures(for: fingers).isEmpty)
}

@Test(arguments: [(0.30, Gesture.tipTapLeft), (0.70, Gesture.tipTapRight)])
func tapBesideARestingFingerIsATipTapOnThatSide(tapX: Double, expected: Gesture) {
    let fingers = [
        Finger(id: 1, down: 0.00, up: 1.00, from: (0.50, 0.5)),
        Finger(id: 2, down: 0.40, up: 0.50, from: (tapX, 0.5)),
    ]

    #expect(gestures(for: fingers) == [expected])
}

@Test func everyTapWhileTheFingerRestsCounts() {
    let taps = [0.30, 0.50, 0.70].enumerated().map { index, down in
        Finger(id: 10 + index, down: down, up: down + 0.08, from: (0.70, 0.5))
    }
    let fingers = [Finger(id: 1, down: 0.00, up: 1.00, from: (0.50, 0.5))] + taps

    #expect(gestures(for: fingers) == [.tipTapRight, .tipTapRight, .tipTapRight])
}

@Test func twoFingerTapIsNotATipTap() {
    let fingers = [
        Finger(id: 1, down: 0.00, up: 0.10, from: (0.40, 0.5)),
        Finger(id: 2, down: 0.01, up: 0.11, from: (0.60, 0.5)),
    ]

    #expect(gestures(for: fingers).isEmpty)
}

@Test func secondFingerHeldDownIsNotATipTap() {
    let fingers = [
        Finger(id: 1, down: 0.00, up: 1.00, from: (0.50, 0.5)),
        Finger(id: 2, down: 0.40, up: 0.80, from: (0.70, 0.5)),
    ]

    #expect(gestures(for: fingers).isEmpty)
}

@Test func restingFingerThatMovesDuringTheTapIsNotATipTap() {
    let fingers = [
        Finger(id: 1, down: 0.00, up: 0.30, from: (0.50, 0.5)),
        Finger(id: 1, down: 0.30, up: 0.50, from: (0.50, 0.5), to: (0.30, 0.5)),
        Finger(id: 1, down: 0.50, up: 1.00, from: (0.30, 0.5)),
        Finger(id: 2, down: 0.30, up: 0.45, from: (0.70, 0.5)),
    ]

    #expect(gestures(for: fingers).isEmpty)
}

@Test func tapBetweenTwoRestingFingersIsATipTapMiddle() {
    let fingers = [
        Finger(id: 1, down: 0.00, up: 1.00, from: (0.30, 0.5)),
        Finger(id: 2, down: 0.01, up: 1.00, from: (0.70, 0.5)),
        Finger(id: 3, down: 0.40, up: 0.50, from: (0.50, 0.5)),
    ]

    #expect(gestures(for: fingers) == [.tipTapMiddle])
}

@Test func tapOutsideTwoRestingFingersIsIgnored() {
    let fingers = [
        Finger(id: 1, down: 0.00, up: 1.00, from: (0.30, 0.5)),
        Finger(id: 2, down: 0.01, up: 1.00, from: (0.50, 0.5)),
        Finger(id: 3, down: 0.40, up: 0.50, from: (0.80, 0.5)),
    ]

    #expect(gestures(for: fingers).isEmpty)
}

@Test func quickTipTapMiddleIsNotAlsoAThreeFingerTap() {
    var tuning = GestureTuning()
    tuning.threeFingerLandingWindow = 0.2
    let fingers = [
        Finger(id: 1, down: 0.00, up: 0.25, from: (0.30, 0.5)),
        Finger(id: 2, down: 0.00, up: 0.25, from: (0.70, 0.5)),
        Finger(id: 3, down: 0.15, up: 0.20, from: (0.50, 0.5)),
    ]

    #expect(gestures(for: fingers, tuning: tuning) == [.tipTapMiddle])
}
