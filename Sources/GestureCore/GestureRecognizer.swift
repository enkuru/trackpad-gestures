public struct TouchPoint: Equatable, Sendable {
    public let id: Int
    /// 0 is the trackpad's left edge, 1 its right edge.
    public let x: Double
    /// 0 is the trackpad's bottom edge, 1 its top edge.
    public let y: Double

    public init(id: Int, x: Double, y: Double) {
        self.id = id
        self.x = x
        self.y = y
    }

    func distance(to other: TouchPoint) -> Double {
        ((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y)).squareRoot()
    }
}

public enum Gesture: Equatable, Sendable {
    /// Three fingers land and lift together.
    case threeFingerTap
    /// One finger rests while another taps to its left.
    case tipTapLeft
    /// One finger rests while another taps to its right.
    case tipTapRight
    /// Two fingers rest while a third taps between them.
    case tipTapMiddle
}

/// Distances are in trackpad widths/heights, durations in seconds.
public struct GestureTuning: Sendable {
    public var tapMaxDuration = 0.25
    public var tapMaxTravel = 0.05
    /// Resting fingers must land this long before the tap, which keeps plain two- and three-finger taps out.
    public var restMinLead = 0.12
    public var restMaxTravel = 0.06
    public var threeFingerLandingWindow = 0.12
    public var threeFingerMaxDuration = 0.3

    public init() {}
}

/// Turns the stream of trackpad frames into gestures. A session runs from the first finger landing until
/// every finger has lifted.
public struct GestureRecognizer: Sendable {
    private struct Contact: Sendable {
        let start: Double
        let origin: TouchPoint
        var position: TouchPoint
        /// Furthest distance from where the finger landed.
        var travel = 0.0
        /// Where the other fingers were when this one landed.
        let othersAtStart: [Int: TouchPoint]
    }

    private struct Lift: Sendable {
        let start: Double
        let end: Double
        let travel: Double
    }

    private let tuning: GestureTuning
    private var contacts: [Int: Contact] = [:]
    private var lifts: [Lift] = []
    private var peakContacts = 0
    private var recognizedTipTap = false

    public init(tuning: GestureTuning = GestureTuning()) {
        self.tuning = tuning
    }

    /// Feeds one frame holding every finger currently on the trackpad.
    public mutating func process(_ touches: [TouchPoint], at time: Double) -> Gesture? {
        let current = Dictionary(touches.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let lifted = contacts.keys.filter { current[$0] == nil }

        var gesture = lifted.count == 1 ? tipTap(lifting: lifted[0], at: time) : nil
        if gesture != nil {
            recognizedTipTap = true
        }
        for id in lifted {
            if let contact = contacts.removeValue(forKey: id) {
                lifts.append(Lift(start: contact.start, end: time, travel: contact.travel))
            }
        }

        for touch in touches {
            if var contact = contacts[touch.id] {
                contact.position = touch
                contact.travel = max(contact.travel, touch.distance(to: contact.origin))
                contacts[touch.id] = contact
            } else {
                let others = contacts.mapValues(\.position)
                contacts[touch.id] = Contact(start: time, origin: touch, position: touch, othersAtStart: others)
            }
        }
        peakContacts = max(peakContacts, contacts.count)

        if contacts.isEmpty {
            gesture = gesture ?? threeFingerTap()
            resetSession()
        }
        return gesture
    }

    private func tipTap(lifting id: Int, at time: Double) -> Gesture? {
        guard let tap = contacts[id] else { return nil }

        let resting = contacts.filter { $0.key != id }
        guard time - tap.start <= tuning.tapMaxDuration,
              tap.travel <= tuning.tapMaxTravel,
              Set(resting.keys) == Set(tap.othersAtStart.keys),
              !lifts.contains(where: { $0.end > tap.start })
        else { return nil }

        for (restingId, finger) in resting {
            guard let positionAtTap = tap.othersAtStart[restingId],
                  tap.start - finger.start >= tuning.restMinLead,
                  finger.position.distance(to: positionAtTap) <= tuning.restMaxTravel
            else { return nil }
        }

        let restingX = resting.values.map(\.position.x).sorted()
        let tapX = tap.origin.x
        switch restingX.count {
        case 1:
            return tapX < restingX[0] ? .tipTapLeft : .tipTapRight
        case 2 where restingX[0] < tapX && tapX < restingX[1]:
            return .tipTapMiddle
        default:
            return nil
        }
    }

    private func threeFingerTap() -> Gesture? {
        let starts = lifts.map(\.start)
        guard !recognizedTipTap,
              peakContacts == 3,
              lifts.count == 3,
              let firstLanding = starts.min(),
              let lastLanding = starts.max(),
              let lastLift = lifts.map(\.end).max(),
              lastLanding - firstLanding <= tuning.threeFingerLandingWindow,
              lastLift - firstLanding <= tuning.threeFingerMaxDuration,
              lifts.allSatisfy({ $0.travel <= tuning.tapMaxTravel })
        else { return nil }

        return .threeFingerTap
    }

    private mutating func resetSession() {
        contacts = [:]
        lifts = []
        peakContacts = 0
        recognizedTipTap = false
    }
}
