// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "AvitoUITestRunner",
    products: [
        .executable(name: "AvitoRunner", targets: ["AvitoRunner"]),
        .library(name: "EmceePlugin", targets: [
            "Models",
            "Logging",
            "Plugin"
            ]),
        .executable(name: "fake_fbxctest", targets: ["FakeFbxctest"]),
        .executable(name: "testing_plugin", targets: ["TestingPlugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-package-manager.git", .exact("0.3.0")),
        .package(url: "https://github.com/beefon/Shout", .branch("master")),
        .package(url: "https://github.com/daltoniam/Starscream.git", .exact("3.0.6")),
        .package(url: "https://github.com/httpswift/swifter.git", .branch("stable")),
        .package(url: "https://github.com/weichsel/ZIPFoundation/", from: "0.9.6"),
    ],
    targets: [
        .target(name: "Ansi", dependencies: []),
        
        .target(
            name: "ArgumentsParser",
            dependencies: [
                "Extensions",
                "Logging",
                "Models",
                "RuntimeDump",
                "Utility"
            ]),
        
        .target(
            name: "AvitoRunner",
            dependencies: [
                "ArgumentsParser",
                "ChromeTracing",
                "Deployer",
                "DistRun",
                "DistWork",
                "EventBus",
                "JunitReporting",
                "LaunchdUtils",
                "Models",
                "PluginManager",
                "ProcessController",
                "ResourceLocationResolver",
                "SSHDeployer",
                "ScheduleStrategy",
                "Scheduler"
            ]),
        .testTarget(
            name: "AvitoRunnerTests",
            dependencies: [
                "Extensions",
                "SimulatorPool"
            ]),
        
        .target(
            name: "BucketQueue",
            dependencies: [
                "Logging",
                "Models",
                "WorkerAlivenessTracker"
            ]),
        .testTarget(
            name: "BucketQueueTests",
            dependencies: [
                "BucketQueue",
                "ModelsTestHelpers",
                "WorkerAlivenessTrackerTestHelpers"
            ]),
        
        .target(
            name: "ChromeTracing",
            dependencies: [
                "Models"
            ]),
        
        .target(
            name: "Deployer",
            dependencies: [
                "Extensions",
                "Logging",
                "Utility",
                "ZIPFoundation",
            ]),
        .testTarget(
            name: "DeployerTests",
            dependencies: [
                "Deployer"
            ]),
        
        .target(
            name: "DistRun",
            dependencies: [
                "BucketQueue",
                "Deployer",
                "EventBus",
                "Extensions",
                "HostDeterminer",
                "LaunchdUtils",
                "Logging",
                "Models",
                "PluginManager",
                "RESTMethods",
                "RuntimeDump",
                "ScheduleStrategy",
                "SSHDeployer",
                "Swifter",
                "SynchronousWaiter",
                "TempFolder",
                "Timer",
                "Utility",
                "WorkerAlivenessTracker"
            ]),
        .testTarget(
            name: "DistRunTests",
            dependencies: [
                "BucketQueue",
                "Deployer",
                "DistRun",
                "DistWork",
                "Models",
                "ModelsTestHelpers",
                "ResourceLocationResolver",
                "TempFolder",
                "WorkerAlivenessTracker",
                "WorkerAlivenessTrackerTestHelpers"
            ]),
        
        .target(
            name: "DistWork",
            dependencies: [
                "EventBus",
                "Extensions",
                "Logging",
                "Models",
                "PluginManager",
                "ResourceLocationResolver",
                "RESTMethods",
                "Scheduler",
                "SimulatorPool",
                "SynchronousWaiter",
                "Timer",
                "Utility"
            ]),
        .testTarget(
            name: "DistWorkTests",
            dependencies: [
                "DistWork",
                "Models",
                "ModelsTestHelpers",
                "RESTMethods",
                "Swifter",
                "SynchronousWaiter"
            ]),
        
        .target(
            name: "EventBus",
            dependencies: [
                "Models",
                ]),
        .testTarget(
            name: "EventBusTests",
            dependencies: [
                "EventBus",
                "ModelsTestHelpers",
                "SynchronousWaiter"
            ]),
        
        .target(
            name: "Extensions",
            dependencies: []),
        .testTarget(
            name: "ExtensionsTests",
            dependencies: [
                "Extensions",
                "Utility"
            ]),
        
        .target(
            name: "FakeFbxctest",
            dependencies: [
                "Extensions",
                "Logging",
                "TestingFakeFbxctest"
            ]
        ),
        .target(
            name: "fbxctest",
            dependencies: [
                "Ansi",
                "JSONStream",
                "HostDeterminer",
                "Logging",
                "ProcessController",
                "Timer",
                "Utility"
            ]),
        
        .target(
            name: "FileCache",
            dependencies: [
                "Extensions",
                "Utility"
            ]),
        .testTarget(
            name: "FileCacheTests",
            dependencies: [
                "FileCache"
            ]),
        
        .target(
            name: "HostDeterminer",
            dependencies: [
                "Logging"
            ]),
        
        .target(
            name: "JSONStream",
            dependencies: []),
        .testTarget(
            name: "JSONStreamTests",
            dependencies: [
                "Utility",
                "JSONStream"
            ]),
        
        .target(
            name: "JunitReporting",
            dependencies: []),
        .testTarget(
            name: "JunitReportingTests",
            dependencies: [
                "Extensions",
                "JunitReporting"
            ]),
        
        .target(
            name: "LaunchdUtils",
            dependencies: []),
        .testTarget(
            name: "LaunchdUtilsTests",
            dependencies: [
                "LaunchdUtils"
            ]),
        
        .target(
            name: "ListeningSemaphore",
            dependencies: [
            ]),
        .testTarget(
            name: "ListeningSemaphoreTests",
            dependencies: [
                "ListeningSemaphore"
            ]),
        
        .target(
            name: "Logging",
            dependencies: [
                "Ansi"
            ]),
        
        .target(
            name: "Models",
            dependencies: [
                "Extensions"
            ]),
        .target(
            name: "ModelsTestHelpers",
            dependencies: [
                "Models"
            ]),
        .testTarget(
            name: "ModelsTests",
            dependencies: [
                "Models",
                "ModelsTestHelpers"
            ]),
        
        .target(
            name: "Plugin",
            dependencies: [
                "EventBus",
                "JSONStream",
                "Logging",
                "Models",
                "Starscream",
                "SynchronousWaiter",
                "Utility"
            ]),
        
        .target(
            name: "PluginManager",
            dependencies: [
                "EventBus",
                "Logging",
                "HostDeterminer",
                "ResourceLocationResolver",
                "Models",
                "ProcessController",
                "Scheduler",
                "Swifter",
                "SynchronousWaiter"
            ]),
        .testTarget(
            name: "PluginManagerTests",
            dependencies: [
                "PluginManager",
                "ResourceLocationResolver",
                "Utility"
            ]),
        
        .target(
            name: "ProcessController",
            dependencies: [
                "Extensions",
                "Logging",
                "ResourceLocationResolver",
                "Timer",
                "Utility"
            ]),
        .testTarget(
            name: "ProcessControllerTests",
            dependencies: [
                "Extensions",
                "ProcessController",
                "Utility"
            ]),
        
        .target(
            name: "ResourceLocationResolver",
            dependencies: [
                "Extensions",
                "FileCache",
                "Models",
                "URLResource"
            ]),
        
        .target(
            name: "RESTMethods",
            dependencies: [
                "Models"
            ]),
        
        .target(
            name: "Runner",
            dependencies: [
                "fbxctest",
                "HostDeterminer",
                "Logging",
                "Models",
                "SimulatorPool",
                "TempFolder"
            ]),
        .testTarget(
            name: "RunnerTests",
            dependencies: [
                "Extensions",
                "Models",
                "ModelsTestHelpers",
                "ResourceLocationResolver",
                "Runner",
                "ScheduleStrategy",
                "SimulatorPool",
                "TestingFakeFbxctest",
                "TempFolder"
            ]
        ),
        
        .target(
            name: "RuntimeDump",
            dependencies: [
                "EventBus",
                "Models",
                "Runner",
                "TempFolder"
            ]),
        
        .target(
            name: "Scheduler",
            dependencies: [
                "EventBus",
                "ListeningSemaphore",
                "Logging",
                "Models",
                "Runner",
                "RuntimeDump",
                "ScheduleStrategy",
                "SimulatorPool",
                "TempFolder"
            ]),
        
        .target(
            name: "ScheduleStrategy",
            dependencies: [
                "Extensions",
                "Logging",
                "Models"
            ]),
        .testTarget(
            name: "ScheduleStrategyTests",
            dependencies: [
                "Models",
                "ModelsTestHelpers",
                "ScheduleStrategy"
            ]),
        
        .target(
            name: "SimulatorPool",
            dependencies: [
                "Extensions",
                "fbxctest",
                "Logging",
                "Models",
                "ProcessController",
                "TempFolder",
                "Utility"
            ]),
        .testTarget(
            name: "SimulatorPoolTests",
            dependencies: [
                "Models",
                "ModelsTestHelpers",
                "ResourceLocationResolver",
                "SimulatorPool",
                "SynchronousWaiter",
                "TempFolder"
            ]),
        
        .target(
            name: "SSHDeployer",
            dependencies: [
                "Ansi",
                "Extensions",
                "Logging",
                "Models",
                "Utility",
                "Deployer",
                "Shout"
            ]),
        .testTarget(
            name: "SSHDeployerTests",
            dependencies: [
                "SSHDeployer"
            ]),
        
        .target(
            name: "SynchronousWaiter",
            dependencies: []),
        .testTarget(
            name: "SynchronousWaiterTests",
            dependencies: ["SynchronousWaiter"]),
        
        .target(
            name: "TempFolder",
            dependencies: [
                "Utility"
            ]),
        .testTarget(
            name: "TempFolderTests",
            dependencies: [
                "TempFolder"
            ]),
        
        .target(
            name: "TestingFakeFbxctest",
            dependencies: [
                "Extensions",
                "fbxctest",
                "Logging"
            ]),
        .target(
            name: "TestingPlugin",
            dependencies: [
                "Models",
                "Logging",
                "Plugin"
            ]),
        
        .target(
            name: "Timer",
            dependencies: [
            ]),
        
        .target(
            name: "URLResource",
            dependencies: [
                "FileCache",
                "Logging",
                "Utility"
            ]),
        .testTarget(
            name: "URLResourceTests",
            dependencies: [
                "FileCache",
                "Swifter",
                "URLResource",
                "Utility"
            ]),
        
        .target(
            name: "WorkerAlivenessTracker",
            dependencies: [
            ]),
        .target(
            name: "WorkerAlivenessTrackerTestHelpers",
            dependencies: [
                "WorkerAlivenessTracker"
            ]),
        .testTarget(
            name: "WorkerAlivenessTrackerTests",
            dependencies: [
                "WorkerAlivenessTracker",
                "WorkerAlivenessTrackerTestHelpers"
            ])
    ]
)
