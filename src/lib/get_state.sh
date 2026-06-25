function get_state {
    local disk="${1}"
	local key="${2}"
    local state_file="${STATE_DIR}/${disk}/${key}"
	
    if [[ -f "${state_file}" ]]; then
        cat "${state_file}"
    else
        echo ""
    fi
}