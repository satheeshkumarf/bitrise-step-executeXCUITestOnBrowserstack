#!/bin⁩/bash
input="FailedTests.txt"
result_file="BrowserstackReRunResults.txt"
failed_in_rerun="FailedTestsInRerun.txt"
if [ -f "$result_file" ]; then
rm BrowserstackReRunResults.txt
fi
if [ -f "$failed_in_rerun" ]; then
rm FailedTestsInRerun.txt
fi
while IFS='=' read -ra line
do
device_name=${line[0]}
test_execution_input=${line[1]}
echo "============================================================================================"
echo "Trigerring Test .."
build_result=$(curl -X POST https://api-cloud.browserstack.com/app-automate/xcuitest/build -d "${test_execution_input}" -H 'Content-Type: application/json' -u $browserstack_username:$browserstack_password)
echo $build_result
build_status=$(jq -n "$build_result" | jq .message)
build_status_temp="${build_status%\"}"
final_build_status="${build_status_temp#\"}"
if [[ $final_build_status == *"All parallel tests are currently in use"* ]] ; then
echo "adding test to the build queue "$test_name
echo $device_name"="$test_execution_input >> $input
echo "Waiting for 15 Seconds ...."
sleep 15s;
else
build_id=$(jq -n "$build_result" | jq .build_id)
temp="${build_id%\"}"
temp_build_id="${temp#\"}"
echo $temp_build_id
echo $temp_build_id"="$device_name"="$test_execution_input >> BrowserstackReRunResults.txt
fi
done < "$input"

while IFS='=' read -ra line
do
build_id=${line[0]}
device_name=${line[1]}
test_execution_input=${line[2]}

for ((i=1;i<=30;i++));
do
sleep 20s;
Test_Result_Status=$(curl -u $browserstack_username:$browserstack_password -X GET "https://api-cloud.browserstack.com/app-automate/xcuitest/builds/${build_id}");

Test_Status=$(jq -n "$Test_Result_Status" | jq .status)
temp_status="${Test_Status%\"}"
temp_status="${temp_status#\"}"
echo $temp_status
if [[ $temp_status != "running" ]] ; then
echo "Checking Test Results ...";
    break
fi
done
echo $Test_Result_Status
passed_count=$(jq -n "$Test_Result_Status" | jq ".devices.\"${device_name}\".test_status.SUCCESS")
if [[ $passed_count -ge 1 ]]; then
echo "${build_id} passed";
else
echo "${build_id} failed";
echo $device_name"="$test_execution_input >> FailedTestsInRerun.txt;
fi
done < "$result_file"
rm FailedTests.txt
if [ -f "$failed_in_rerun" ]; then
cp FailedTestsInRerun.txt FailedTests.txt
rm FailedTestsInRerun.txt
fi
