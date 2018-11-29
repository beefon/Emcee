import DistRun
import DistWork
import EventBus
import Foundation
import Models
import ModelsTestHelpers
import XCTest

final class QueueServerStressTests: XCTestCase {
    let eventBus = EventBus()
    let workerConfigurations = WorkerConfigurations()
    
    func test() throws {
        let workers = registerWorkers()
        let server = queueServer(workerConfigurations: workerConfigurations)
        let buckets = self.buckets()
        
        server.add(buckets: buckets)
        
        let serverPort = try server.start()
        
        let testingResults = waitForResults(timeout: 90, server: server) {
            let dispatchGroup = DispatchGroup()
            workers.forEach { worker in
                worker.startThread(serverPort: serverPort, dispatchGroup: dispatchGroup)
            }
            dispatchGroup.wait()
        }
        
        let allResults = testingResults.flatMap { $0.unfilteredResults }
        let allTests = buckets.flatMap { $0.testEntries }
        
        XCTAssertEqual(allResults.count, allTests.count)
    }
    
    private func registerWorkers() -> [Worker] {
        let workers: [Worker] = (0..<maxWorkers).map { index in
            let simulatedDefect: WorkerDefect?
            
            if index < maxWorkers * 1 / 4 {
                simulatedDefect = nil
            } else if index < maxWorkers * 2 / 4 {
                simulatedDefect = .stuckingTemporarily
            } else if index < maxWorkers * 3 / 4 {
                simulatedDefect = .dying
            } else {
                // TODO: Fix the issue when worker doesn't send the result
                // and bucket queue stucks then.
                // Uncomment the following line to test the fix:
                // simulatedDefect = .notSendingResult
                simulatedDefect = nil
            }
            
            return Worker(
                workerId: "worker_\(index)",
                defectToSimulate: simulatedDefect
            )
        }
        
        workers.forEach { worker in
            workerConfigurations.add(
                workerId: worker.workerId,
                configuration: WorkerConfigurationFixtures.workerConfiguration
            )
        }
        
        return workers
    }
    
    private func buckets() -> [Bucket] {
        return (0..<maxBuckets).map { bucketIndex in
            let range = minTests...(Int(arc4random() % UInt32(maxTests)) + minTests)
            
            return BucketFixtures.createBucket(
                testEntries: range.map { testIndex in
                    TestEntryFixtures.testEntry(className: "bucket_\(bucketIndex)", methodName: "test_\(testIndex)")
                }
            )
        }
    }
    
    private func queueServer(workerConfigurations: WorkerConfigurations) -> QueueServer {
        return QueueServer(
            eventBus: EventBus(),
            workerConfigurations: workerConfigurations,
            reportAliveInterval: 0.1,
            numberOfRetries: 0,
            // Set to small value to:
            // failed - Unexpected error: SynchronousWaiter reached timeout of 0.1 s for 'Waiting workers to appear' operation
            newWorkerRegistrationTimeAllowance: 60,
            // TODO: Try with small values
            queueExhaustTimeAllowance: .infinity
        )
    }
    
    private func waitForResults(
        timeout: TimeInterval,
        server: QueueServer,
        whileExecutingClosure closure: () -> ())
        -> [TestingResult]
    {
        var testingResults = [TestingResult]()
        let expectationForResults = expectation(description: "results became available")
        DispatchQueue.global().async {
            do {
                testingResults = try server.waitForQueueToFinish()
                expectationForResults.fulfill()
            } catch {
                XCTFail("Unexpected error: \(error)")
                expectationForResults.fulfill()
            }
        }
        
        closure()
        
        wait(for: [expectationForResults], timeout: timeout)
        
        return testingResults
    }
}

// Limits allows to guarantee finishing test in reasonable time
private let maxRetries = 2
private let maxWorkers = 70
private let maxBuckets = 1000
private let minTests = 1
private let maxTests = 3
private let maxFails = 100

private enum WorkerDefect {
    case stuckingTemporarily
    case dying
    case notSendingResult
}

private final class Worker {
    let workerId: String
    let defectToSimulate: WorkerDefect?
    var simulatedDefects = [WorkerDefect]() // may be useful for debugging
    var thread: Thread?
    var fails = 0
    var results = [TestEntryResult]()
    var client: SynchronousQueueClient!
    
    init(workerId: String, defectToSimulate: WorkerDefect?) {
        self.workerId = workerId
        self.defectToSimulate = defectToSimulate
    }
    
    func startThread(serverPort: Int, dispatchGroup: DispatchGroup) {
        dispatchGroup.enter()
        let thread = Thread { [weak self] in
            do {
                try self?.main(serverPort: serverPort)
            } catch {
                // do nothing
            }
            dispatchGroup.leave()
        }
        thread.start()
        self.thread = thread
    }
    
    private func main(serverPort: Int) throws {
        defer {
            try? simulateRandomDefect()
        }
        
        let arbitraryLargeNumber = 100
        let maxIterations = maxBuckets * (maxRetries + 1) * arbitraryLargeNumber
        
        client = SynchronousQueueClient(serverAddress: "localhost", serverPort: serverPort, workerId: workerId)
        
        _ = try client.registerWithServer()
        
        for _ in 0..<maxIterations {
            let requestId = UUID().uuidString
            
            try simulateRandomDefect()
            
            let fetchResult = try client.fetchBucket(requestId: requestId)
            
            try simulateRandomDefect()
            
            switch fetchResult {
            case .bucket(let bucket):
                try simulateNotSendingResult() {
                    try handleBucket(bucket: bucket, requestId: requestId)
                }
            case .queueIsEmpty:
                return
            case .checkLater(_ /* let timeInterval */):
                Thread.sleep(forTimeInterval: 0.001)
            case .workerHasBeenBlocked:
                return
            }
            
            try simulateRandomDefect()
            
            try client.reportAliveness()
            
            try simulateRandomDefect()
        }
    }
    
    private func handleBucket(bucket: Bucket, requestId: String) throws {
        let testingResult = TestingResult(
            bucketId: bucket.bucketId,
            testDestination: bucket.testDestination,
            unfilteredResults: fakeOutTestingResults(bucket: bucket)
        )
        results.append(contentsOf: testingResult.unfilteredResults)
        try client.send(testingResult: testingResult, requestId: requestId)
    }
    
    private func fakeOutTestingResults(bucket: Bucket) -> [TestEntryResult] {
        return bucket.testEntries.map { testEntry in
            let success: Bool
            
            switch arc4random() % 100 {
            case 0..<10:
                return TestEntryResult.lost(testEntry: testEntry)
            case 10..<20:
                success = maxFails < fails
            default:
                success = true
            }
            
            if !success { fails += 1 }
            
            return TestEntryResult.withResult(
                testEntry: testEntry,
                testRunResult: TestRunResultFixtures.testRunResult(succeeded: success)
            )
        }
    }
    
    private func simulateRandomDefect() throws {
        let shouldDefect = arc4random() % 100 == 0
        
        if shouldDefect {
            switch defectToSimulate {
            case .stuckingTemporarily?:
                simulateStucking()
            case .dying?:
                try simulateDying()
            case nil, .notSendingResult?:
                break
            }
        }
    }
    
    private func simulateStucking() {
        simulatedDefects.append(.stuckingTemporarily)
        
        Thread.sleep(forTimeInterval: 15)
    }
    
    private func simulateDying()throws {
        simulatedDefects.append(.dying)
        
        class Died: Error {}
        throw Died()
    }
    
    private func simulateNotSendingResult(sendingResultClosure: () throws -> ()) rethrows {
        if case .notSendingResult? = defectToSimulate {
            simulatedDefects.append(.notSendingResult)
        } else {
            try sendingResultClosure()
        }
    }
}
