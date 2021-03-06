import Foundation
import Swifter
import Logging

public final class QueueServerRequestParser {
    private let decoder: JSONDecoder
    
    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }
    
    public func parse<T, R>(
        request: HttpRequest,
        responseProducer: (T) throws -> (R))
        -> HttpResponse
        where T: Decodable, R: Encodable
    {
        let requestData = Data(bytes: request.body)
        do {
            let object: T = try decoder.decode(T.self, from: requestData)
            return .json(response: try responseProducer(object))
        } catch {
            log("Failed to process \(request.path) data: \(error). Will return server error response.")
            return .internalServerError
        }
    }
}
