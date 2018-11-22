import textwrap
from typing import List

from IntegrationTests.helpers.fixture_types.EmceePluginFixture import EmceePluginFixture
from IntegrationTests.helpers.fixture_types.ExecutableFixture import ExecutableFixture
from IntegrationTests.helpers.fixture_types.IosAppFixture import IosAppFixture
from IntegrationTests.helpers.Directory import Directory

class EmceeCommonArgs:
    # Not supported yet:
    # --additional-app
    def __init__(
            self,
            avito_runner: ExecutableFixture,
            ios_app: IosAppFixture,
            environment_json,
            fbsimctl_url: str,
            fbxctest_url: str,
            junit_path: str,
            trace_path: str,
            test_destinations: [str],
            temp_folder: str,
            current_directory: Directory,
            number_of_retries: int = 1,
            number_of_simulators: int = 1,
            plugins: [EmceePluginFixture] = None,
            single_test_timeout: int = 300
    ):
        if plugins is None:
            plugins = []

        self.avito_runner = avito_runner
        self.ios_app = ios_app
        self.environment_json = environment_json
        self.fbsimctl_url = fbsimctl_url
        self.fbxctest_url = fbxctest_url
        self.junit_path = junit_path
        self.trace_path = trace_path
        self.test_destinations = test_destinations
        self.temp_folder = temp_folder
        self.number_of_retries = number_of_retries
        self.number_of_simulators = number_of_simulators
        self.plugins = plugins
        self.single_test_timeout = single_test_timeout
        self.current_directory = current_directory

    def args(self):
        args: List[str] = [
            '--app', self.ios_app.app_path,
            '--environment', self.environment_json,
            '--fbsimctl', self.fbsimctl_url,
            '--fbxctest', self.fbxctest_url,
            '--junit', self.junit_path,
            '--number-of-retries', str(self.number_of_retries),
            '--number-of-simulators', str(self.number_of_simulators),
            '--runner', self.ios_app.ui_tests_runner_path,
            '--single-test-timeout', str(self.single_test_timeout),
            '--temp-folder', self.temp_folder,
            '--trace', self.trace_path,
            '--xctest-bundle', self.ios_app.xctest_bundle_path
        ]

        for plugin in self.plugins:
            args.extend(['--plugin', plugin.path])

        for destination in self.test_destinations:
            args.extend(['--test-destinations', destination])

        return args

class EmceeRunTestsArgs(EmceeCommonArgs):
    def __init__(
            self,
            avito_runner: ExecutableFixture,
            ios_app: IosAppFixture,
            environment_json,
            fbsimctl_url: str,
            fbxctest_url: str,
            junit_path: str,
            trace_path: str,
            test_destinations: [str],
            temp_folder: str,
            current_directory: Directory,
            number_of_retries: int = 1,
            number_of_simulators: int = 1,
            plugins: [EmceePluginFixture] = None,
            schedule_strategy: str = "individual",
            single_test_timeout: int = 300
    ):
        self.schedule_strategy = schedule_strategy

        super().__init__(
            avito_runner = avito_runner,
            ios_app = ios_app,
            environment_json = environment_json,
            fbsimctl_url = fbsimctl_url,
            fbxctest_url = fbxctest_url,
            junit_path = junit_path,
            trace_path = trace_path,
            test_destinations = test_destinations,
            temp_folder = temp_folder,
            number_of_retries = number_of_retries,
            number_of_simulators = number_of_simulators,
            plugins = plugins,
            single_test_timeout = single_test_timeout,
            current_directory = current_directory
        )

    def command(self):
        args: List[str] = [self.avito_runner.path, 'runTests'] + super().args

        args.extend(['--schedule-strategy', self.schedule_strategy])

        return args

class EmceeDistRunTestsArgs(EmceeCommonArgs):
    def __init__(
            self,
            avito_runner: ExecutableFixture,
            ios_app: IosAppFixture,
            environment_json,
            fbsimctl_url: str,
            fbxctest_url: str,
            junit_path: str,
            trace_path: str,
            test_destinations: [str],
            temp_folder: str,
            current_directory: Directory,
            number_of_retries: int = 1,
            number_of_simulators: int = 1,
            plugins: [EmceePluginFixture] = None,
            schedule_strategy: str = "individual",
            single_test_timeout: int = 300
    ):
        super().__init__(
            avito_runner = avito_runner,
            ios_app = ios_app,
            environment_json = environment_json,
            fbsimctl_url = fbsimctl_url,
            fbxctest_url = fbxctest_url,
            junit_path = junit_path,
            trace_path = trace_path,
            test_destinations = test_destinations,
            temp_folder = temp_folder,
            number_of_retries = number_of_retries,
            number_of_simulators = number_of_simulators,
            plugins = plugins,
            schedule_strategy = schedule_strategy,
            single_test_timeout = single_test_timeout,
            current_directory = current_directory
        )

    def command(self):
        args: List[str] = [self.avito_runner.path, 'runTests'] + super().args


        args.extend(['--remote - schedule-strategy', self.schedule_strategy])


        return args

        def command(self):
            args: List[str] = [
                self.avito_runner.path, 'runTests',
                '--app', self.ios_app.app_path,
                '--environment', self.environment_json,
                '--fbsimctl', self.fbsimctl_url,
                '--fbxctest', self.fbxctest_url,
                '--junit', self.junit_path,
                '--number-of-retries', str(self.number_of_retries),
                '--number-of-simulators', str(self.number_of_simulators),
                '--runner', self.ios_app.ui_tests_runner_path,
                '--schedule-strategy', self.schedule_strategy,
                '--single-test-timeout', str(self.single_test_timeout),
                '--temp-folder', self.temp_folder,
                '--trace', self.trace_path,
                '--xctest-bundle', self.ios_app.xctest_bundle_path
            ]

            for plugin in self.plugins:
                args.extend(['--plugin', plugin.path])

            for destination in self.test_destinations:
                args.extend(['--test-destinations', destination])

            return args

#
    # distRunTests \

    # --remote-schedule-strategy "progressive" \
    # --run-id "$REMOTE_RUN_ID_FINAL" \
    # --runner "$runnerAppLocation" \
    # --schedule-strategy "equally_divided" \
    # --simulator-localization-settings "$CHECKOUT_DIRECTORY_FINAL/ci_automation/functional/avito_run_tests/simulator_localization.json" \
    # --single-test-timeout "$TEST_TIMEOUT" \
    # --test-destinations "$TEST_DESTINATIONS_FILE" \
    # --trace "$TRACE_REPORT_PATH_FINAL" \
    # --watchdog-settings "$CHECKOUT_DIRECTORY_FINAL/ci_automation/functional/avito_run_tests/watchdog.json" \
    # --xctest-bundle "$xcTestBundleLocation" \
    # "${INCLUDE_TESTS_ARGS[@]}"