function alert {
    local subject="${1}"
    local message="${2}"

    if ((SEND_MAIL)); then
		echo "Sending Mail-Alert to ${EMAIL_TO}"

		echo -e "${message}" | \
		mail -s "${MAIL_SUBJECT}${subject}" "${EMAIL_TO}"
	fi

	if ((LOG_TO_FILE)); then
		# Log the alert locally as well
		echo "$(date '+%Y-%m-%d %H:%M:%S') - ALERT: ${subject}" >> "${ALERT_LOG}"
	fi
}