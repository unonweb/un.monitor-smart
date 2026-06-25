function set_state {
	local disk="${1}"
    local key="${2}"
    local value="${3}"
	
	mkdir --parent "${STATE_DIR}/${disk}"
    echo "${value}" > "${STATE_DIR}/${disk}/${key}"
}