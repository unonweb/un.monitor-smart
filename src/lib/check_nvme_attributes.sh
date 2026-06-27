function check_nvme_attributes {
    local disk="${1}"
	local disk_name=$(basename "${disk}")
    local alert_msg=""

    # Dump NVMe SMART log to a temporary file
    local tmp_log="${TMP_DIR}/${disk_name}.log"
    smartctl --attributes "${disk}" > "${tmp_log}"

    # WARNINGS
	# ========
	# alert once per new warning

    local crit_warn=$(grep "Critical Warning:" "${tmp_log}" | awk '{print $3}')
    local prev_crit_warn=$(get_state "${disk_name}" "crit_warn")
    if [[ "${crit_warn}" != "0x00" ]] && [[ "${crit_warn}" != "${prev_crit_warn}" ]]; then
		
		local msg="Critical Warning: ${crit_warn}"
		alert_msg+="${msg}\n"
        set_state "${disk_name}" "crit_warn" "${crit_warn}"
    fi

    # SPARE
	# =====
	# Available Spare vs Threshold

    local avail_spare=$(grep "Available Spare:" "${tmp_log}" | grep -oE '[0-9]+' | head -n1)
    local spare_thresh=$(grep "Available Spare Threshold:" "${tmp_log}" | grep -oE '[0-9]+' | head -n1)
    if [[ -n "${avail_spare}" ]] && [[ -n "${spare_thresh}" ]]; then
        if (( avail_spare <= spare_thresh )); then
            local spare_alerted=$(get_state "${disk_name}" "spare_alerted")
            if [[ "${spare_alerted}" != "1" ]]; then
				
				local msg="MSG: Available spare on ${disk} has dropped to ${avail_spare}%, reaching/exceeding the threshold of ${spare_thresh}%."
				alert_msg+="${msg}\n"
                set_state "${disk_name}" "spare_alerted" "1"
            fi
        fi
    fi

    # ERRORS
	# ======
	# (Media and Data Integrity Errors)

    local errors=$(grep "Media and Data Integrity Errors:" "${tmp_log}" | awk '{print $6}' | tr -d ',')
    local prev_errors=$(get_state "${disk_name}" "errors")
    [[ -z "${prev_errors}" ]] && prev_errors=0
    if [[ -n "${errors}" ]] && (( errors > prev_errors )); then

		local msg="MSG: Media and Data Integrity Errors on ${disk} increased from ${prev_errors} to ${errors}."
		alert_msg+="${msg}\n"
        set_state "${disk_name}" "errors" "${errors}"
    fi

    # UNSAFE SHUTDOWNS
	# ================

    local unsafe=$(grep "Unsafe Shutdowns:" "${tmp_log}" | awk '{print $3}' | tr -d ',')
    local prev_unsafe=$(get_state "${disk_name}" "unsafe")
    [[ -z "${prev_unsafe}" ]] && prev_unsafe=0
    if [[ -n "${unsafe}" ]] && (( unsafe > prev_unsafe )); then

		local msg="Unsafe shutdowns on ${disk} increased from ${prev_unsafe} to ${unsafe}."
		alert_msg+="${msg}\n"
        set_state "${disk_name}" "unsafe" "${unsafe}"
    fi

    # TEMPERATUR
	# ==========
	# Monitor Temperature Times (Warning and Critical)

	local current_temp=$(grep "Temperature:" "${tmp_log}" | awk '{print $2}' | tr -d ',')
    local warn_temp_time=$(grep "Warning  Comp. Temperature Time:" "${tmp_log}" | awk '{print $5}' | tr -d ',')
    local crit_temp_time=$(grep "Critical Comp. Temperature Time:" "${tmp_log}" | awk '{print $5}' | tr -d ',')

	# Match digits at the start of the string
	if [[ "${current_temp}" =~ ^([0-9]+) ]]; then
		# BASH_REMATCH[1] contains the captured text 
		# (regex inside the first set of parentheses)
		current_temp_cleaned="${BASH_REMATCH[1]}"
	fi

	if [[ -z "${current_temp_cleaned}" ]]; then
		msg="ERROR: Could not get current_temp_cleaned from ${current_temp}"
		log "${msg}"
		debug "${msg}"
		continue
	fi

	# alert if temperature is above given threshold
	if (( 10#${current_temp} > 10#${SMART_CELSIUS_THRESH} )); then
		local msg="Temperature (${current_temp}) above given threshold of ${SMART_CELSIUS_THRESH}"
		alert_msg+="${msg}\n"
	fi

	# warn_temp_time
    local prev_warn_time=$(get_state "${disk_name}" "warn_temp_time")
    [[ -z "${prev_warn_time}" ]] && prev_warn_time=0
    if [[ -n "${warn_temp_time}" ]] && (( warn_temp_time > prev_warn_time )); then

		local msg="Warning Composite Temperature Time on ${disk} increased to ${warn_temp_time} minutes."
		alert_msg+="${msg}\n"
		set_state "${disk_name}" "warn_temp_time" "${warn_temp_time}"
    fi

	# crit_temp_time
    local prev_crit_time=$(get_state "${disk_name}" "crit_temp_time")
    [[ -z "${prev_crit_time}" ]] && prev_crit_time=0
    if [[ -n "${crit_temp_time}" ]] && (( crit_temp_time > prev_crit_time )); then

		local msg="Critical Composite Temperature Time on ${disk} increased to ${crit_temp_time} minutes."
		alert_msg+="${msg}\n"
		set_state "${disk_name}" "crit_temp_time" "${crit_temp_time}"
    fi

	# ALERT
	# =====
	
	if [[ -n "${alert_msg}" ]]; then
		debug "\nAlert: ${alert_msg}"
		alert "${alert_msg}"
	fi

    # DEBUG
	# =====

	debug "\
			avail_spare: ${avail_spare}\n\
			spare_thresh: ${spare_thresh}\n\
			errors: ${errors}\n\
			prev_errors: ${prev_errors}\n\
			unsafe: ${unsafe}\n\
			prev_unsafe: ${prev_unsafe}\n\
			current_temp: ${current_temp}\n\
			warn_temp_time: ${warn_temp_time}\n\
			crit_temp_time: ${crit_temp_time}\n\
			prev_crit_time: ${prev_crit_time}\n\
		"
}