import Foundation

public enum StdinError: Error, CustomStringConvertible {
    case processIsNotRunning(ProcessController)
    case didNotConsumeStdinInTime(ProcessController)
    
    public var processController: ProcessController {
        switch self {
        case .processIsNotRunning(let controller):
            return controller
        case .didNotConsumeStdinInTime(let controller):
            return controller
        }
    }
    
    public var description: String {
        switch self {
        case .processIsNotRunning(let controller):
            return "\(controller) error: Cannot write to stdin because process is not running"
        case .didNotConsumeStdinInTime(let controller):
            return "\(controller) error: did not consime stdin in time"
        }
    }
}
