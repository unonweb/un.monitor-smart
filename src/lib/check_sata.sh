function check_sata {

    local disk="${1}"
	local smart_args="${2}"
    local disk_name=$(basename "${disk}")
    local tmp_log="${TMP_DIR}/${disk_name}.log"

	# Dump SMART data
	# (Attributes and Self-Test logs) to a tmp file
    smartctl --all ${smart_args} "${disk}" > "${tmp_log}"
	
	# CHECK --format=old
	source "${SCRIPT_DIR}/lib/check_sata_format_old.sh"

    # PARSE SMART ATTRIBUTES
	# ======================
    # Grep lines that start with a number (these are the attribute rows)

    check_sata_format_old "${tmp_log}"

	# PARSE TEST RESULTS
	# ==================
    # Monitor new test results for errors

    # Grab the most recent test result (starts with "# 1") from the same log
    latest_test=$(grep -E "^# 1 " "${tmp_log}")
    if [[ -n "${latest_test}" ]] && ! echo "${latest_test}" | grep -qi "Completed without error"; then
        
        # Use the LifeTime(hours) column as a unique identifier for the test
        local test_lifetime=$(echo "${latest_test}" | awk '{print $9}')
        local prev_test=$(get_state "${disk_name}" "latest_error_test")
        
        if [[ "${test_lifetime}" != "${prev_test}" ]]; then

			local subj="[${disk}] Self-Test Error"
			local msg="A SMART self-test on ${disk} reported an error.\n\nDetails:\n${latest_test}"

			alert "${subj}" "${msg}"
            set_state "${disk_name}" "latest_error_test" "${test_lifetime}"
        fi
    fi
}