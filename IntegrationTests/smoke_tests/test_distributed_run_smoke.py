import json

from IntegrationTests.helpers.fixture_types.EmceeRunTestsArgs import EmceeRunTestsArgs
from IntegrationTests.helpers.common_fixtures import *
from IntegrationTests.helpers.miscellaneous import check_file_exists, get_test_cases_from_xml_file
from IntegrationTests.smoke_tests.smoke_tests_fixtures import *


class TestDistributedRunSmoke:
    def test_check_reports_exist(self, smoke_tests_result: EmceeRunTestsArgs):
        check_file_exists(smoke_tests_result.current_directory.sub_path('auxiliary/tempfolder/test-results/iphone_se_ios_103.json'))
        check_file_exists(smoke_tests_result.current_directory.sub_path('auxiliary/tempfolder/test-results/iphone_se_ios_103.xml'))
        check_file_exists(smoke_tests_result.trace_path)
        check_file_exists(smoke_tests_result.junit_path)

    def test_junit_contents(self, repo_root: Directory, smoke_tests_result: EmceeRunTestsArgs):
        iphone_se_junit = get_test_cases_from_xml_file(
            path=smoke_tests_result.current_directory.sub_path('auxiliary/tempfolder/test-results/iphone_se_ios_103.xml')
        )
        assert len(iphone_se_junit) == 6

        successful_tests = set([item["name"] for item in iphone_se_junit if item.get("failure") is None])
        expected_successful_tests = {
            "testSlowTest",
            "testAlwaysSuccess",
            "testQuickTest",
            "testWritingToTestWorkingDir"
        }
        failed_tests = set([item["name"] for item in iphone_se_junit if item.get("failure") is not None])
        expected_failed_tests = {
            "testAlwaysFails",
            "testMethodThatThrowsSwiftError"
        }

        assert successful_tests == expected_successful_tests
        assert failed_tests == expected_failed_tests

    def test_plugin_output(self, repo_root: Directory, smoke_tests_result: EmceeRunTestsArgs):
        output_path = open(smoke_tests_result.current_directory.sub_path('auxiliary/tempfolder/test-results/test_plugin_output.json'), 'r')
        json_contents = json.load(output_path)

        testing_result_events = []
        tear_down_events = []
        runner_events = []
        unknown_events = []

        for event in json_contents:
            if event["eventType"] == "didObtainTestingResult":
                testing_result_events.append(event)
            elif event["eventType"] == "runnerEvent":
                runner_events.append(event)
            elif event["eventType"] == "tearDown":
                tear_down_events.append(event)
            else:
                unknown_events.append(event)

        self.check_test_result_events(testing_result_events)
        self.check_runner_events(runner_events)
        self.check_tear_down_events(tear_down_events)
        self.check_unknown_events(unknown_events)

    def check_test_result_events(self, events):
        all_test_entries = [test_entry_result["testEntry"]
                            for event in events
                            for test_entry_result in event["testingResult"]["unfilteredResults"]]
        actual_tests = sorted([entry["methodName"] for entry in all_test_entries])
        expected_tests = sorted([
            "testAlwaysSuccess",
            "testWritingToTestWorkingDir",
            "testSlowTest",
            "testAlwaysFails",
            "testQuickTest",
            "testMethodThatThrowsSwiftError"
        ])
        assert actual_tests == expected_tests

        all_test_runs = [unfiltered_test_runs
                         for event in events
                         for unfiltered_test_runs in event["testingResult"]["unfilteredResults"]]
        green_tests = [test_entry_result["testEntry"]["methodName"]
                       for test_entry_result in all_test_runs
                       for test_run in test_entry_result["testRunResults"]
                       if test_run["succeeded"] is True]
        failed_tests = [test_entry_result["testEntry"]["methodName"]
                        for test_entry_result in all_test_runs
                        for test_run in test_entry_result["testRunResults"]
                        if test_run["succeeded"] is False]
        expected_green_tests = [
            "testAlwaysSuccess",
            "testWritingToTestWorkingDir",
            "testSlowTest",
            "testQuickTest"
        ]

        assert sorted(green_tests) == sorted(expected_green_tests)

        # also check that failed tests have been restarted and the attempts are listed in the events
        expected_failed_tests = [
            "testAlwaysFails",
            "testAlwaysFails",
            "testMethodThatThrowsSwiftError",
            "testMethodThatThrowsSwiftError"
        ]
        assert sorted(failed_tests) == sorted(expected_failed_tests)

    def check_runner_events(self, events):
        all_runner_events = [event["runnerEvent"] for event in events]
        all_events_envs = [event["testContext"]["environment"] for event in all_runner_events]

        working_directory_values = [event_env.get("EMCEE_TESTS_WORKING_DIRECTORY") for event_env in all_events_envs]
        "Check that env.EMCEE_TESTS_WORKING_DIRECTORY is set"

        for working_dir in working_directory_values:
            assert working_dir != None

        all_will_run_events = [event for event in all_runner_events if event["eventType"] == "willRun"]
        all_did_run_events = [event for event in all_runner_events if event["eventType"] == "didRun"]
        "Check that number of willRun events equal to didRun events"
        assert len(all_will_run_events) == len(all_did_run_events)

        all_will_run_tests = [test_entry["methodName"]
                              for event in all_will_run_events
                              for test_entry in event["testEntries"]]
        all_did_run_tests = [test_entry_result["testEntry"]["methodName"]
                             for event in all_did_run_events
                             for test_entry_result in event["results"]]
        "Check that willRun events and didRun events match the test method names"
        assert sorted(all_will_run_tests) == sorted(all_did_run_tests)

        all_test_expected_to_be_ran = [
            "fakeTest",
            "testAlwaysSuccess",
            "testWritingToTestWorkingDir",
            "testSlowTest",
            "testQuickTest",
            "testAlwaysFails",
            "testMethodThatThrowsSwiftError"
        ]
        "Check that all expected tests have been invoked, including the fakeTest which is used for runtime dump feature"

        assert set(all_will_run_tests) == set(all_test_expected_to_be_ran)

        self.check_that_testWritingToTestWorkingDir_writes_to_working_dir(all_runner_events)

    def check_that_testWritingToTestWorkingDir_writes_to_working_dir(self, all_runner_events):
        did_run_events = [event for event in all_runner_events if event["eventType"] == "didRun"]
        event = [event
                 for event in did_run_events
                 for test_entry_result in event["results"]
                 if test_entry_result["testEntry"]["methodName"] == "testWritingToTestWorkingDir"][0]
        expected_path = os.path.join(
            event["testContext"]["environment"]["EMCEE_TESTS_WORKING_DIRECTORY"],
            "test_artifact.txt")
        test_output_file = open(expected_path, "r")
        contents = test_output_file.read()

        assert contents == "contents"

    def check_tear_down_events(self, events):
        assert len(events) == 1

    def check_unknown_events(self, events):
        assert len(events) == 0

@pytest.fixture(scope="session")
def smoke_tests_result(
        request,
        repo_root: Directory,
        avito_runner: ExecutableFixture,
        smoke_tests_app: IosAppFixture,
        smoke_tests_plugin: EmceePluginFixture,
        fbsimctl_url: str,
        fbxctest_url: str
):
    def make():
        print("Running integration tests")

        temporary_directory = Directory.make_temporary(remove_automatically=False)
        test_results_directory = temporary_directory.make_sub_directory("test_results")
        current_directory = temporary_directory.make_sub_directory("current_directory")

        args = EmceeRunTestsArgs(
            avito_runner=avito_runner,
            ios_app=smoke_tests_app,
            environment_json=repo_root.sub_path('auxiliary/environment.json'),
            fbsimctl_url=fbsimctl_url,
            fbxctest_url=fbxctest_url,
            junit_path=test_results_directory.sub_path('junit.combined.xml'),
            trace_path=test_results_directory.sub_path('trace.combined.json'),
            test_destinations=[repo_root.sub_path('auxiliary/destination_iphone_se_ios103.json')],
            temp_folder=temporary_directory.make_sub_directory("temp_folder").path,
            current_directory=current_directory,
            number_of_retries=1,
            number_of_simulators=2,
            plugins=[smoke_tests_plugin],
            schedule_strategy='individual',
            single_test_timeout=100
        )

        bash(command=args.command(), current_directory=current_directory.path)

        yield args

    yield from using_pycache(
        request=request,
        key="smoke_tests_result",
        make=make
    )
