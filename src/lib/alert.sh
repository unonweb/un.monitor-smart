function alert {
    local subject="${1}"
    local message="${2}"

    if ((ALERT_MAIL)); then
		echo "Sending Mail-Alert to ${ALERT_MAIL_TO}"

		echo -e "${message}" | \
		mail -s "${ALERT_MAIL_SUBJECT} ${subject}" "${ALERT_MAIL_TO}"
	fi
}