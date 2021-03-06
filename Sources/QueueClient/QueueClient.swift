import Dispatch
import Foundation
import Logging
import Models
import RESTMethods

public final class QueueClient {
    public weak var delegate: QueueClientDelegate?
    private let serverAddress: String
    private let serverPort: Int
    private let workerId: String
    private let urlSession = URLSession(configuration: URLSessionConfiguration.default)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var isClosed = false
    
    public init(serverAddress: String, serverPort: Int, workerId: String) {
        self.serverAddress = serverAddress
        self.serverPort = serverPort
        self.workerId = workerId
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    }
    
    deinit {
        close()
    }
    
    public func registerWithServer() throws {
        try sendRequest(
            .registerWorker,
            payload: RegisterWorkerRequest(workerId: workerId),
            completionHandler: handleRegisterWorkerResponse
        )
    }
    
    public func close() {
        log("Invalidating queue client URL session")
        urlSession.finishTasksAndInvalidate()
        isClosed = true
    }
    
    /// Request id is a unique request identifier that could be used to retry bucket fetch in case if
    /// request has failed. Server is expected to return the same bucket if request id + worker id pair
    /// match for sequential requests.
    /// Apple's guide on handling Handling "The network connection was lost" errors:
    /// https://developer.apple.com/library/archive/qa/qa1941/_index.html
    public func fetchBucket(requestId: String) throws {
        try sendRequest(
            .getBucket,
            payload: DequeueBucketRequest(
                workerId: workerId,
                requestId: requestId
            ),
            completionHandler: handleFetchBucketResponse
        )
    }
    
    public func send(testingResult: TestingResult, requestId: String) throws {
        try sendRequest(
            .bucketResult,
            payload: PushBucketResultRequest(
                workerId: workerId,
                requestId: requestId,
                testingResult: testingResult
            ),
            completionHandler: handleSendBucketResultResponse
        )
    }
    
    public func reportAlive(bucketIdsBeingProcessedProvider: () -> (Set<String>)) throws {
        try sendRequest(
            .reportAlive,
            payload: ReportAliveRequest(
                workerId: workerId,
                bucketIdsBeingProcessed: bucketIdsBeingProcessedProvider()
            ),
            completionHandler: handleAlivenessResponse
        )
    }
    
    public func fetchQueueServerVersion() throws {
        try sendRequest(
            .queueVersion,
            payload: QueueVersionRequest(),
            completionHandler: handleQueueServerVersion
        )
    }
    
    // MARK: - Request Generation
    
    private func sendRequest<Payload, Response>(
        _ restMethod: RESTMethod,
        payload: Payload,
        completionHandler: @escaping (Response) throws -> ())
        throws where Payload : Encodable, Response : Decodable
    {
        guard !isClosed else { throw QueueClientError.queueClientIsClosed(restMethod) }
        
        let jsonData = try encoder.encode(payload)
        if let stringJson = String(data: jsonData, encoding: .utf8) {
            log("Sending request to \(restMethod.withPrependingSlash): \(stringJson)")
        } else {
            log("Sending request to \(restMethod.withPrependingSlash): unable to get string for json data \(jsonData.count) bytes")
        }
        var urlRequest = URLRequest(url: url(restMethod), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: .infinity)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("Content-Type", forHTTPHeaderField: "application/json")
        urlRequest.httpBody = jsonData
        let dataTask = urlSession.dataTask(with: urlRequest) { [weak self] (data: Data?, response: URLResponse?, error: Error?) in
            guard let strongSelf = self else { return }
            
            if let error = error {
                strongSelf.delegate?.queueClient(strongSelf, didFailWithError: QueueClientError.communicationError(error)); return
            }
            guard let data = data else {
                strongSelf.delegate?.queueClient(strongSelf, didFailWithError: QueueClientError.noData); return
            }
            do {
                try completionHandler(try strongSelf.decoder.decode(Response.self, from: data))
            } catch {
                strongSelf.delegate?.queueClient(strongSelf, didFailWithError: QueueClientError.parseError(error, data)); return
            }
        }
        dataTask.resume()
    }
    
    private func url(_ method: RESTMethod) -> URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = serverAddress
        components.port = serverPort
        components.path = RESTMethod.getBucket.withPrependingSlash
        components.path = method.withPrependingSlash
        guard let url = components.url else {
            let error = "Unable to convert components to url: \(components)"
            log(error, color: .red)
            fatalError(error)
        }
        return url
    }
    
    // MARK: - Response Handlers
    
    private func handleRegisterWorkerResponse(response: RegisterWorkerResponse) {
        switch response {
        case .workerRegisterSuccess(let workerConfiguration):
            delegate?.queueClient(self, didReceiveWorkerConfiguration: workerConfiguration)
        }
    }
    
    private func handleFetchBucketResponse(response: DequeueBucketResponse) {
        switch response {
        case .bucketDequeued(let bucket):
            delegate?.queueClient(self, didFetchBucket: bucket)
        case .checkAgainLater(let checkAfter):
            delegate?.queueClient(self, fetchBucketLaterAfter: checkAfter)
        case .queueIsEmpty:
            delegate?.queueClientQueueIsEmpty(self)
        case .workerBlocked:
            delegate?.queueClientWorkerHasBeenBlocked(self)
        }
    }
    
    private func handleSendBucketResultResponse(response: BucketResultAcceptResponse) {
        switch response {
        case .bucketResultAccepted(let bucketId):
            delegate?.queueClient(self, serverDidAcceptBucketResult: bucketId)
        }
    }
    
    private func handleAlivenessResponse(response: ReportAliveResponse) {
        switch response {
        case .aliveReportAccepted:
            delegate?.queueClientWorkerHasBeenIndicatedAsAlive(self)
        }
    }
    
    private func handleQueueServerVersion(response: QueueVersionResponse) {
        switch response {
        case .queueVersion(let version):
            delegate?.queueClient(self, didFetchQueueServerVersion: version)
        }
    }
}
