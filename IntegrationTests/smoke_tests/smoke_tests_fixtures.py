import os
import pytest

from IntegrationTests.helpers.Directory import Directory
from IntegrationTests.helpers.bash import bash
from IntegrationTests.helpers.cache import using_pycache
from IntegrationTests.helpers.fixture_types.EmceePluginFixture import EmceePluginFixture
from IntegrationTests.helpers.fixture_types.IosAppFixture import IosAppFixture


@pytest.fixture(scope="session")
def smoke_tests_app(request, repo_root):
    def make():
        temporary_directory: Directory = Directory.make_temporary(remove_automatically=False)
        derived_data: Directory = temporary_directory.make_sub_directory(path="DerivedData")
        xcodebuild_log_path: str = derived_data.sub_path('xcodebuild.log.ignored')

        print(f'Building for testing. Build is log path: {xcodebuild_log_path}')

        bash(command=f'''
        set -o pipefail && \
        cd "{repo_root.path}/TestApp" && xcodebuild build-for-testing \
        -scheme "TestApp" \
        -derivedDataPath {derived_data.path} \
        -destination "platform=iOS Simulator,name=iPhone SE,OS=10.3.1" \
        | tee "{xcodebuild_log_path}" || (echo "Failed! Logs: `cat {xcodebuild_log_path}`" && exit 3)
        ''')

        # Work around a bug when xcodebuild puts Build and Indexes folders to a pwd instead of derived data
        def derived_data_workaround(top_level_folder: str):
            build_folder = '{repo_root.path}/TestApp/{top_level_folder}'
            if os.path.isdir(build_folder):
                print(f'Unexpectidly found {top_level_folder} in PWD, moving {repo_root.path}/TestApp/{top_level_folder}/ to {derived_data.path}/')
                os.rename(build_folder, f'{derived_data.path}/{top_level_folder}')

        derived_data_workaround(top_level_folder='Build')
        derived_data_workaround(top_level_folder='Index')

        yield IosAppFixture(
            app_path=f'{derived_data.path}/Build/Products/Debug-iphonesimulator/TestApp.app',
            ui_tests_runner_path=f'{derived_data.path}/Build/Products/Debug-iphonesimulator/TestAppUITests-Runner.app',
            xctest_bundle_path=f'{derived_data.path}/Build/Products/Debug-iphonesimulator/TestAppUITests-Runner.app/PlugIns/TestAppUITests.xctest'
        )

    yield from using_pycache(
        request=request,
        key="smoke_tests_app",
        make=make
    )


@pytest.fixture(scope="session")
def smoke_tests_plugin(request, repo_root):
    def make():
        bash(command='make build', current_directory=f'{repo_root.path}/TestPlugin')

        yield EmceePluginFixture(
            path=f'{repo_root.path}/TestPlugin/.build/debug/TestPlugin.emceeplugin'
        )

    yield from using_pycache(
        request=request,
        key="smoke_tests_plugin",
        make=make
    )