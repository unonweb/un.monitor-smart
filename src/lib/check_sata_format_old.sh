function check_sata_format_old {

	local tmp_log="${1}"

	grep --extended-regexp '^[[:space:]]*[0-9]+ ' "${tmp_log}" | while read -r id attribute_name flag value worst thresh type updated when_failed raw_value; do
		# '^[[:space:]]*'
		# Matches any line that starts with zero or more spaces
		# '[0-9]+ '
		# Matches one or more digits followed by a literal space
        # read splits a line of text using any whitespace as a delimiter
		# read then assigns the encountered pieces of text one-by-one to the given variables
		# read -r prevents backslashes from acting as escape characters, preserving the text exactly as it is

		if ((DEBUG)); then echo "Attribute: ${attribute_name}"; fi
		
		# WHEN_FAILED
		# ===========
		
		if [[ "${when_failed}" != "-" ]]; then

			if ((DEBUG)); then echo "Fail Alert: ${when_failed}"; fi

			# Only alert once per threshold cross to prevent spam
			local fail_alerted=$(get_state "${disk_name}" "${id}_fail_alerted")
			if [[ "${fail_alerted}" != "1" ]]; then

				local subj="[${disk}] Fail Alert: ${attribute_name}"
				local msg="DISK: ${disk}\nATTRIBUTE: ${id} ${attribute_name}\n\n Fail Alert: ${when_failed}"

				alert "${subj}" "${msg}"
				# set state to prevent multiple alerts for the same cause
				set_state "${disk_name}" "${id}_fail_alerted" "1"
			fi
		else
			if ((DEBUG)); then echo "No Fail detected: ${when_failed}"; fi
			set_state "${disk_name}" "${id}_fail_alerted" "0"
		fi

		# Skip attributes we're not interested in
		if ! is_str_in_arr "${attribute_name}" "${SMART_INCLUDE_SATA_ATTRIBUTES[@]}"; then
			if ((DEBUG)); then echo "Skipping attribute"; fi
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
			
			if ((DEBUG)); then echo "Comparing attribute: RAW > THRES: ${raw_value} > ${thresh}"; fi
			
            if (( 10#${raw_value} > 10#${thresh} )); then
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
}