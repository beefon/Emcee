import BucketQueue
import Foundation
import Models
import ModelsTestHelpers
import WorkerAlivenessTracker
import WorkerAlivenessTrackerTestHelpers
import XCTest

final class BucketQueueStressTests: XCTestCase {
    func test___bucket_queue___works_properly___while_being_stress_tested() {
        let dispatchGroup = DispatchGroup()

        let workers: [Worker] = (0..<100).map { index in
            Worker(id: "worker_\(index)")
        }

        let bucketQueue = self.bucketQueue(workerIds: workers.map { $0.workerId }, numberOfRetries: maxRetries)
        let buckets: [Bucket] = (0..<maxBuckets).map { bucketIndex in
            let range = minTests...(Int(arc4random() % UInt32(maxTests)) + minTests)

            return BucketFixtures.createBucket(
                testEntries: range.map { testIndex in
                    TestEntryFixtures.testEntry(className: "bucket_\(bucketIndex)", methodName: "test_\(testIndex)")
                }
            )
        }

        bucketQueue.enqueue(buckets: buckets)

        for worker in workers {
            worker.startThread(bucketQueue: bucketQueue, dispatchGroup: dispatchGroup)
        }
        
        dispatchGroup.wait()
        
        let allTests = buckets.flatMap { $0.testEntries }
        let allResults = workers.flatMap { $0.results }
        
        XCTAssertEqual(allResults.count, allTests.count)
    }
    
    private func bucketQueue(workerIds: [String], numberOfRetries: Int) -> BucketQueue {
        let tracker = WorkerAlivenessTrackerFixtures.alivenessTrackerWithAlwaysAliveResults()
        workerIds.forEach(tracker.didRegisterWorker)

        let bucketQueue = BucketQueueFixtures.bucketQueue(
            workerAlivenessProvider: tracker,
            testHistoryTracker: TestHistoryTrackerFixtures.testHistoryTracker(
                numberOfRetries: 2
            )
        )

        return bucketQueue
    }
    
    private func assertNoThrow(file: StaticString = #file, line: UInt = #line, body: () throws -> ()) {
        do {
            try body()
        } catch let e {
            XCTFail("Unexpectidly caught \(e)", file: file, line: line)
        }
    }
}

// Limits allows to guarantee finishing test in reasonable time
private let maxRetries = 3
private let maxWorkers = 100
private let maxBuckets = 1500
private let minTests = 1
private let maxTests = 3
private let maxFails = 100

private final class Worker {
    let workerId: String
    var thread: Thread?
    var fails = 0
    var results = [TestEntryResult]()
    
    init(id: String) {
        self.workerId = id
    }
    
    func startThread(bucketQueue: BucketQueue, dispatchGroup: DispatchGroup) {
        dispatchGroup.enter()
        let thread = Thread { [weak self] in
            do {
                try self?.main(bucketQueue: bucketQueue)
            } catch {
                // do nothing
            }
            dispatchGroup.leave()
        }
        thread.start()
        self.thread = thread
    }
    
    func main(bucketQueue: BucketQueue) throws {
        let arbitraryLargeNumber = 100
        let maxIterations = maxBuckets * (maxRetries + 1) * arbitraryLargeNumber
        
        for iteration in 0..<maxIterations {
            let dequeueResult = bucketQueue.dequeueBucket(
                requestId: "\(workerId)_iteration_\(iteration)",
                workerId: workerId
            )
            
            switch dequeueResult {
            case .queueIsEmpty, .workerBlocked:
                return
            case .nothingToDequeueAtTheMoment:
                Thread.sleep(forTimeInterval: 0.001)
            case .dequeuedBucket(let dequeuedBucket):
                try handleBucket(dequeuedBucket: dequeuedBucket, bucketQueue: bucketQueue)
            }
        }
    }
    
    private func handleBucket(dequeuedBucket: DequeuedBucket, bucketQueue: BucketQueue) throws {
        let acceptResult = try bucketQueue.accept(
            testingResult: TestingResult(
                bucketId: dequeuedBucket.bucket.bucketId,
                testDestination: dequeuedBucket.bucket.testDestination,
                unfilteredResults: fakeOutTestingResults(bucket: dequeuedBucket.bucket)
            ),
            requestId: dequeuedBucket.requestId,
            workerId: dequeuedBucket.workerId
        )
        results.append(contentsOf: acceptResult.testingResultToCollect.unfilteredResults)
    }
    
    private func fakeOutTestingResults(bucket: Bucket) -> [TestEntryResult] {
        return bucket.testEntries.map { testEntry in
            let success: Bool
            
            switch arc4random() % 5 {
            case 0:
                return TestEntryResult.lost(testEntry: testEntry)
            case 1:
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
}
