import Dispatch
import Foundation
import Logging

final class TestEventsListener {    
    private let pairsController = TestEventPairsController()
    
    func testStarted(_ event: TestStartedEvent) {
        pairsController.append(TestEventPair(startEvent: event, finishEvent: nil))
    }
    
    func testFinished(_ event: TestFinishedEvent) {
        guard let pair = pairsController.popLast() else {
            log("Unable to find matching start event for \(event)", color: .red)
            log("The result for test \(event.testName) (\(event.result) will be lost.")
            return
        }
        guard pair.startEvent.test == event.test else {
            log("Last TestStartedEvent \(pair.startEvent) does not match just received finished event \(event)", color: .red)
            log("The result for test \(event.testName) (\(event.result) will be lost.")
            return
        }
        pairsController.append(TestEventPair(startEvent: pair.startEvent, finishEvent: event))
    }
    
    func testPlanFinished(_ event: TestPlanFinishedEvent) {
        guard let pair = self.lastStartedButNotFinishedTestEventPair else {
            log("Test plan finished, but there is no hang test found. All started tests have corresponding finished events.")
            return
        }
        reportTestPlanFinishedWithHangStartedTest(
            startEvent: pair.startEvent,
            testPlanFailed: !event.succeeded,
            testPlanEventTimestamp: event.timestamp)
    }
    
    func testPlanError(_ event: TestPlanErrorEvent) {
        guard let pair = self.lastStartedButNotFinishedTestEventPair else {
            log("Test plan errored, but there is no hang test found. All started tests have corresponding finished events.")
            return
        }
        reportTestPlanFinishedWithHangStartedTest(
            startEvent: pair.startEvent,
            testPlanFailed: true,
            testPlanEventTimestamp: event.timestamp)
    }
    
    // MARK: - Other methods that call basic methods above
    
    func errorDuringTest(_ event: GenericErrorEvent) {
        if event.domain == "com.facebook.XCTestBootstrap" {
            processBootstrapError(event)
        }
    }
    
    func longRunningTest() {
        guard let startEvent = lastStartedButNotFinishedTestEventPair?.startEvent else { return }
        let timestamp = Date().timeIntervalSince1970
        let failureEvent = TestFinishedEvent(
            test: startEvent.test,
            result: "long running test",
            className: startEvent.className,
            methodName: startEvent.methodName,
            totalDuration: timestamp - startEvent.timestamp,
            exceptions: [TestExceptionEvent(reason: "Test timeout. Test did not finish in time.", filePathInProject: #file, lineNumber: #line)],
            succeeded: false,
            output: "",
            logs: [],
            timestamp: timestamp)
        testFinished(failureEvent)
    }
    
    func timeoutDueToSilence() {
        guard let startEvent = lastStartedButNotFinishedTestEventPair?.startEvent else { return }
        let timestamp = Date().timeIntervalSince1970
        let failureEvent = TestFinishedEvent(
            test: startEvent.test,
            result: "timeout due to silence",
            className: startEvent.className,
            methodName: startEvent.methodName,
            totalDuration: timestamp - startEvent.timestamp,
            exceptions: [TestExceptionEvent(reason: "Timeout due to silence", filePathInProject: #file, lineNumber: #line)],
            succeeded: false,
            output: "",
            logs: [],
            timestamp: timestamp)
        testFinished(failureEvent)
    }
    
    var allEventPairs: [TestEventPair] {
        return pairsController.allPairs
    }
    
    var lastStartedButNotFinishedTestEventPair: TestEventPair? {
        if let pair = pairsController.lastPair, pair.finishEvent == nil {
            return pair
        }
        return nil
    }
    
    // MARK: - Private
    
    private func processBootstrapError(_ event: GenericErrorEvent) {
        guard let startEvent = lastStartedButNotFinishedTestEventPair?.startEvent else { return }
        let timestamp = Date().timeIntervalSince1970
        let bootstrapFailureEvent = TestFinishedEvent(
            test: startEvent.test,
            result: "bootstrap error",
            className: startEvent.className,
            methodName: startEvent.methodName,
            totalDuration: timestamp - startEvent.timestamp,
            exceptions: [TestExceptionEvent(reason: "Failed to bootstap event: \(event.text ?? "no details")", filePathInProject: #file, lineNumber: #line)],
            succeeded: false,
            output: "",
            logs: [],
            timestamp: timestamp)
        testFinished(bootstrapFailureEvent)
    }
    
    private func reportTestPlanFinishedWithHangStartedTest(
        startEvent: TestStartedEvent,
        testPlanFailed: Bool,
        testPlanEventTimestamp: TimeInterval)
    {
        let finishEvent = TestFinishedEvent(
            test: startEvent.test,
            result: "test plan early finish",
            className: startEvent.className,
            methodName: startEvent.methodName,
            totalDuration: testPlanEventTimestamp - startEvent.timestamp,
            exceptions: [
                TestExceptionEvent(
                    reason: "test plan finished (\(testPlanFailed ? "failed" : "with success")) but test did not receive finish event",
                    filePathInProject: #file,
                    lineNumber: #line)
            ],
            succeeded: false,
            output: "",
            logs: [],
            timestamp: testPlanEventTimestamp)
        log("Test plan finished, but hang test found: \(startEvent.description). Adding a finished event for it: \(finishEvent.description)")
        testFinished(finishEvent)
    }
}
