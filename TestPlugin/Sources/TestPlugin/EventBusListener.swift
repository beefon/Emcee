import EventBus
import Foundation
import Logging
import Models

final class EventBusListener: EventStream {
    private let outputPath: String
    private var busEvents = [BusEvent]()
    
    public init(outputPath: String) {
        self.outputPath = outputPath
    }
    
    func process(event: BusEvent) {
        log("Received event: \(event)")
        busEvents.append(event)
        if case BusEvent.tearDown = event {
            tearDown()
        }
    }
    
    func tearDown() {
        dump()
    }
    
    private func dump() {
        do {
            try FileManager.default.createDirectory(
                atPath: (outputPath as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(busEvents)
            try data.write(to: URL(fileURLWithPath: outputPath))
            log("Dumped \(busEvents.count) events to file: '\(outputPath)'")
        } catch {
            log("Error: \(error)", color: .red)
        }
    }
}
