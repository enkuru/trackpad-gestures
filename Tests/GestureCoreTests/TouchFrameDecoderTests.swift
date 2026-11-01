import GestureCore
import Testing

private struct Record {
    let id: Int32
    let state: Int32
    let x: Float
    let y: Float
}

/// Lays records out the way MultitouchSupport does, with `size` bytes per record.
private func withFrame<Result>(
    _ records: [Record], size: Int, frame: Int32, timestamp: Double, stampFrame: Bool = true,
    _ body: (UnsafeRawPointer) -> Result
) -> Result {
    let buffer = UnsafeMutableRawPointer.allocate(byteCount: records.count * size, alignment: 8)
    defer { buffer.deallocate() }
    buffer.initializeMemory(as: UInt8.self, repeating: 0, count: records.count * size)

    for (index, record) in records.enumerated() {
        let start = index * size
        if stampFrame {
            buffer.storeBytes(of: frame, toByteOffset: start, as: Int32.self)
            buffer.storeBytes(of: timestamp, toByteOffset: start + 8, as: Double.self)
        }
        buffer.storeBytes(of: record.id, toByteOffset: start + 16, as: Int32.self)
        buffer.storeBytes(of: record.state, toByteOffset: start + 20, as: Int32.self)
        buffer.storeBytes(of: record.x, toByteOffset: start + 32, as: Float.self)
        buffer.storeBytes(of: record.y, toByteOffset: start + 36, as: Float.self)
    }
    return body(UnsafeRawPointer(buffer))
}

@Test(arguments: [96, 112, 160])
func measuresTheRecordSizeAndReadsOnlyFingersOnTheSurface(size: Int) {
    var decoder = TouchFrameDecoder()
    let records = [
        Record(id: 7, state: 4, x: 0.25, y: 0.5),
        Record(id: 8, state: 3, x: 0.75, y: 0.5),
        Record(id: 9, state: 2, x: 0.5, y: 0.9),
    ]

    let touches = withFrame(records, size: size, frame: 4242, timestamp: 1234.5) {
        decoder.decode($0, count: records.count, frame: 4242, timestamp: 1234.5)
    }

    #expect(decoder.recordSize == .measured(size))
    #expect(touches == [TouchPoint(id: 7, x: 0.25, y: 0.5), TouchPoint(id: 8, x: 0.75, y: 0.5)])
}

@Test func fallsBackToTheLegacySizeWhenRecordsCarryNoFrameNumber() {
    var decoder = TouchFrameDecoder()
    let records = [Record(id: 1, state: 4, x: 0.25, y: 0.5), Record(id: 2, state: 4, x: 0.75, y: 0.5)]

    let touches = withFrame(records, size: 96, frame: 1, timestamp: 1, stampFrame: false) {
        decoder.decode($0, count: records.count, frame: 1, timestamp: 1)
    }

    #expect(decoder.recordSize == .assumed(96))
    #expect(touches.map(\.id) == [1, 2])
}
