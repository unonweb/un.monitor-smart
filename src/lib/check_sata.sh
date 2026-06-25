function check_sata {

    local disk="${1}"
	local smart_args="${2}"
    local disk_name=$(basename "${disk}")
    local tmp_log="${TMP_DIR}/${disk_name}.log"

    # Dump all SMART data (Attributes and Self-Test logs) to a temp file
    smartctl --all ${smart_args} "${disk}" > "${tmp_log}"

    # 1. & 2. Parse SMART Attributes (WORST, RAW_VALUE, THRESH)
    # Grep lines that start with a number (these are the attribute rows)
    grep -E '^[[:space:]]*[0-9]+ ' "${tmp_log}" | while read -r id name flag value worst thresh type updated when_failed raw; do
        
        # Monitor for new WORST value lows
        local prev_worst=$(get_state "${disk_name}" "${id}_worst")
        if [[ -n "${prev_worst}" ]] && (( 10#${worst} < 10#${prev_worst} )); then # && [[ "${worst}" -lt "${prev_worst}" ]]; then

			local subj="[${disk}] New WORST value for ${name}"
			local msg="The WORST value for attribute ${name} (ID ${id}) dropped from ${prev_worst} to ${worst} on ${disk}."

			alert "${subj}" "${msg}"
        fi
        set_state "${disk_name}" "${id}_worst" "${worst}"

        # Compare RAW_VALUE against THRESH
        if [[ "${thresh}" =~ ^[0-9]+$ ]] && [[ "$raw" =~ ^[0-9]+$ ]]; then
            if (( raw > thresh )); then
                # Only alert once per threshold cross to prevent spam
                local raw_alerted=$(get_state "${disk_name}" "${id}_raw_alerted")
                if [[ "${raw_alerted}" != "1" ]]; then

					local subj="[${disk}] RAW exceeds THRESH for ${name}"
					local msg="Attribute ${name} (ID ${id}) on ${disk} has a RAW_VALUE of ${raw}, which exceeds the THRESHOLD of ${thresh}."

					alert "${subj}" "${msg}"
					# set alerted to prevent multiple alerts for the same cause
                    set_state "${disk_name}" "${id}_raw_alerted" "1"
                fi
            else
                set_state "${disk_name}" "${id}_raw_alerted" "0"
            fi
        fi
    done

    # 3. Monitor new test results for errors
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

	# DEBUG
	# =====

	if ((DEBUG)); then
		echo -e "\
			id: ${id}\n\
			name: ${name}\n\
			worst: ${worst}\n\
			thresh: ${thresh}\n\
			raw: ${raw}\n\
			latest_test: ${latest_test}\n\
		"
	fi
}