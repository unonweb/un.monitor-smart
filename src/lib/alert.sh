function alert {
    local subject="${1}"
    local message="${2}"

    if ((ALERT_MAIL)); then
		echo "Sending Mail-Alert to ${ALERT_MAIL_TO}"

		echo -e "${message}" | \
		mail -s "${ALERT_MAIL_SUBJECT_PREFIX}${subject}" "${ALERT_MAIL_TO}"
	fi

	if ((ALERT_LOG)); then
		# Log the alert locally as well
		echo "$(date '+%Y-%m-%d %H:%M:%S') - ALERT: ${subject}" >> "${ALERT_LOG_FILE}"
	fi
}