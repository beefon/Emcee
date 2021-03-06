import BucketQueue
import Foundation
import Models

/// Allows to override dequeue result when no dequeueable buckets available.
public protocol NothingToDequeueBehavior {
    func dequeueResultWhenNoBucketsToDequeueAvaiable(dequeueResults: [DequeueResult]) -> DequeueResult
}

/// This behavior will not let workers quit, making them check for new jobs again and again.
public final class NothingToDequeueBehaviorCheckLater: NothingToDequeueBehavior {
    private let checkAfter: TimeInterval

    public init(checkAfter: TimeInterval) {
        self.checkAfter = checkAfter
    }
    
    public func dequeueResultWhenNoBucketsToDequeueAvaiable(dequeueResults: [DequeueResult]) -> DequeueResult {
        return .checkAgainLater(checkAfter: checkAfter)
    }
}

/// This behavior will let workers quit after all jobs will have their queues in depleted state.
public final class NothingToDequeueBehaviorWaitForAllQueuesToDeplete: NothingToDequeueBehavior {
    private let checkAfter: TimeInterval
    
    public init(checkAfter: TimeInterval) {
        self.checkAfter = checkAfter
    }
    
    public func dequeueResultWhenNoBucketsToDequeueAvaiable(dequeueResults: [DequeueResult]) -> DequeueResult {
        let uniqueDequeueResults = Set<DequeueResult>(dequeueResults)
        
        if uniqueDequeueResults.count == 1, let singleResult = uniqueDequeueResults.first {
            return singleResult
        }
        
        return .checkAgainLater(checkAfter: checkAfter)
    }
}
