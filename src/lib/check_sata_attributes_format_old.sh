function check_sata_attributes_format_old {

	local tmp_log="${1}"
	local alert_msg=""

	source "${SCRIPT_DIR}/lib/alert.sh"

	grep --extended-regexp '^[[:space:]]*[0-9]+ ' "${tmp_log}" | while read -r id attribute_name flag value worst thresh type updated when_failed raw_value; do
		# '^[[:space:]]*'
		# Matches any line that starts with zero or more spaces
		# '[0-9]+ '
		# Matches one or more digits followed by a literal space
        # read splits a line of text using any whitespace as a delimiter
		# read then assigns the encountered pieces of text one-by-one to the given variables
		# read -r prevents backslashes from acting as escape characters, preserving the text exactly as it is

		debug "\nAttribute: ${attribute_name}"
		
		# WHEN_FAILED
		# ===========
		
		if [[ "${when_failed}" != "-" ]]; then

			debug "Fail Alert: ${when_failed}"

			# Only alert once per threshold cross to prevent spam
			local fail_alerted=$(get_state "${disk_name}" "${id}_fail_alerted")
			if [[ "${fail_alerted}" != "1" ]]; then

				local msg="ATTRIBUTE: ${id} ${attribute_name}\n\n Fail Alert: ${when_failed}"
				alert_msg+="${msg}\n"
				
				# set state to prevent multiple alerts for the same cause
				set_state "${disk_name}" "${id}_fail_alerted" "1"
			fi
		else
			# debug "No Fail detected: ${when_failed}"
			set_state "${disk_name}" "${id}_fail_alerted" "0"
		fi

		# TEMPERATURE
		# ===========

		if [[ "${attribute_name}" = "Temperature_Celsius" ]]; then
			# ID: 194
			local attribute_temparature_celsius_present=1
			local prev_worst=$(get_state "${disk_name}" "${id}_worst")

			# Match digits at the start of the string
			if [[ "${raw_value}" =~ ^([0-9]+) ]]; then
				# BASH_REMATCH[1] contains the captured text 
				# (regex inside the first set of parentheses)
				raw_value_cleaned="${BASH_REMATCH[1]}"
			fi

			if [[ -z "${raw_value_cleaned}" ]]; then
				msg="ERROR: Could not get raw_value_cleaned from ${raw_value}"
				log "${msg}"
				debug "${msg}"
				continue
			fi
			
			# Figure out scale
			if (( 10#${raw_value_cleaned} == 10#${value} )); then
				# This manufacturer is using a 1:1 Celsius scale
				# Here we need to check if the new worst value is HIGHER that the previous
				debug "Celsius Scale: 1:1"

				if [[ -n "${prev_worst}" ]] && (( 10#${worst} > 10#${prev_worst} )); then

					local msg="The WORST value for attribute ${attribute_name} (ID ${id}) raised from ${prev_worst} to ${worst} on ${disk}."
					alert_msg+="${msg}"
					debug "${msg}"
				fi
			else
				# This manufacturer is using a normalized scale
				if [[ -n "${prev_worst}" ]] && (( 10#${worst} < 10#${prev_worst} )); then

					debug "Celsius Scale: normalized"
					local msg="The WORST value for attribute ${attribute_name} (ID ${id}) dropped from ${prev_worst} to ${worst} on ${disk}."
					alert_msg+="${msg}"					
					debug "${msg}"
				fi
			fi
			
			set_state "${disk_name}" "${id}_worst" "${worst}"
		fi
		

		# WORST
		# =====
		# Monitor for new WORST value lows of 'Pre-fail' types
		# Include additional attributes from the config

		if [[ "${type}" == "Pre-fail" ]] || is_str_in_arr "${attribute_name}" "${SMART_INCLUDE_SATA_ATTRIBUTES[@]}"; then
			local prev_worst=$(get_state "${disk_name}" "${id}_worst")
			# use (( )) to handle numbers correctly
			# use 10# to force bash to treat the value as a base-10 integer
			if [[ -n "${prev_worst}" ]] && (( 10#${worst} < 10#${prev_worst} )); then

				local msg="The WORST value for attribute ${attribute_name} (ID ${id}) dropped from ${prev_worst} to ${worst} on ${disk}."
				alert_msg+="${msg}"
				debug "Alert: ${msg}"
			fi

			set_state "${disk_name}" "${id}_worst" "${worst}"
		fi
		
    done

	# ALERT
	# =====
	debug "alert_msg: ${alert_msg}"

	if [[ -n "${alert_msg}" ]]; then
		alert "${alert_msg}"
	fi
}