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
        local clean_msg="${BASH_REMATCH[2]}"
        
        # Only log if the message level is less than or equal to the global LOG_LVL
        if (( msg_lvl <= LOG_LVL )); then
            # Log to file
			if (( LOG_TO_FILE )); then
            	echo "${timestamp} [LVL ${msg_lvl}] ${clean_msg}" >> "${LOG_FILE}"
			fi
			if (( LOG_TO_CONSOLE )); then
				echo "${message}"
			fi
        fi
    else
        # Fallback if someone forgets to include <num> (defaults to printing it)
        if (( LOG_TO_FILE )); then
			echo "${timestamp} [LVL ${msg_lvl}] ${clean_msg}" >> "${LOG_FILE}"
		fi
		if (( LOG_TO_CONSOLE )); then
			echo "${message}"
		fi
    fi
}