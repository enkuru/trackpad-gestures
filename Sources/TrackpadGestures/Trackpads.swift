import Foundation
import GestureCore
import os

/// MultitouchSupport is private, so its functions are bound at runtime instead of linked.
private struct MultitouchSupport {
    typealias Device = UnsafeMutableRawPointer
    typealias ContactCallback = @convention(c) (Device?, UnsafeRawPointer?, Int32, Double, Int32) -> Int32

    let createDeviceList: @convention(c) () -> Unmanaged<CFArray>?
    let register: @convention(c) (Device, ContactCallback) -> Void
    let unregister: @convention(c) (Device, ContactCallback) -> Void
    let start: @convention(c) (Device, Int32) -> Void
    let stop: @convention(c) (Device) -> Void
    let familyID: @convention(c) (Device, UnsafeMutablePointer<Int32>) -> Void
    let surfaceDimensions: @convention(c) (Device, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32

    init?() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_NOW) else { return nil }

        func bind<Function>(_ name: String) -> Function? {
            dlsym(handle, name).map { unsafeBitCast($0, to: Function.self) }
        }
        guard let createDeviceList: @convention(c) () -> Unmanaged<CFArray>? = bind("MTDeviceCreateList"),
              let register: @convention(c) (Device, ContactCallback) -> Void = bind("MTRegisterContactFrameCallback"),
              let unregister: @convention(c) (Device, ContactCallback) -> Void = bind("MTUnregisterContactFrameCallback"),
              let start: @convention(c) (Device, Int32) -> Void = bind("MTDeviceStart"),
              let stop: @convention(c) (Device) -> Void = bind("MTDeviceStop"),
              let familyID: @convention(c) (Device, UnsafeMutablePointer<Int32>) -> Void = bind("MTDeviceGetFamilyID"),
              let surfaceDimensions: @convention(c) (Device, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32 =
                  bind("MTDeviceGetSensorSurfaceDimensions")
        else { return nil }

        self.createDeviceList = createDeviceList
        self.register = register
        self.unregister = unregister
        self.start = start
        self.stop = stop
        self.familyID = familyID
        self.surfaceDimensions = surfaceDimensions
    }

    /// Family IDs as catalogued by jitouch: trackpads report 98 and up, the Magic Mouse reports 112.
    func isTrackpad(_ device: Device) -> Bool {
        var family: Int32 = 0
        familyID(device, &family)
        return family >= 98 && family != 112
    }

    /// In millimetres; the framework reports hundredths. Zero when the trackpad doesn't report it, which lets taps
    /// reach any distance.
    func surfaceSize(_ device: Device) -> CGSize {
        var width: Int32 = 0
        var height: Int32 = 0
        guard surfaceDimensions(device, &width, &height) == 0 else { return .zero }
        return CGSize(width: Double(width) / 100, height: Double(height) / 100)
    }
}

private struct TrackpadSession: Sendable {
    var decoder = TouchFrameDecoder()
    var recognizer: GestureRecognizer
}

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrackpadGestures", category: "trackpad")

/// Keyed by device address. MultitouchSupport calls back on its own thread, one call per frame.
private let sessions = OSAllocatedUnfairLock(initialState: [Int: TrackpadSession]())

private let contactCallback: MultitouchSupport.ContactCallback = { device, records, count, timestamp, frame in
    guard let device, let records else { return 0 }

    let gesture = sessions.withLockUnchecked { sessions -> Gesture? in
        guard var session = sessions[Int(bitPattern: device)] else { return nil }

        let measuredBefore = session.decoder.recordSize
        let touches = session.decoder.decode(records, count: Int(count), frame: frame, timestamp: timestamp)
        if measuredBefore == nil, let recordSize = session.decoder.recordSize {
            log.notice("Touch record size: \(String(describing: recordSize), privacy: .public)")
        }
        let gesture = session.recognizer.process(touches, at: timestamp)
        sessions[Int(bitPattern: device)] = session
        return gesture
    }

    if let gesture {
        Task { @MainActor in Trackpads.onGesture?(gesture) }
    }
    return 0
}

@MainActor
final class Trackpads {
    static var onGesture: ((Gesture) -> Void)?

    private let framework = MultitouchSupport()
    /// Retained so the handles in `listening` stay valid.
    private var deviceList: CFArray?
    private var listening: [MultitouchSupport.Device] = []

    var isAvailable: Bool { framework != nil }
    var count: Int { listening.count }

    /// Also used after wake and when a trackpad is connected: device handles go stale across sleep.
    func restart() {
        stop()
        guard let framework, let list = framework.createDeviceList()?.takeRetainedValue() else { return }

        listening = devices(in: list).filter(framework.isTrackpad)
        let newSessions = Dictionary(uniqueKeysWithValues: listening.map { device in
            let recognizer = GestureRecognizer(trackpadSize: framework.surfaceSize(device))
            return (Int(bitPattern: device), TrackpadSession(recognizer: recognizer))
        })
        sessions.withLock { $0 = newSessions }
        for device in listening {
            framework.register(device, contactCallback)
            framework.start(device, 0)
        }
        deviceList = list
        log.notice("Listening to \(self.listening.count) of \(CFArrayGetCount(list)) multitouch device(s)")
    }

    func stop() {
        guard let framework else { return }

        for device in listening {
            framework.unregister(device, contactCallback)
            framework.stop(device)
        }
        listening = []
        deviceList = nil
        sessions.withLock { $0.removeAll() }
    }

    private func devices(in list: CFArray) -> [MultitouchSupport.Device] {
        (0..<CFArrayGetCount(list)).compactMap { index in
            CFArrayGetValueAtIndex(list, index).map { UnsafeMutableRawPointer(mutating: $0) }
        }
    }
}
