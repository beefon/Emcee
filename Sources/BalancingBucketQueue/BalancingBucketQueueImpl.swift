import Basic
import BucketQueue
import Dispatch
import Foundation
import Models
import ResultsCollector

final class BalancingBucketQueueImpl: BalancingBucketQueue {
    private let syncQueue = DispatchQueue(label: "ru.avito.emcee.BalancingBucketQueueImpl.syncQueue")
    private var bucketQueues: SortedArray<JobQueue>
    private let bucketQueueFactory: BucketQueueFactory
    private let nothingToDequeueBehavior: NothingToDequeueBehavior
    
    public init(
        bucketQueueFactory: BucketQueueFactory,
        nothingToDequeueBehavior: NothingToDequeueBehavior)
    {
        self.bucketQueues = BalancingBucketQueueImpl.createQueues(contents: [])
        self.bucketQueueFactory = bucketQueueFactory
        self.nothingToDequeueBehavior = nothingToDequeueBehavior
    }
    
    private static func createQueues(contents: [JobQueue]) -> SortedArray<JobQueue> {
        return SortedArray(contents) { $0 < $1 }
    }
    
    func delete(jobId: JobId) {
        return syncQueue.sync {
            let newContents = bucketQueues.values.filter { $0.jobId != jobId }
            bucketQueues = BalancingBucketQueueImpl.createQueues(contents: newContents)
        }
    }
    
    func state(jobId: JobId) throws -> BucketQueueState {
        return try syncQueue.sync {
            guard let existingEntry = entry__onSyncQueue(jobId: jobId) else {
                throw BalancingBucketQueueError.noQueue(jobId: jobId)
            }
            return existingEntry.bucketQueue.state
        }
    }
    
    func results(jobId: JobId) throws -> [TestingResult] {
        return try syncQueue.sync {
            guard let existingEntry = entry__onSyncQueue(jobId: jobId) else {
                throw BalancingBucketQueueError.noQueue(jobId: jobId)
            }
            return existingEntry.resultsCollector.collectedResults
        }
    }
    
    func enqueue(buckets: [Bucket], jobId: JobId) {
        syncQueue.sync {
            let bucketQueue: BucketQueue
            if let existingEntry = entry__onSyncQueue(jobId: jobId) {
                bucketQueue = existingEntry.bucketQueue
            } else {
                bucketQueue = bucketQueueFactory.createBucketQueue()
                add_onSyncQueue(bucketQueue: bucketQueue, jobId: jobId)
            }
            bucketQueue.enqueue(buckets: buckets)
        }
    }
    
    func previouslyDequeuedBucket(requestId: String, workerId: String) -> DequeuedBucket? {
        return syncQueue.sync {
            let bucketQueues = bucketQueues_onSyncQueue()
            
            return bucketQueues
                .compactMap({ $0.previouslyDequeuedBucket(requestId: requestId, workerId: workerId) })
                .first
        }
    }
    
    func dequeueBucket(requestId: String, workerId: String) -> DequeueResult {
        return syncQueue.sync {
            let bucketQueues = bucketQueues_onSyncQueue()
            
            if let previouslyDequeuedBucket = bucketQueues
                .compactMap({ $0.previouslyDequeuedBucket(requestId: requestId, workerId: workerId) })
                .first {
                return .dequeuedBucket(previouslyDequeuedBucket)
            }
            
            var dequeueResults = [DequeueResult]()
            for queue in bucketQueues {
                let dequeueResult = queue.dequeueBucket(requestId: requestId, workerId: workerId)
                switch dequeueResult {
                case .dequeuedBucket:
                    return dequeueResult
                case .queueIsEmpty, .checkAgainLater, .workerBlocked:
                    dequeueResults.append(dequeueResult)
                }
            }
            
            return nothingToDequeueBehavior.dequeueResultWhenNoBucketsToDequeueAvaiable(dequeueResults: dequeueResults)
        }
    }
    
    func accept(testingResult: TestingResult, requestId: String, workerId: String) throws -> BucketQueueAcceptResult {
        return try syncQueue.sync {
            if let appropriateEntry: JobQueue = bucketQueues
                .filter({ $0.bucketQueue.previouslyDequeuedBucket(requestId: requestId, workerId: workerId) != nil })
                .first {
                let result = try appropriateEntry.bucketQueue.accept(
                    testingResult: testingResult,
                    requestId: requestId,
                    workerId: workerId
                )
                appropriateEntry.resultsCollector.append(testingResult: result.testingResultToCollect)
                return result
            }
            
            throw BalancingBucketQueueError.noMatchingQueueFound(
                testingResult: testingResult,
                requestId: requestId,
                workerId: workerId
            )
        }
    }
    
    func reenqueueStuckBuckets() -> [StuckBucket] {
        return syncQueue.sync {
            bucketQueues_onSyncQueue().flatMap { $0.reenqueueStuckBuckets() }
        }
    }
    
    var state: BucketQueueState {
        return syncQueue.sync {
            let states = bucketQueues_onSyncQueue().map { $0.state }
            return BucketQueueState(
                enqueuedBucketCount: states.map { $0.enqueuedBucketCount }.reduce(0, +),
                dequeuedBucketCount: states.map { $0.dequeuedBucketCount }.reduce(0, +)
            )
        }
    }
    
    private func entry__onSyncQueue(jobId: JobId) -> JobQueue? {
        return bucketQueues.first(where: { entry -> Bool in entry.jobId == jobId })
    }
    
    private func add_onSyncQueue(bucketQueue: BucketQueue, jobId: JobId) {
        bucketQueues.insert(
            JobQueue(
                jobId: jobId,
                creationTime: Date(),
                bucketQueue: bucketQueue,
                resultsCollector: ResultsCollector()
            )
        )
    }
    
    private func bucketQueues_onSyncQueue() -> [BucketQueue] {
        return bucketQueues.map { $0.bucketQueue }
    }
}
