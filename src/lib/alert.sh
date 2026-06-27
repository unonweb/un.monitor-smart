function alert {
    local message="${1}"

    if ((ALERT_MAIL)); then
		echo "Sending Mail-Alert to ${ALERT_MAIL_TO}"

		echo -e "${message}" | \
		mail -s "${ALERT_MAIL_SUBJECT}" "${ALERT_MAIL_TO}"
	fi

	if ((ALERT_LOG)); then
		# Log the alert locally as well
		echo "$(date '+%Y-%m-%d %H:%M:%S') - ALERT: ${message}" >> "${ALERT_LOG_FILE}"
	fi
}