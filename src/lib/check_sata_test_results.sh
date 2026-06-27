function check_sata_test_results {
	
	local tmp_log="${1}"

	# Grab the most recent test result (starts with "# 1") from the same log
    latest_test=$(grep -E "^# 1 " "${tmp_log}")
    if [[ -n "${latest_test}" ]] && ! echo "${latest_test}" | grep -qi "Completed without error"; then
        
        # Use the LifeTime(hours) column as a unique identifier for the test
        local test_lifetime=$(echo "${latest_test}" | awk '{print $9}')
        local prev_test=$(get_state "${disk_name}" "latest_error_test")
        
        if [[ "${test_lifetime}" != "${prev_test}" ]]; then

			local msg="A SMART self-test on ${disk} reported an error.\n\nDetails:\n${latest_test}"
			alert_msg+="${msg}"
			set_state "${disk_name}" "latest_error_test" "${test_lifetime}"
        fi
    fi
}