import Dispatch
import EventBus
import Extensions
import Foundation
import ListeningSemaphore
import Logging
import Models
import ResourceLocationResolver
import Runner
import ScheduleStrategy
import SimulatorPool
import TempFolder

/**
 * This class manages Runner instances, and provides back a TestingResult object with all results for all tests.
 * It fetches the Bucket it will process using the SchedulerDataSource object.
 * It will request Bucket for each Simulator as soon as it becomes available.
 * You can listen to the events via EventStream. In this case you will receive information about the run
 * quicker than if you'd wait until run() method finishes.
 *
 * Scheduler uses `ListeningSemaphore` to allocate resources and limit maximum number of running tests.
 *
 * The flow can be described like that:
 * 1. Enter the Queue and fetch Bucket, add Operation to the Queue if Bucket has been fetched.
 * 1.1 - If there's no Bucket inside Data Source, do not add Operation to the queue. This is an exit point.
 * 2. Run tests in the fetched Bucket inside Queue.
 * 3. Repeat.
 * 4. Wait for Queue to become empty.
 *
 * Eventually the Queue will finish all operations.
 * At this point we will merge the results and provide back an array of TestingResult objects for each Bucket.
 */
public final class Scheduler {
    private let eventBus: EventBus
    private let configuration: SchedulerConfiguration
    private let resourceSemaphore: ListeningSemaphore
    private var testingResults = [TestingResult]()
    private let queue = OperationQueue()
    private let syncQueue = DispatchQueue(label: "ru.avito.Scheduler")
    private let tempFolder: TempFolder
    private let resourceLocationResolver: ResourceLocationResolver
    private var gatheredErrors = [Error]()
    
    public enum SchedulerError: Error, CustomStringConvertible {
        case someErrorsHappened([Error])
        
        public var description: String {
            switch self {
            case .someErrorsHappened(let errors):
                return "During execution of tests the following errors happened: \(errors)"
            }
        }
    }
    
    public init(
        eventBus: EventBus,
        configuration: SchedulerConfiguration,
        tempFolder: TempFolder,
        resourceLocationResolver: ResourceLocationResolver)
    {
        self.eventBus = eventBus
        self.configuration = configuration
        self.resourceSemaphore = ListeningSemaphore(
            maximumValues: .of(
                runningTests: Int(configuration.testRunExecutionBehavior.numberOfSimulators)))
        self.tempFolder = tempFolder
        self.resourceLocationResolver = resourceLocationResolver
    }
    
    /**
     * Runs the tests. This method blocks until all Buckets from the Data Source will be executed.
     * It returns a single TestingResult object that contains all test resutls for all tests in all Buckets.
     * You can listen to the live events for each Bucket via EventStream.
     */
    public func run() throws -> [TestingResult] {
        startFetchingAndRunningTests()
        queue.waitUntilAllOperationsAreFinished()
        if !gatheredErrors.isEmpty {
            throw SchedulerError.someErrorsHappened(gatheredErrors)
        }
        return testingResults
    }
    
    // MARK: - Running on Queue
    
    private func startFetchingAndRunningTests() {
        fetchAndRunBucket()
    }
    
    private func fetchAndRunBucket() {
        queue.addOperation {
            if self.resourceSemaphore.availableResources.runningTests == 0 {
                return
            }
            guard self.gatheredErrors.isEmpty else {
                log("Error: Some errors occured, will not fetch and run more buckets. Errors: \(self.gatheredErrors)", color: .red)
                return
            }
            guard let bucket = self.configuration.schedulerDataSource.nextBucket() else {
                log("Data Source returned no bucket")
                return
            }
            log("Data Source returned bucket: \(bucket)")
            self.runTestsFromFetchedBucket(bucket)
        }
    }
    
    private func runTestsFromFetchedBucket(_ bucket: SchedulerBucket) {
        do {
            let resourceRequirement = bucket.testDestination.resourceRequirement
            let acquireResources = try resourceSemaphore.acquire(.of(runningTests: resourceRequirement))
            let runTestsInBucketAfterAcquiringResources = BlockOperation {
                do {
                    self.fetchAndRunBucket()
                    let testingResult = try self.runRetrying(bucket: bucket)
                    try self.resourceSemaphore.release(.of(runningTests: resourceRequirement))
                    self.didReceiveResults(testingResult: testingResult)
                    self.eventBus.post(event: .didObtainTestingResult(testingResult))
                    self.fetchAndRunBucket()
                } catch {
                    self.didFailRunningTests(bucket: bucket, error: error)
                }
            }
            acquireResources.addCascadeCancellableDependency(runTestsInBucketAfterAcquiringResources)
            queue.addOperation(runTestsInBucketAfterAcquiringResources)
        } catch {
            log("Failed to run tests from bucket \(bucket): \(error)")
        }
    }
    
    private func didReceiveResults(testingResult: TestingResult) {
        syncQueue.sync {
            testingResults.append(testingResult)
        }
    }
    
    private func didFailRunningTests(bucket: SchedulerBucket, error: Error) {
        log("Error running tests from fetched bucket '\(bucket)' with error: \(error)")
        syncQueue.sync {
            gatheredErrors.append(error)
        }
    }
    
    // MARK: - Running the Tests
    
    /**
     Runs tests in a given Bucket, retrying failed tests multiple times if necessary.
     */
    private func runRetrying(bucket: SchedulerBucket) throws -> TestingResult {
        let firstRun = try runBucketOnce(bucket: bucket, testsToRun: bucket.testEntries)
        
        guard configuration.testRunExecutionBehavior.numberOfRetries > 0 else {
            log("numberOfRetries == 0, will not retry failed tests.")
            return firstRun
        }
        
        var lastRunResults = firstRun
        var results = [firstRun]
        for retryNumber in 0 ..< configuration.testRunExecutionBehavior.numberOfRetries {
            let failedTestEntriesAfterLastRun = lastRunResults.failedTests.map { $0.testEntry }
            if failedTestEntriesAfterLastRun.isEmpty {
                log("No failed tests after last retry, so nothing to run.")
                break
            }
            log("After last run \(failedTestEntriesAfterLastRun.count) tests have failed: \(failedTestEntriesAfterLastRun).")
            log("Retrying them, attempt #\(retryNumber + 1) of maximum \(configuration.testRunExecutionBehavior.numberOfRetries) attempts")
            lastRunResults = try runBucketOnce(bucket: bucket, testsToRun: failedTestEntriesAfterLastRun)
            results.append(lastRunResults)
        }
        return try combine(runResults: results)
    }
    
    private func runBucketOnce(bucket: SchedulerBucket, testsToRun: [TestEntry]) throws -> TestingResult {
        let simulatorPool = try configuration.onDemandSimulatorPool.pool(
            key: OnDemandSimulatorPool.Key(
                numberOfSimulators: configuration.testRunExecutionBehavior.numberOfSimulators,
                testDestination: bucket.testDestination,
                fbsimctl: bucket.toolResources.fbsimctl))
        let simulatorController = try simulatorPool.allocateSimulator()
        defer { simulatorPool.freeSimulator(simulatorController) }
            
        let runner = Runner(
            eventBus: eventBus,
            configuration: RunnerConfiguration(
                testType: configuration.testType,
                fbxctest: bucket.toolResources.fbxctest,
                buildArtifacts: bucket.buildArtifacts,
                environment: bucket.environment,
                simulatorSettings: bucket.simulatorSettings,
                testTimeoutConfiguration: configuration.testTimeoutConfiguration
            ),
            tempFolder: tempFolder,
            resourceLocationResolver: resourceLocationResolver
        )
        let simulator: Simulator
        do {
            simulator = try simulatorController.bootedSimulator()
        } catch {
            log("Failed to get booted simulator: \(error)")
            try simulatorController.deleteSimulator()
            throw error
        }

        let runnerResult = try runner.run(entries: testsToRun, onSimulator: simulator)
        return TestingResult(
            bucketId: bucket.bucketId,
            testDestination: bucket.testDestination,
            unfilteredResults: runnerResult
        )
    }
    
    // MARK: - Utility Methods
    
    /**
     Combines several TestingResult objects of the same Bucket, after running and retrying tests,
     so if some tests become green, the resulting combined object will have it in a green state.
     */
    private func combine(runResults: [TestingResult]) throws -> TestingResult {
        // All successful tests should be merged into a single array.
        // Last run's `failedTests` contains all tests that failed after all attempts to rerun failed tests.
        log("Combining the following results from \(runResults.count) runs:")
        runResults.forEach { log("Result: \($0)") }
        let result = try TestingResult.byMerging(testingResults: runResults)
        log("Combined result: \(result)")
        return result
    }
}
