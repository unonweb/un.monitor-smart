# NOTES
# =====
# 0: Emergency, 1: Alert, 2: Critical, 3: Error, 4: Warning, 5: Notice, 6: Info, 7: Debug

# REQUIRES
# ========
# - LOG_FILE
# - LOG_TO_FILE
# - LOG_TO_CONSOLE
# - LOG_LVL

function log {

    local message="${1}"
	local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
	
	# Regex pattern that captures two groups:
	# <number>
	# message
    if [[ "${message}" =~ ^\<([0-7])\>[[:space:]]*(.*) ]]; then
        local msg_lvl="${BASH_REMATCH[1]}"
        local msg_only="${BASH_REMATCH[2]}"
    fi
	# Check msg_lvl
	# If not specified default to log, too
	if (( msg_lvl <= LOG_LVL )) || [[ -z ${msg_lvl} ]]; then

		# Log to file
		if (( LOG_TO_FILE )); then
			echo -e "${timestamp} [LVL ${msg_lvl}] ${msg_only}" >> "${LOG_FILE}"
		fi

		# Log to console
		if (( LOG_TO_CONSOLE )); then
			if [ -n "${INVOCATION_ID}" ]; then
				# Script is running inside a systemd service
				# Log original message
				echo -e "${message}"
			else
				# No systemd service around
				# Log clean message
				echo -e "${msg_only}"
			fi
		fi
	fi
}