function check_sata_attributes_format_old {

	local tmp_log="${1}"
	local alert_msg=""

	source "${SCRIPT_DIR}/lib/alert.sh"

	while read -r id attribute_name flag value worst thresh type updated when_failed raw_value; do
		# '^[[:space:]]*'
		# Matches any line that starts with zero or more spaces
		# '[0-9]+ '
		# Matches one or more digits followed by a literal space
        # read splits a line of text using any whitespace as a delimiter
		# read then assigns the encountered pieces of text one-by-one to the given variables
		# read -r prevents backslashes from acting as escape characters, preserving the text exactly as it is

		log "<7> Attribute: ${attribute_name}"
		
		# WHEN_FAILED
		# ===========
		
		if [[ "${when_failed}" != "-" ]]; then

			log "<7> Fail Alert: ${when_failed}"

			# Only alert once per threshold cross to prevent spam
			local fail_alerted=$(get_state "${disk_name}" "${id}_fail_alerted")
			if [[ "${fail_alerted}" != "1" ]]; then

				local msg="${id} ${attribute_name}\nFail Alert: ${when_failed}"
				alert_msg+="${msg}\n"
				
				# set state to prevent multiple alerts for the same cause
				set_state "${disk_name}" "${id}_fail_alerted" "1"
			fi
		else
			# log "<7> No Fail detected: ${when_failed}"
			set_state "${disk_name}" "${id}_fail_alerted" "0"
		fi

		# TEMPERATURE
		# ===========

		if [[ "${attribute_name}" =~ ^(Temperature_Celsius|Airflow_Temperature_Cel)$ ]]; then
			# ID: 194
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
				log "<7> ${msg}"
				continue
			fi
			
			# independently of new worst values
			# alert if temperature is above given threshold
			if (( 10#${raw_value_cleaned} > 10#${SMART_CELSIUS_THRESH} )); then
				local msg="${id} ${attribute_name}\nTemperature (${raw_value_cleaned}) above given threshold of ${SMART_CELSIUS_THRESH}"
				alert_msg+="${msg}\n"
			fi
			
			# Figure out scale
			if (( 10#${raw_value_cleaned} == 10#${value} )); then
				# This manufacturer is using a 1:1 Celsius scale
				# Here we need to check if the new worst value is HIGHER that the previous
				log "<7> Celsius Scale: 1:1"

				if [[ -n "${prev_worst}" ]] && (( 10#${worst} > 10#${prev_worst} )); then

					local msg="${id} ${attribute_name}\nThe WORST value raised from ${prev_worst} to ${worst}"
					alert_msg+="${msg}\n"
					log "<7> ${msg}"
				fi
			else
				# This manufacturer is using a normalized scale
				if [[ -n "${prev_worst}" ]] && (( 10#${worst} < 10#${prev_worst} )); then

					log "<7> Celsius Scale: normalized"
					local msg="${id} ${attribute_name}\nThe WORST value dropped from ${prev_worst} to ${worst}"
					alert_msg+="${msg}\n"					
					log "<7> ${msg}"
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

				local msg="${id} ${attribute_name}\nThe WORST value dropped ${prev_worst} to ${worst}"
				alert_msg+="${msg}\n"
				log "<7> Alert: ${msg}"
			fi

			set_state "${disk_name}" "${id}_worst" "${worst}"
		fi
		
    done < <(grep --extended-regexp '^[[:space:]]*[0-9]+ ' "${tmp_log}")

	# ALERT
	# =====
	
	if [[ -n "${alert_msg}" ]]; then
		log "<7> \nAlert: ${alert_msg}"
		alert "[${disk}]" "DISK: ${disk}\n---\n${alert_msg}"
	fi
}