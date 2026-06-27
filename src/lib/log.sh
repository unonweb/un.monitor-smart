function log {
    local message="${1}"
    
    # Log the alert locally as well
	echo "$(date '+%Y-%m-%d %H:%M:%S') - ${message}" >> "${ERROR_LOG_FILE}"
}