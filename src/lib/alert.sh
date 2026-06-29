function alert {
    local subject="${1}"
    local message="${2}"

	if (( ALERT_MAIL )); then

		if [[ -z "${ALERT_MAIL_TO}" ]]; then
			log "<3> Required var not set: ALERT_MAIL_TO"
			return 1
		else
			log "<6> Sending Mail-Alert to ${ALERT_MAIL_TO}"

			echo -e "${message}" | \
			mail -s "${ALERT_MAIL_SUBJECT} ${subject}" "${ALERT_MAIL_TO}" \
			&& log "<5> Mail-Alert sent to ${ALERT_MAIL_TO}" \
			&& return 0
		fi
	fi
}