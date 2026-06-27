function debug {
    local message="${1}"
    
    if ((DEBUG)); then 
		echo -e "${message}"
	fi
}