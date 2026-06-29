#!/usr/bin/bash

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE}")"
SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_NAME=$(basename -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_PARENT=$(dirname "${SCRIPT_DIR}")

APP_NAME="${SCRIPT_PARENT##*/}"

PATH_CONFIG="${SCRIPT_PARENT}/config.cfg"
PATH_DEFAULTS="${SCRIPT_PARENT}/defaults.cfg"

# IMPORTS
source "${SCRIPT_DIR}/lib/is_str_in_arr.sh"
source "${SCRIPT_DIR}/lib/alert.sh"
source "${SCRIPT_DIR}/lib/log.sh"
source "${SCRIPT_DIR}/lib/check_nvme_attributes.sh"
source "${SCRIPT_DIR}/lib/check_sata.sh"
source "${SCRIPT_DIR}/lib/set_state.sh"
source "${SCRIPT_DIR}/lib/get_state.sh"
source "${SCRIPT_DIR}/lib/get_mounted_disks.sh"

function main {

	if [ "${UID}" -ne 0 ]; then
  		echo "This script must be run as root."
  		exit 1
	fi

	# CONFIG & DEFAULTS
	if [[ -r ${PATH_CONFIG} ]]; then
		source "${PATH_CONFIG}"
	else
		echo "No config file found at ${PATH_CONFIG}. Using defaults ..."
		source "${PATH_DEFAULTS}"
	fi

	# Ensure required directory exist
	mkdir -p "${STATE_DIR}"
	mkdir -p "${TMP_DIR}"
	mkdir -p "${LOG_DIR}"

	# Detect mounted disks
	DISKS=$(get_mounted_disks)

	# Iterate through disks
	for disk in ${DISKS}; do

		if [[ "${SMART_INCLUDE_DISKS}" != "all" ]] && ! is_str_in_arr "${disk}" "${SMART_INCLUDE_DISKS[@]}"; then
			log "<7> ---\nDisk: ${disk}\nSkipping\n---"
			continue
		else
			log "<7> ---\nDisk: ${disk}\n---"
		fi

		# Skip if we don't have read permissions to the disk
		if [[ ! -r "${disk}" ]]; then
			log "<3> Can't read ${disk}. Skipping."
			continue
		fi

		# NVME
		if [[ "${disk}" == /dev/nvme* ]]; then	
			# NVMe drives generally do not hide behind USB bridges that require -d flags; 
        	# NVMe-to-USB enclosures usually present as standard SCSI/SATA devices (/dev/sd*)
			check_nvme_attributes "${disk}"
		# SATA
		elif [[ "${disk}" == /dev/sd* ]]; then
			local smart_args=""
        
			# Check if the transport type is USB
			transport=$(lsblk -nd -o TRAN "${disk}" 2>/dev/null | tr -d '[:space:]')
			
			if [[ "${transport}" == "usb" ]]; then
				usb_supported=false
				
				# Common USB bridge types: empty (auto), sat (SCSI-to-ATA), plus specific legacy chips
				# https://manpages.debian.org/trixie/smartmontools/smartctl.8.en.html#d
				device_types=("" "sat" "sat,12" "usbprolific" "usbcypress" "usbsunplus" "usbinitio" "sntrealtek")
				
				for type in "${device_types[@]}"; do
					# Test the option. If it prints SMART info without failing, we found the right chip.
					if smartctl --info --device ${type} "${disk}" 2>/dev/null | grep -qi "SMART support is:.*Enabled"; then
						smart_args+=" --device ${type}"
						usb_supported=true
						break
					fi
				done
				
				# If no flag worked, log an error and skip the disk to avoid spam
				if [[ "${usb_supported}" == false ]]; then
					log "<3> Cannot read SMART data for USB disk ${disk}. Bridge chip may be unsupported."
					continue
				fi
			fi

			# Pass the disk and the discovered smart arguments
        	check_sata "${disk}" "${smart_args}"
		else
			# Log or ignore unknown block devices
			log "<5> Unrecognized base device type for ${disk}, skipping."
		fi
	done
}

main