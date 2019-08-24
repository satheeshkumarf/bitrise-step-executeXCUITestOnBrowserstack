#!/bin⁩/bash
set -e
result_file="BrowserstackResults.txt"
failed_tests="FailedTests.txt"
BUILD_IDENTIFIER=${BITRISE_BUILD_NUMBER}"_"${BITRISE_GIT_BRANCH}

if [ -f "$result_file" ]; then
rm BrowserstackResults.txt
fi
if [ -f "$failed_tests" ]; then
rm FailedTests.txt
fi

while IFS='=' read -ra line
do
test_name=${line[0]}
device_name=${line[1]}
echo "============================================================================================"
echo "Trigerring Test - "$test_name" on device - "$device_name
test_execution_input="{\"devices\": [\"${device_name}\"], \"app\": \"$BROWSERSTACK_APP_URL\", \"only-testing\" : [\"${test_name}\"], \"deviceLogs\" : \"true\", \"local\" : \"true\", \"testSuite\": \"$BROWSERSTACK_XCTEST_URL\", \"customBuildName\" : \"${BUILD_IDENTIFIER}\"}"
build_result=$(curl -X POST https://api-cloud.browserstack.com/app-automate/xcuitest/build -d "${test_execution_input}" -H 'Content-Type: application/json' -u $BROWSERSTACK_USERNAME:$BROWSERSTACK_PASSWORD)
echo $build_result
build_status=$(jq -n "$build_result" | jq .message)
build_status_temp="${build_status%\"}"
final_build_status="${build_status_temp#\"}"
if [[ $final_build_status == *"All parallel tests are currently in use"* ]] ; then
    echo "adding test to the build queue "$test_name
    echo $test_name"="$device_name >> $TESTS_FIILE_PATH
    echo "Waiting for 15 Seconds ...."
    sleep 15s;
else
    build_id=$(jq -n "$build_result" | jq .build_id)
    temp="${build_id%\"}"
    temp_build_id="${temp#\"}"
    echo $temp_build_id"="$device_name"="$test_execution_input >> BrowserstackResults.txt
fi
done < "$TESTS_FIILE_PATH"
echo "============================================================================================"
echo "Waiting for tests to finish execution.."
while IFS='=' read -ra line
do
build_id=${line[0]}
device_name=${line[1]}
test_execution_input=${line[2]}

for ((i=1;i<=30;i++));
do
sleep 20s;
Test_Result_Status=$(curl -u $BROWSERSTACK_USERNAME:$BROWSERSTACK_PASSWORD -X GET "https://api-cloud.browserstack.com/app-automate/xcuitest/builds/${build_id}");
Test_Status=$(jq -n "$Test_Result_Status" | jq .status)
temp_status="${Test_Status%\"}"
temp_status="${temp_status#\"}"
echo $temp_status

if [[ $temp_status != "running" ]] ; then
echo "************************************************************************************************";
echo "Checking Test Results...";
break
fi
done

passed_count=$(jq -n "$Test_Result_Status" | jq ".devices.\"${device_name}\".test_status.SUCCESS")
if [[ $passed_count -ge 1 ]]; then
echo "Test with BuildID - ${build_id} Passed.";
    else
echo "Test with BuildID -${build_id} Failed.";
echo $device_name"="$test_execution_input >> FailedTests.txt;
    fi
done < "$result_file"
for ((i=1;i<=${RETRY_COUNT};i++));
do
if [ -f "$failed_tests" ]; then
    echo "Test Failed, Executing re-run "$i" for following tests";
    sh ./ReRunFailedTests.sh;
else
    break
fi
done
if [ -f "$failed_tests" ]; then
echo "Following UI Tests Failed. Please check";
cat FailedTests.txt;
pkill -f BrowserStack.*;
exit 1;
else
echo "Test Passed";
fi
