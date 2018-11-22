#!/bin/bash

set -e

main() {
    goToWorkingDirectory
    checkDependencies
    runTests
}

goToWorkingDirectory() {
    cd `dirname $0`
    cd `git rev-parse --show-toplevel`
    cd "IntegrationTests"
}

checkDependencies() {
    upgradePythonIfNeeded
    installPyTestIfNeeded
    installRequirementsTxt
}

runTests() {
    pytest --cache-clear
}

upgradePythonIfNeeded() {
    local pythonVersion=`python3 --version`

    # Require Python >= 3.6
    if [ `echo "$pythonVersion"|perl -pe 's/^.*?([0-9]+)\.([0-9]+).*$/\1\2/'` -ge 36 ]
    then
        echo "Python is already installed, python3 --version is $pythonVersion"
    else
        echo "Incorrect python version, upgrading python..."
        upgradePython
    fi
}

upgradePython() {
    if brew upgrade python 2>&1 | grep "Install the Command Line Tools"
    then
        echo "Command Line Tools not installed, installing..."
        installCommandLineTools
        brew upgrade python
    fi
}

installCommandLineTools() {
    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

    packageName=$(softwareupdate -l|grep "\*.*Command Line"|head -n 1|awk -F"*" '{print $2}'|sed -e 's/^ *//' | tr -d '\n')

    softwareupdate -i "$packageName"
}

installPyTestIfNeeded() {
    which pytest || pip3 install pytest
}

installRequirementsTxt() {
    pip3 install -r "requirements.txt"
}

main