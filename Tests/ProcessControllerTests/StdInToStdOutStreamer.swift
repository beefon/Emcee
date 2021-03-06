import Foundation

class StdInToStdOutStreamer {
    public init() {}
    
    public func run() {
        write(string: "stdin-to-stdout-streamer started!", file: stdout)
        
        FileHandle.standardInput.readabilityHandler = { handler in
            let stdinData = handler.availableData
            if stdinData.isEmpty {
                FileHandle.standardInput.readabilityHandler = nil
            } else {
                guard let string = String(data: stdinData, encoding: .utf8) else { return }
                guard let outputData = string.data(using: .utf8) else { return }
                write(data: outputData, file: stdout)
                if string.contains("bye") {
                    FileHandle.standardInput.readabilityHandler = nil
                }
            }
        }
        
        while FileHandle.standardInput.readabilityHandler != nil {
           sleep(1)
        }
    }
}

func write(string: String, file: UnsafeMutablePointer<FILE>) {
    guard let data = string.data(using: .utf8) else { return }
    write(data: data, file: file)
}

func write(data: Data, file: UnsafeMutablePointer<FILE>) {
    data.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
        fwrite(bytes, 1, data.count, file)
        fflush(file)
    }
}

// Swift does not allow to have a top level code statements unless the file is named main.swift.
// We use this file as a simple program that we invoke via `swift StdInToStdOutStreamer.swift` right from unit test
// To make top level code work, we copy this file and uncomment the line below, and then we invoke this code
// by calling `swift`.

//uncomment_from_tests StdInToStdOutStreamer().run()
