import Foundation

public struct DistRunConfiguration {
    
    /** An identifier of distributed run of tests. UUID usually is a good choice. */
    public let runId: String
    
    /** The output locations. */
    public let reportOutput: ReportOutput
    
    /** A list of destinations that should be used for distributed run. */
    public let destinations: [DeploymentDestination]
    
    /** A list of additional per-destination configurations. */
    public let destinationConfigurations: [DestinationConfiguration]
    
    /** How to scatter tests onto destinations. */
    public let remoteScheduleStrategyType: ScheduleStrategyType
    
    /** Timeout values. */
    public let testTimeoutConfiguration: TestTimeoutConfiguration
    
    /** Deifnes the behavior of the test run. */
    public let testExecutionBehavior: TestExecutionBehavior
    
    /** Paths that are required to make things work. */
    public let auxiliaryResources: AuxiliaryResources
    
    /** A set of paths to the build artifacts. */
    public let buildArtifacts: BuildArtifacts

    /** Some settings that should be applied to the test environment prior running the tests. */
    public let simulatorSettings: SimulatorSettings
    
    /** All test that must be run by the test runner. */
    public let testsToRun: [TestToRun]
    
    /** Test destination configurations for the test run.  */
    public let testDestinationConfigurations: [TestDestinationConfiguration]
    
    /// Period of time when workers should report their aliveness
    public let reportAliveInterval: TimeInterval = 30

    public init(
        runId: String,
        reportOutput: ReportOutput,
        destinations: [DeploymentDestination],
        destinationConfigurations: [DestinationConfiguration],
        remoteScheduleStrategyType: ScheduleStrategyType,
        testTimeoutConfiguration: TestTimeoutConfiguration,
        testExecutionBehavior: TestExecutionBehavior,
        auxiliaryResources: AuxiliaryResources,
        buildArtifacts: BuildArtifacts,
        simulatorSettings: SimulatorSettings,
        testsToRun: [TestToRun],
        testDestinationConfigurations: [TestDestinationConfiguration])
    {
        self.runId = runId
        self.reportOutput = reportOutput
        self.destinations = destinations
        self.destinationConfigurations = destinationConfigurations
        self.remoteScheduleStrategyType = remoteScheduleStrategyType
        self.testTimeoutConfiguration = testTimeoutConfiguration
        self.testExecutionBehavior = testExecutionBehavior
        self.auxiliaryResources = auxiliaryResources
        self.buildArtifacts = buildArtifacts
        self.simulatorSettings = simulatorSettings
        self.testsToRun = testsToRun
        self.testDestinationConfigurations = testDestinationConfigurations
    }
    
    public var testDestinations: [TestDestination] {
        return testDestinationConfigurations.map { $0.testDestination }
    }
    
    public func workerConfiguration(destination: DeploymentDestination) -> WorkerConfiguration {
        return WorkerConfiguration(
            testExecutionBehavior: testExecutionBehavior(destination: destination),
            testTimeoutConfiguration: testTimeoutConfiguration,
            reportAliveInterval: reportAliveInterval)
    }
    
    private func testExecutionBehavior(destination: DeploymentDestination) -> TestExecutionBehavior {
        let overrides = destinationConfigurations.first { $0.destinationIdentifier == destination.identifier }
        
        // Queue server will retry by itself
        let numberOfRetriesOnLocalMachine: UInt = 0
        
        return TestExecutionBehavior(
            numberOfRetries: numberOfRetriesOnLocalMachine,
            numberOfSimulators: overrides?.numberOfSimulators ?? testExecutionBehavior.numberOfSimulators,
            environment: testExecutionBehavior.environment,
            scheduleStrategy: testExecutionBehavior.scheduleStrategy)
    }
}
