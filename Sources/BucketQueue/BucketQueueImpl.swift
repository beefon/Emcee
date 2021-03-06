import Dispatch
import Foundation
import Logging
import Models
import WorkerAlivenessTracker

final class BucketQueueImpl: BucketQueue {
    private var enqueuedBuckets = [Bucket]()
    private var dequeuedBuckets = Set<DequeuedBucket>()
    private let testHistoryTracker: TestHistoryTracker
    private let queue = DispatchQueue(label: "ru.avito.emcee.BucketQueue.queue")
    private let workerAlivenessProvider: WorkerAlivenessProvider
    private let checkAgainTimeInterval: TimeInterval
    
    public init(
        workerAlivenessProvider: WorkerAlivenessProvider,
        testHistoryTracker: TestHistoryTracker,
        checkAgainTimeInterval: TimeInterval)
    {
        self.workerAlivenessProvider = workerAlivenessProvider
        self.testHistoryTracker = testHistoryTracker
        self.checkAgainTimeInterval = checkAgainTimeInterval
    }
    
    public func enqueue(buckets: [Bucket]) {
        queue.sync {
            self.enqueue_onSyncQueue(buckets: buckets)
        }
    }
    
    public var state: BucketQueueState {
        return queue.sync {
            return state_onSyncQueue
        }
    }
    
    private var state_onSyncQueue: BucketQueueState {
        return BucketQueueState(enqueuedBucketCount: enqueuedBuckets.count, dequeuedBucketCount: dequeuedBuckets.count)
    }
    
    func previouslyDequeuedBucket(requestId: String, workerId: String) -> DequeuedBucket? {
        return queue.sync {
            previouslyDequeuedBucket_onSyncQueue(requestId: requestId, workerId: workerId)
        }
    }
    
    public func dequeueBucket(requestId: String, workerId: String) -> DequeueResult {
        let workerAliveness = workerAlivenessProvider.workerAliveness
        
        if workerAliveness[workerId]?.status != .alive {
            return .workerBlocked
        }
        
        return queue.sync {
            // There might me problems with connection between workers and queue and connection may be lost.
            // If same worker tries to perform same request again, return same result.
            if let previouslyDequeuedBucket = previouslyDequeuedBucket_onSyncQueue(requestId: requestId, workerId: workerId) {
                log("Provided previously dequeued bucket: \(previouslyDequeuedBucket)")
                return .dequeuedBucket(previouslyDequeuedBucket)
            }
            
            if state_onSyncQueue.isDepleted {
                return .queueIsEmpty
            }
            if state_onSyncQueue.enqueuedBucketCount == 0 {
                return .checkAgainLater(checkAfter: checkAgainTimeInterval)
            }
            
            let bucketToDequeueOrNil = testHistoryTracker.bucketToDequeue(
                workerId: workerId,
                queue: enqueuedBuckets,
                aliveWorkers: workerAliveness
                    .filter { $0.value.status == .alive }
                    .map { $0.key }
            )
            
            if let bucket = bucketToDequeueOrNil {
                return .dequeuedBucket(
                    dequeue_onSyncQueue(
                        bucket: bucket,
                        requestId: requestId,
                        workerId: workerId
                    )
                )
            } else {
                return .checkAgainLater(checkAfter: checkAgainTimeInterval)
            }
        }
    }
    
    public func accept(
        testingResult: TestingResult,
        requestId: String,
        workerId: String)
        throws
        -> BucketQueueAcceptResult
    {
        return try queue.sync {
            log("Validating result from \(workerId) \(requestId): \(testingResult)")
            
            guard let dequeuedBucket = previouslyDequeuedBucket_onSyncQueue(requestId: requestId, workerId: workerId) else {
                log("Validation failed: no dequeued bucket for request \(requestId) worker \(workerId)")
                throw ResultAcceptanceError.noDequeuedBucket(requestId: requestId, workerId: workerId)
            }
            
            let actualTestEntries = Set(testingResult.unfilteredResults.map { $0.testEntry })
            let expectedTestEntries = Set(dequeuedBucket.bucket.testEntries)
            reenqueueLostResults_onSyncQueue(
                expectedTestEntries: expectedTestEntries,
                actualTestEntries: actualTestEntries,
                bucket: dequeuedBucket.bucket,
                workerId: workerId,
                requestId: requestId
            )
            
            let acceptResult = testHistoryTracker.accept(
                testingResult: testingResult,
                bucket: dequeuedBucket.bucket,
                workerId: workerId
            )
            enqueue_onSyncQueue(buckets: acceptResult.bucketsToReenqueue)
            
            dequeuedBuckets.remove(dequeuedBucket)
            log("Accepted result for bucket '\(testingResult.bucketId)' from '\(workerId)', updated dequeued buckets: \(dequeuedBuckets.count): \(dequeuedBuckets)")
            
            return BucketQueueAcceptResult(
                testingResultToCollect: acceptResult.testingResult
            )
        }
    }
    
    /// Removes and returns any buckets that appear to be stuck, providing a reason why queue thinks bucket is stuck.
    public func reenqueueStuckBuckets() -> [StuckBucket] {
        let workerAliveness = workerAlivenessProvider.workerAliveness
        
        return queue.sync {
            let allDequeuedBuckets = dequeuedBuckets
            let stuckBuckets: [StuckBucket] = allDequeuedBuckets.compactMap { dequeuedBucket in
                let aliveness = workerAliveness[dequeuedBucket.workerId] ?? WorkerAliveness(status: .notRegistered, bucketIdsBeingProcessed: [])
                let stuckReason: StuckBucket.Reason
                switch aliveness.status {
                case .notRegistered:
                    fatalLogAndError("Logic error: worker '\(dequeuedBucket.workerId)' is not registered, but stuck bucket has worker id of this worker. This is not expected, as we shouldn't dequeue bucket using non-registered worker.")
                case .alive:
                    if aliveness.bucketIdsBeingProcessed.contains(dequeuedBucket.bucket.bucketId) {
                       return nil
                    }
                    stuckReason = .bucketLost
                case .blocked:
                    stuckReason = .workerIsBlocked
                case .silent:
                    stuckReason = .workerIsSilent
                }
                dequeuedBuckets.remove(dequeuedBucket)
                return StuckBucket(
                    reason: stuckReason,
                    bucket: dequeuedBucket.bucket,
                    workerId: dequeuedBucket.workerId,
                    requestId: dequeuedBucket.requestId
                )
            }
            
            // Every stucked test produces a single bucket with itself
            let buckets = stuckBuckets.flatMap { stuckBucket in
                stuckBucket.bucket.testEntries.map { testEntry in
                    Bucket(
                        testEntries: [testEntry],
                        buildArtifacts: stuckBucket.bucket.buildArtifacts,
                        environment: stuckBucket.bucket.environment,
                        simulatorSettings: stuckBucket.bucket.simulatorSettings,
                        testDestination: stuckBucket.bucket.testDestination,
                        toolResources: stuckBucket.bucket.toolResources
                    )
                }
            }
            
            if !buckets.isEmpty {
                log("Got \(stuckBuckets.count) stuck buckets, reenqueueing them as \(buckets.count) buckets:")
                for bucket in buckets {
                    log("-- \(bucket)")
                }
                
                enqueue_onSyncQueue(buckets: buckets)
            }
            
            return stuckBuckets
        }
    }
    
    private func enqueue_onSyncQueue(buckets: [Bucket]) {
        // For empty queue it just inserts buckets to the beginning,
        //
        // There is an optimization to insert additional (probably failed) buckets:
        //
        // If we insert new buckets to the end of the queue we will end up in a situation when
        // there will be a tail of failing tests at the end of the queue.
        //
        // If we insert it in at the beginning there will be a little delay between retries,
        // and, for example, some temporarily unavalable service in E2E won't stop failing yet.
        //
        // The ideal solution is to optimize the inserting position based on current queue,
        // current number of retries etc. For example, spread retires evenly throughout whole run.
        //
        // This is not optimal:
        //
        let positionJustAfterNextBucket = 1
        
        let positionLimit = self.enqueuedBuckets.count
        let positionToInsert = min(positionJustAfterNextBucket, positionLimit)
        self.enqueuedBuckets.insert(contentsOf: buckets, at: positionToInsert)
    }
    
    private func dequeue_onSyncQueue(bucket: Bucket, requestId: String, workerId: String) -> DequeuedBucket {
        let dequeuedBucket = DequeuedBucket(bucket: bucket, workerId: workerId, requestId: requestId)
        
        enqueuedBuckets.removeAll(where: { $0 == bucket })
        _ = dequeuedBuckets.insert(dequeuedBucket)
        
        log("Dequeued new bucket: \(dequeuedBucket). Now there are \(dequeuedBuckets.count) dequeued buckets.")
        
        return dequeuedBucket
    }
    
    private func previouslyDequeuedBucket_onSyncQueue(requestId: String, workerId: String) -> DequeuedBucket? {
        return dequeuedBuckets.first { $0.requestId == requestId && $0.workerId == workerId }
    }
    
    private func reenqueueLostResults_onSyncQueue(
        expectedTestEntries: Set<TestEntry>,
        actualTestEntries: Set<TestEntry>,
        bucket: Bucket,
        workerId: String,
        requestId: String)
    {
        let lostTestEntries = expectedTestEntries.subtracting(actualTestEntries)
        if !lostTestEntries.isEmpty {
            log("Test result from \(workerId) (request \(requestId)) contains lost test entries: \(lostTestEntries)")
            let lostResult = testHistoryTracker.accept(
                testingResult: TestingResult(
                    bucketId: bucket.bucketId,
                    testDestination: bucket.testDestination,
                    unfilteredResults: lostTestEntries.map { TestEntryResult.lost(testEntry: $0) }),
                bucket: bucket,
                workerId: workerId
            )
            enqueue_onSyncQueue(buckets: lostResult.bucketsToReenqueue)
        }
    }
}
