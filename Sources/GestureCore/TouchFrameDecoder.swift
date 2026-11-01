/// Reads the contact records MultitouchSupport passes to its frame callback.
///
/// The record layout is private. It is 96 bytes on macOS 26.5, but other tools report a changed size on some
/// macOS 26 builds, so it is not hard-coded. Every record starts with the frame number and timestamp the
/// callback also receives, which lets the size be measured from the first frame with two fingers.
public struct TouchFrameDecoder: Sendable {
    public enum RecordSize: Equatable, Sendable {
        case measured(Int)
        /// Measuring failed, so the pre-macOS 26 size is used.
        case assumed(Int)

        var bytes: Int {
            switch self {
            case .measured(let bytes), .assumed(let bytes): bytes
            }
        }
    }

    static let legacyRecordSize = 96

    private enum Offset {
        static let frame = 0
        static let timestamp = 8
        static let identifier = 16
        static let state = 20
        static let x = 32
        static let y = 36
    }

    /// MakeTouch and Touching. Hovering, lifting and lingering records are not fingers on the surface.
    private static let contactStates: Set<Int32> = [3, 4]

    public private(set) var recordSize: RecordSize?

    public init() {}

    public mutating func decode(_ records: UnsafeRawPointer, count: Int, frame: Int32, timestamp: Double) -> [TouchPoint] {
        if recordSize == nil, count >= 2 {
            recordSize = Self.measureRecordSize(records, frame: frame, timestamp: timestamp)
                .map(RecordSize.measured) ?? .assumed(Self.legacyRecordSize)
        }
        let size = recordSize?.bytes ?? Self.legacyRecordSize

        return (0..<count).compactMap { index in
            let record = records + index * size
            guard Self.contactStates.contains(record.loadUnaligned(fromByteOffset: Offset.state, as: Int32.self))
            else { return nil }

            return TouchPoint(
                id: Int(record.loadUnaligned(fromByteOffset: Offset.identifier, as: Int32.self)),
                x: Double(record.loadUnaligned(fromByteOffset: Offset.x, as: Float.self)),
                y: Double(record.loadUnaligned(fromByteOffset: Offset.y, as: Float.self))
            )
        }
    }

    /// Scans upward so the true size matches before any read could pass the end of a two-record buffer.
    private static func measureRecordSize(_ records: UnsafeRawPointer, frame: Int32, timestamp: Double) -> Int? {
        func startsRecord(at offset: Int) -> Bool {
            records.loadUnaligned(fromByteOffset: offset + Offset.frame, as: Int32.self) == frame
                && abs(records.loadUnaligned(fromByteOffset: offset + Offset.timestamp, as: Double.self) - timestamp) < 1
        }

        guard startsRecord(at: 0) else { return nil }
        return stride(from: 64, through: 256, by: 8).first(where: startsRecord)
    }
}
