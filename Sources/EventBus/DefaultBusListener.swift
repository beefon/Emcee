import Foundation
import Models

open class DefaultBusListener: EventStream {
    
    public init() {}
    
    open func process(event: BusEvent) {
        switch event {
        case .didObtainTestingResult(let testingResult):
            didObtain(testingResult: testingResult)
        case .runnerEvent(let runnerEvent):
            self.runnerEvent(runnerEvent)
        case .tearDown:
            tearDown()
        }
    }
    
    /// Called when a `TestingResult` has been obtained for a corresponding `Bucket`.
    open func didObtain(testingResult: TestingResult) {}
    
    /// Called when Runner reports an event
    open func runnerEvent(_ event: RunnerEvent) {}
    
    /// Called when listener should tear down
    open func tearDown() {}
}
