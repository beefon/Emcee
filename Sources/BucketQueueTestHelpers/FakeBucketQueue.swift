import BucketQueue
import Foundation
import Models

public class FakeBucketQueue: BucketQueue {
    
    public struct AcceptanceError: Error {}
    
    public var enqueuedBuckets = [Bucket]()
    public let throwsOnAccept: Bool
    public let fixedStuckBuckets: [StuckBucket]
    public let fixedDequeueResult: DequeueResult
    public var fixedPreviouslyDequeuedBucket: DequeuedBucket?
    
    public init(
        throwsOnAccept: Bool = false,
        fixedStuckBuckets: [StuckBucket] = [],
        fixedDequeueResult: DequeueResult = .workerBlocked)
    {
        self.throwsOnAccept = throwsOnAccept
        self.fixedStuckBuckets = fixedStuckBuckets
        self.fixedDequeueResult = fixedDequeueResult
    }
    
    public var state: BucketQueueState {
        return BucketQueueState(enqueuedBucketCount: 0, dequeuedBucketCount: 0)
    }
    
    public func enqueue(buckets: [Bucket]) {
        enqueuedBuckets.append(contentsOf: buckets)
    }
    
    public func previouslyDequeuedBucket(requestId: String, workerId: String) -> DequeuedBucket? {
        return fixedPreviouslyDequeuedBucket
    }
    
    public func dequeueBucket(requestId: String, workerId: String) -> DequeueResult {
        return fixedDequeueResult
    }
    
    public func accept(testingResult: TestingResult, requestId: String, workerId: String) throws -> BucketQueueAcceptResult {
        if throwsOnAccept {
            throw AcceptanceError()
        } else {
            return BucketQueueAcceptResult(testingResultToCollect: testingResult)
        }
    }
    
    public func reenqueueStuckBuckets() -> [StuckBucket] {
        return fixedStuckBuckets
    }
}
