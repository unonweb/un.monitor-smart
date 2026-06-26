function check_sata {

    local disk="${1}"
	local smart_args="${2}"
    local disk_name=$(basename "${disk}")
    local tmp_log="${TMP_DIR}/${disk_name}.log"

    # Dump SMART data
	# (Attributes and Self-Test logs) to a tmp file
    smartctl --all ${smart_args} "${disk}" > "${tmp_log}"

    # PARSE SMART ATTRIBUTES
	# ======================
    # Grep lines that start with a number (these are the attribute rows)

    grep -E '^[[:space:]]*[0-9]+ ' "${tmp_log}" | while read -r id attribute_name flag value worst thresh type updated when_failed raw_value; do
        
		# Skip attributes that are not included
		if ! is_str_in_arr "${attribute_name}" "${SMART_INCLUDE_SATA_ATTRIBUTES[@]}"; then
			if ((DEBUG)); then echo "Skipping attribute ${attribute_name}"; fi
			continue
		fi

        # WORST
		# =====
		# Monitor for new WORST value lows

        local prev_worst=$(get_state "${disk_name}" "${id}_worst")
		# use (( )) to handle numbers correctly
		# use 10# to force bash to treat the value as a base-10 integer
        if [[ -n "${prev_worst}" ]] && (( 10#${worst} < 10#${prev_worst} )); then

			local subj="[${disk}] New WORST value for ${attribute_name}"
			local msg="The WORST value for attribute ${attribute_name} (ID ${id}) dropped from ${prev_worst} to ${worst} on ${disk}."

			alert "${subj}" "${msg}"
        fi
        set_state "${disk_name}" "${id}_worst" "${worst}"
		
		# THRESH
		# ======
        # Compare RAW_VALUE against THRESH
		
		# Check that both vars contain only numbers
        if [[ "${thresh}" =~ ^[0-9]+$ ]] && [[ "${raw_value}" =~ ^[0-9]+$ ]]; then
            if (( raw_value > thresh )); then
                # Only alert once per threshold cross to prevent spam
                local raw_alerted=$(get_state "${disk_name}" "${id}_raw_alerted")
                if [[ "${raw_alerted}" != "1" ]]; then

					local subj="[${disk}] RAW exceeds THRESH for ${attribute_name}"
					local msg="Attribute ${attribute_name} (ID ${id}) on ${disk} has a RAW_VALUE of ${raw_value}, which exceeds the THRESHOLD of ${thresh}."

					alert "${subj}" "${msg}"
					# set alerted to prevent multiple alerts for the same cause
                    set_state "${disk_name}" "${id}_raw_alerted" "1"
                fi
            else
                set_state "${disk_name}" "${id}_raw_alerted" "0"
            fi
        fi
    done

	# TEST RESULTS
	# ============
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