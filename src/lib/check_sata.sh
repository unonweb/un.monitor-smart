function check_sata {

    local disk="${1}"
	local smart_args="${2}"
    local disk_name=$(basename "${disk}")
    local tmp_log_attributes="${TMP_DIR}/${disk_name}.log"

	# IMPORTS
	# =======
	source "${SCRIPT_DIR}/lib/check_sata_attributes_format_old.sh"
	source "${SCRIPT_DIR}/lib/check_sata_test_results.sh"

	# Dump SMART data
	# (Attributes and Self-Test logs) to a tmp file
    smartctl --attributes ${smart_args} "${disk}" > "${tmp_log_attributes}"

    # PARSE SMART ATTRIBUTES
	# ======================
    # Grep lines that start with a number (these are the attribute rows)

	# CHECK --format=old
    check_sata_attributes_format_old "${tmp_log_attributes}"

	# PARSE TEST RESULTS
	# ==================
    # Monitor new test results for errors

    # check_sata_test_results "${tmp_log_test_results}"
}