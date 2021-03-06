import Foundation
import Models
import ModelsTestHelpers
import ScheduleStrategy
import XCTest

final class BucketSplitterTests: XCTestCase {
    let testDestination1 = TestDestinationFixtures.testDestination
    let testDestination2 = try! TestDestination(deviceType: "device2", runtime: "11.0")
    
    func test_splits_into_matrix_of_test_destination_by_test_entry() {
        let testEntryConfigurations =
            TestEntryConfigurationFixtures()
                .add(testEntry: TestEntry(className: "class", methodName: "testMethod1", caseId: nil))
                .add(testEntry: TestEntry(className: "class", methodName: "testMethod2", caseId: nil))
                .add(testEntry: TestEntry(className: "class", methodName: "testMethod3", caseId: nil))
                .add(testEntry: TestEntry(className: "class", methodName: "testMethod4", caseId: nil))
                .with(testDestination: testDestination1)
                .testEntryConfigurations()
                +
                TestEntryConfigurationFixtures()
                    .add(testEntry: TestEntry(className: "class", methodName: "testMethod1", caseId: nil))
                    .add(testEntry: TestEntry(className: "class", methodName: "testMethod2", caseId: nil))
                    .add(testEntry: TestEntry(className: "class", methodName: "testMethod3", caseId: nil))
                    .add(testEntry: TestEntry(className: "class", methodName: "testMethod4", caseId: nil))
                    .with(testDestination: testDestination2)
                    .testEntryConfigurations()
        
        let splitter = DirectSplitter()
        
        let buckets = splitter.generate(
            inputs: testEntryConfigurations,
            splitInfo: BucketSplitInfoFixtures.bucketSplitInfoFixture()
        )
        XCTAssertEqual(buckets.count, 2)
        
        // TODO: add more checks
    }
}
