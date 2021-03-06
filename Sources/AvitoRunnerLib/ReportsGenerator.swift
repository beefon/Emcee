import ChromeTracing
import Foundation
import JunitReporting
import Logging
import Models

public final class ReportsGenerator {
    private let testingResult: CombinedTestingResults
    private let reportOutput: ReportOutput
    public init(testingResult: CombinedTestingResults, reportOutput: ReportOutput) {
        self.testingResult = testingResult
        self.reportOutput = reportOutput
    }
    
    public func prepareReports() throws {
        try createDirectories()
        try prepareJunitReport(testingResult: testingResult, path: reportOutput.junit)
        try prepareTraceReport(testingResult: testingResult, path: reportOutput.tracingReport)
    }
    
    private func createDirectories() throws {
        try FileManager.default.createDirectory(
            atPath: reportOutput.junit.deletingLastPathComponent,
            withIntermediateDirectories: true,
            attributes: nil)
        try FileManager.default.createDirectory(
            atPath: reportOutput.tracingReport.deletingLastPathComponent,
            withIntermediateDirectories: true,
            attributes: nil)
    }
    
    private func prepareJunitReport(testingResult: CombinedTestingResults, path: String) throws {
        let testCases = testingResult.unfilteredResults
            .map { (testEntryResult: TestEntryResult) -> JunitTestCase in
                let testRunResult = testEntryResult.appropriateTestRunResult
                let failures = testRunResult.exceptions.map {
                    JunitTestCaseFailure(
                        reason: $0.reason,
                        fileLine: "\($0.filePathInProject):\($0.lineNumber)")
                }
                let boundaries = JunitTestCaseBoundaries(
                    processId: testRunResult.processId,
                    simulatorId: testRunResult.simulatorId,
                    startTime: testRunResult.startTime,
                    finishTime: testRunResult.finishTime)
                return JunitTestCase(
                    caseId: testEntryResult.testEntry.caseId,
                    className: testEntryResult.testEntry.className,
                    name: testEntryResult.testEntry.methodName,
                    time: testRunResult.duration,
                    isFailure: !testRunResult.succeeded,
                    failures: failures,
                    boundaries: boundaries)
        }
        
        let generator = JunitGenerator(testCases: testCases)
        do {
            try generator.writeReport(path: path)
            log("Stored Junit report at \(path)")
        } catch let error {
            log("Failed to write out junit report. Error: \(error)", color: .red)
            throw error
        }
    }
    
    private func prepareTraceReport(testingResult: CombinedTestingResults, path: String) throws {
        let generator = ChromeTraceGenerator(testingResult: testingResult)
        do {
            try generator.writeReport(path: path)
            log("Stored trace report at \(path)")
        } catch let error {
            log("Failed to write out trace report. Error: \(error)", color: .red)
            throw error
        }
    }
}

private extension TestEntryResult {
    /// Returns a `TestRunResult` that can be used as a single result for this `TestEntry`.
    /// E.g. if there is any successful result, it will be returned. Otherwise, a failed result will be returned.
    var appropriateTestRunResult: TestRunResult {
        let appropriateTestRunResult: TestRunResult?
        
        let sorted = testRunResults.sorted { (left, right) -> Bool in
            return left.startTime > right.startTime
        }
        if succeeded {
            appropriateTestRunResult = sorted.first(where: { (result: TestRunResult) -> Bool in result.succeeded == true })
        } else {
            appropriateTestRunResult = sorted.first
        }
        
        return appropriateTestRunResult!
    }

}
