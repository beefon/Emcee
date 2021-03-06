import Basic
import Foundation
import Models

public final class Shimulator: Simulator {
    public static func shimulator(testDestination: TestDestination) -> Shimulator {
        return Shimulator(
            index: 0,
            testDestination: testDestination,
            workingDirectory: AbsolutePath(ProcessInfo.processInfo.executablePath.deletingLastPathComponent))
    }
}
