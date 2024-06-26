#!/usr/bin/env bash
# Copyright 2019-2024 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

##############################################################################################################
# Validate several prerequisites for a seamless analysis:
#  - applications copied according to description in README.md
#  - tools distributions present in './dist'
#  - required Java version in use
##############################################################################################################

# ------ Do not modify
NEEDED_MIN_FREE_DISK_SPACE_IN_GB=20
RECOMMENDED_MIN_CONTAINER_ENGINE_MEMORY_IN_GB=15

ARE_PREREQUISITES_MET=true
IS_CONTAINER_ENGINE_CHECKED=false
export LOG_FILE=/dev/null

# Check container engine and load images
function check_container_engine() {
	IMAGE_NAME="${1}"
	IMAGE_FILE="${2}"
	IS_CONTAINER_ENGINE_RUNNING=true
	if [[ "${IS_CONTAINER_ENGINE_CHECKED}" == "false" ]]; then
		if [[ -z "$(command -v ${CONTAINER_ENGINE})" ]]; then
			if [[ "${CONTAINER_ENGINE}" == "docker" ]]; then
				if [[ "${IS_MAC}" == "true" ]]; then
					log_console_error "'docker' is not available. Please install it and start the docker daemon.
			[MacOS] Install docker (UI required) with brew and start its daemon
				$ brew install docker
				$ open /Applications/Docker.app"
				else
					log_console_error "'docker' is not available. Please install it and start the docker daemon.
			[CentoOS/RHEL/Fedora] Install docker and start its daemon
				$ sudo yum install -y yum-utils device-mapper-persistent-data lvm2
				$ sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
				$ sudo yum -y install docker-ce docker-ce-cli --nobest
				$ sudo groupadd docker
				$ sudo usermod -aG docker \${USER}
				$ sudo mkdir -p /etc/systemd/system/docker.service.d
				$ sudo systemctl start docker"
				fi
			elif [[ "${CONTAINER_ENGINE}" == "podman" ]]; then
				log_console_error "'${CONTAINER_ENGINE}' is not available. Please install it and start the '${CONTAINER_ENGINE}' container engine."
			fi
			IS_CONTAINER_ENGINE_RUNNING=false
		else
			# Check if the docker daemon is running
			set +e
			${CONTAINER_ENGINE} info >/dev/null 2>&1
			if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
				if [[ "${CONTAINER_ENGINE}" == "docker" ]]; then
					if [[ "${IS_MAC}" == "true" ]]; then
						log_console_error "The docker daemon is not running! Please start it ([MacOS] '$ open /Applications/Docker.app')."
					else
						log_console_error "The docker daemon is not running! Please start it ([CentoOS/RHEL/Fedora] '$ sudo systemctl start docker')."
					fi
				elif [[ "${CONTAINER_ENGINE}" == "podman" ]]; then
					if [[ "${IS_MAC}" == "true" ]]; then
						log_console_error "The podman machine is not running! Please start it ([MacOS] '$ podman machine stop; podman machine rm -f; podman machine init --cpus 8 --memory 16384 --disk-size 20 --rootful; podman machine start')."
					else
						log_console_error "The podman machine is not running! Please start it."
					fi
				fi
				IS_CONTAINER_ENGINE_RUNNING=false
			fi

			if [[ "${IS_CONTAINER_ENGINE_RUNNING}" == "true" ]]; then
				# Check memory limit
				CONTAINER_ENGINE_MEM_TOTAL=$(${CONTAINER_ENGINE} info --format '{{.MemTotal}}' | awk '{print $1/1024/1024/1024}')
				CONTAINER_ENGINE_MEM_TOTAL_IN_GB=${CONTAINER_ENGINE_MEM_TOTAL%.*}
				if ((CONTAINER_ENGINE_MEM_TOTAL_IN_GB < RECOMMENDED_MIN_CONTAINER_ENGINE_MEMORY_IN_GB)); then
					log_console_warning "Current container engine (${CONTAINER_ENGINE}) memory limit (${CONTAINER_ENGINE_MEM_TOTAL} GB) is beyond the recommended minimum (${RECOMMENDED_MIN_CONTAINER_ENGINE_MEMORY_IN_GB} GB). Please increase it to speed up analysis and prevent memory issues."
				fi
			fi
			set -e
		fi
		IS_CONTAINER_ENGINE_CHECKED=true
	fi

	if [ "${IS_CONTAINER_ENGINE_RUNNING}" = false ]; then
		ARE_PREREQUISITES_MET=false
	else
		if [[ -n "$(${CONTAINER_ENGINE} images -q "${IMAGE_NAME}")" ]]; then
			log_console_info "${CONTAINER_ENGINE} image available: '${IMAGE_NAME}'"
		else
			log_console_info "Importing '${IMAGE_NAME}' ${CONTAINER_ENGINE} image."
			if [[ -f "${IMAGE_FILE}" ]]; then
				set +e
				${CONTAINER_ENGINE} image load -i "${IMAGE_FILE}"
				RC=$?
				set -e
				if [[ ${RC} -ne 0 ]]; then
					log_console_error "Unable to import the ${CONTAINER_ENGINE} image ('${IMAGE_FILE}') in your local registry."
					ARE_PREREQUISITES_MET=false
				fi
			else
				log_console_error "Local ${CONTAINER_ENGINE} image file '${IMAGE_FILE}' not found! Download it running './audit download'"
				ARE_PREREQUISITES_MET=false
			fi
		fi
	fi
}

mkdir -p "${APP_DIR_IN}"

log_console_step "Check and import present applications (${APP_GROUP})"

# Handle "IMPORT_DIR" parameter
SKIP_APP_GROUP_ANALYSIS="false"
if [[ -n "${IMPORT_DIR}" ]]; then
	if [[ ! -d "${IMPORT_DIR}" ]]; then
		log_console_error "The specified application import directory ('${IMPORT_DIR}') does not exist."
		ARE_PREREQUISITES_MET=false
		SKIP_APP_GROUP_ANALYSIS=true
	else
		if [[ "${IMPORT_DIR}" = "${CURRENT_DIR}"* ]]; then
			log_console_error "The specified application import directory ('${IMPORT_DIR}') must not under the current dir ('${CURRENT_DIR}')."
			ARE_PREREQUISITES_MET=false
			SKIP_APP_GROUP_ANALYSIS=true
		else
			rm -Rf "${APP_DIR_IN:?}/${APP_GROUP}"
			# Detect if it is a single- or multiple-app directory
			if (find "${IMPORT_DIR}" -mindepth 1 -maxdepth 1 | rev | cut -d '/' -f 1 | rev | grep -q -i -E '^pom.xml$|^readme.md$|^license.md$|^\.git$|^target$|^\.svn$'); then
				log_console_info "Import a single application"
				# Single app in the import directory
				TARGET_DIR="${APP_DIR_IN}/${APP_GROUP}/"
			else
				log_console_info "Import multiple applications"
				# Multiple apps in the import directory
				TARGET_DIR="${APP_DIR_IN}/"
			fi
			mkdir -p "${TARGET_DIR}"
			cp -Rfp "${IMPORT_DIR}/../${APP_GROUP}" "${TARGET_DIR}."
		fi
	fi
fi

if [[ "${SKIP_APP_GROUP_ANALYSIS}" == "false" ]]; then
	if [[ "${APP_GROUP}" == "" ]]; then
		# All groups selected
		SELECTED_APP_DIR_IN="${APP_DIR_IN}"
		DEPTH=2
		COUNT_GROUPS=$(find "${APP_DIR_IN}" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' \t')
	else
		# Group selected
		SELECTED_APP_DIR_IN="${APP_DIR_IN}/${APP_GROUP}"
		DEPTH=1
		COUNT_GROUPS=1
		if ! find "${APP_DIR_IN}" -maxdepth 1 -mindepth 1 -type d | grep -q "${APP_GROUP}"; then
			SELECTED_APP_DIR_IN=""
		fi
	fi
	if [[ -d "${SELECTED_APP_DIR_IN}" ]]; then
		COUNT_SINGLE_APPS=$(find "${SELECTED_APP_DIR_IN}" -maxdepth ${DEPTH} -mindepth ${DEPTH} -type f -name '*.[ejgrhws]ar' -or -name '*.zip' | wc -l | tr -d ' \t')
		COUNT_EXPLODED_APPS=$(find "${SELECTED_APP_DIR_IN}" -maxdepth ${DEPTH} -mindepth ${DEPTH} -type d -not -name 'src' -not -name 'tmp' | wc -l | tr -d ' \t')
		COUNT_APPS=$((COUNT_SINGLE_APPS + COUNT_EXPLODED_APPS))
		if ((COUNT_APPS > 0)); then
			log_console "    [INFO] ${B}${COUNT_APPS} application(s)${N} found in ${B}${COUNT_GROUPS} group(s)${N}."
		else
			log_console_error "No application found. Please organize your applications as described in README.md."
			ARE_PREREQUISITES_MET=false
		fi
	else
		if [[ -f "${REPORTS_DIR}/00__Weave/list__all_apps.csv" ]]; then
			log_console_warning "Applications do not exist locally. Creating mock application group structure under '${APP_DIR_IN}/${APP_GROUP}'"
			mkdir -p "${APP_DIR_IN}/${APP_GROUP}"
			while read -r APP; do
				touch "${APP_DIR_IN}/${APP_GROUP}/${APP}"
			done < <(cut -d ',' -f 1 "${REPORTS_DIR}/00__Weave/list__all_apps.csv")
		else
			log_console_error "Specified application group ('${APP_GROUP}') not found. Please use the import option or organize your applications as described in README.md."
			ARE_PREREQUISITES_MET=false
		fi
	fi
fi

# Bash version validation
log_console_step "Check Bash version (>=4)"
MAJOR_BASH_VERSION=$(echo "${BASH_VERSION}" | cut -d . -f 1)
if ((MAJOR_BASH_VERSION < 4)); then
	INSTRUCTIONS=''
	if [[ "${IS_MAC}" == "true" ]]; then
		INSTRUCTIONS=" ('$ brew install bash' on MacOS)"
	fi
	log_console_error "You are running Bash '${BASH_VERSION}'. Please update it to version 4 or later.${INSTRUCTIONS}"
	ARE_PREREQUISITES_MET=false
else
	log_console_info "Compatible Bash version ('${BASH_VERSION}') in use."
fi

# Free disk space validation
log_console_step "Check free disk space (>=${NEEDED_MIN_FREE_DISK_SPACE_IN_GB}GB)"
declare AVAILABLE_FREE_GB
if [[ "${IS_MAC}" == "true" ]]; then
	AVAILABLE_FREE_GB=$(df -Pg . | tail -1 | awk '{print $4}')
else
	AVAILABLE_FREE_GB=$(df -BG -P . | tail -1 | awk '{print $4}' | tr -d 'G')
fi
if ((AVAILABLE_FREE_GB < NEEDED_MIN_FREE_DISK_SPACE_IN_GB)); then
	log_console_error "Less than ${NEEDED_MIN_FREE_DISK_SPACE_IN_GB}GB of free disk space available. Please free some more disk space."
	ARE_PREREQUISITES_MET=false
else
	log_console_info "${AVAILABLE_FREE_GB}GB disk space available."
fi

# Internet connectivity
log_console_step "Check internet connectivity"
set +e
if [[ -n "$(command -v ping)" ]]; then
	if ping -q -c 1 -W 1 dns.google.com >/dev/null; then
		log_console_info "Internet access detected."
	else
		log_console_warning "You have no Internet access. The identification of 3rd party libraries ('01__fernflower_decompile') and security vulnerabilties (05__owasp, 13_grype, 14_trivy) will be less effective."
	fi
else
	log_console_warning "'ping' is not available. Please install it to be able to check the Internet connectivity."
fi
set -e

# 01
if [[ "${DECOMPILE_SOURCE}" == "true" ]]; then
	log_console_step "Step 01 - Check Fernflower prerequisites"

	if [[ -z "$(command -v unzip)" || -z "$(command -v sha1sum)" || -z "$(command -v curl)" || -z "$(command -v jq)" ]]; then
		if [[ "${IS_MAC}" == "true" ]]; then
			log_console_error "'curl', 'jq', 'sha1sum', and 'unzip' are not all available.
	[MacOS] Installation with brew:
	$ brew install jq md5sha1sum unzip"
		else
			log_console_error "'curl', 'jq', 'sha1sum', and 'unzip' are not all available.
	[CentoOS/RHEL/Fedora] Installation with yum:
	$ sudo yum -y install jq curl unzip
	[Ubuntu] Installation with yum:
	$ sudo apt install jq curl unzip"
		fi
		ARE_PREREQUISITES_MET=false
	fi

	check_container_engine "${CONTAINER_IMAGE_NAME_FERNFLOWER}" "${DIST_DIR}/oci__fernflower_${FERNFLOWER_VERSION}.img"
fi

# 02
if [[ "${CSA_ACTIVE}" == "true" ]]; then
	log_console_step "Step 02 - Check CSA prerequisites"
	check_container_engine "${CONTAINER_IMAGE_NAME_CSA}" "${DIST_DIR}/oci__csa_${CSA_VERSION}.img"
	check_container_engine "${CONTAINER_IMAGE_NAME_CSA_BAGGER}" "${DIST_DIR}/oci__csa-bagger_${CSA_BAGGER_VERSION}.img"
fi

# 03
if [[ "${WINDUP_ACTIVE}" == "true" ]]; then
	log_console_step "Step 03 - Check Windup prerequisites"
	if [[ -z "$(command -v xmllint)" || -z "$(command -v xsltproc)" ]]; then
		log_console_error "'xmllint' and 'xsltproc' are not available. Please install them."
		ARE_PREREQUISITES_MET=false
	fi
	check_container_engine "${CONTAINER_IMAGE_NAME_WINDUP}" "${DIST_DIR}/oci__windup_${WINDUP_VERSION}.img"
	#if [[ -z "${WINDUP_INCLUDE_PACKAGES_FILE}" && -z "${WINDUP_EXCLUDE_PACKAGES_FILE}" ]]; then
	#	log_console_warning "Windup Analysis is active, but no list of packages to include/exclude has been set. It might take a long time to run."
	#fi
fi

# 04
if [[ "${WAMT_ACTIVE}" == "true" ]]; then
	log_console_step "Step 04 - Check WAMT prerequisites"
	check_container_engine "${CONTAINER_IMAGE_NAME_WAMT}" "${DIST_DIR}/oci__wamt_${WAMT_VERSION}.img"
fi

# 05
if [[ "${OWASP_ACTIVE}" == "true" ]]; then
	log_console_step "Step 05 - Check OWASP Dependency-Check prerequisites"
	check_container_engine "${CONTAINER_IMAGE_NAME_OWASP_DC}" "${DIST_DIR}/oci__owasp-dependency-check_${OWASP_DC_VERSION}.img"
fi

# 06
if [[ "${SCANCODE_ACTIVE}" == "true" ]]; then
	log_console_step "Step 06 - Check ScanCode prerequisites"
	check_container_engine "${CONTAINER_IMAGE_NAME_SCANCODE}" "${DIST_DIR}/oci__scancode-toolkit_${SCANCODE_VERSION}.img"
fi

# 07
if [[ "${PMD_ACTIVE}" == "true" ]]; then
	log_console_step "Step 07 - Check PMD prerequisites"
	check_container_engine "${CONTAINER_IMAGE_NAME_PMD}" "${DIST_DIR}/oci__pmd_${PMD_VERSION}.img"
fi

# 08
if [[ "${LANGUAGES_ACTIVE}" == "true" ]]; then
	log_console_step "Step 08 - Check Linguist prerequisites"
	check_container_engine "${CONTAINER_IMAGE_NAME_LINGUIST}" "${DIST_DIR}/oci__linguist_${LINGUIST_VERSION}.img"
	check_container_engine "${CONTAINER_IMAGE_NAME_CLOC}" "${DIST_DIR}/oci__cloc_${CLOC_VERSION}.img"
	# Check if git is present
	if [[ -z "$(command -v git)" ]]; then
		if [[ "${IS_MAC}" == "true" ]]; then
			log_console_error "'git' is not available. Please install it ([MacOS] '$ brew install git') or disable Linguist."
		else
			log_console_error "'git' is not available. Please install it ([CentoOS/RHEL/Fedora] '$ sudo yum -y install git') or disable Linguist."
		fi
		ARE_PREREQUISITES_MET=false
	fi
fi

# 09
if [[ "${FSB_ACTIVE}" == "true" ]]; then
	log_console_step "Step 09 - Check Find Security Bugs prerequisites"
	check_container_engine "${CONTAINER_IMAGE_NAME_FSB}" "${DIST_DIR}/oci__findsecbugs_${FSB_VERSION}.img"
	if [[ -z "$(command -v xmllint)" ]]; then
		log_console_error "'xmllint' is not available. Please install it."
		ARE_PREREQUISITES_MET=false
	fi
fi

# 10
if [[ "${MAI_ACTIVE}" == "true" ]]; then
	log_console_step "Step 10 - Check Microsoft Application Inspector (MAI) prerequisites"
	check_container_engine "${CONTAINER_IMAGE_NAME_MAI}" "${DIST_DIR}/oci__mai_${MAI_VERSION}.img"
fi

# 11
if [[ "${SLSCAN_ACTIVE}" == "true" ]]; then
	log_console_step "Step 11 - Check SAST-Scan prerequisites"
	check_container_engine "${CONTAINER_IMAGE_NAME_SLSCAN}" "${DIST_DIR}/oci__sast-scan_${SLSCAN_VERSION}.img"
fi

# 12
if [[ "${INSIDER_ACTIVE}" == "true" ]]; then
	log_console_step "Step 12 - Check Insider prerequisites"
	check_container_engine "${CONTAINER_IMAGE_NAME_INSIDER}" "${DIST_DIR}/oci__insider_${INSIDER_VERSION}.img"
fi

# 13
if [[ "${GRYPE_ACTIVE}" == "true" ]]; then
	log_console_step "Step 13 - Check Grype prerequisites"
	check_container_engine "${CONTAINER_IMAGE_NAME_GRYPE}" "${DIST_DIR}/oci__grype_${GRYPE_VERSION}.img"
	check_container_engine "${CONTAINER_IMAGE_NAME_SYFT}" "${DIST_DIR}/oci__syft_${SYFT_VERSION}.img"
fi

# 14
if [[ "${TRIVY_ACTIVE}" == "true" ]]; then
	log_console_step "Step 14 - Check Trivy prerequisites"
	check_container_engine "${CONTAINER_IMAGE_NAME_TRIVY}" "${DIST_DIR}/oci__trivy_${TRIVY_VERSION}.img"
fi

# 15
if [[ "${OSV_ACTIVE}" == "true" ]]; then
	log_console_step "Step 15 - Check OSV prerequisites"
	check_container_engine "${CONTAINER_IMAGE_NAME_SYFT}" "${DIST_DIR}/oci__syft_${SYFT_VERSION}.img"
	check_container_engine "${CONTAINER_IMAGE_NAME_OSV}" "${DIST_DIR}/oci__osv_${OSV_VERSION}.img"
fi

# 16
if [[ "${ARCHEO_ACTIVE}" == "true" ]]; then
	log_console_step "Step 16 - Check Archeo prerequisites"
	check_container_engine "${CONTAINER_IMAGE_NAME_SYFT}" "${DIST_DIR}/oci__syft_${SYFT_VERSION}.img"
fi

# 17
if [[ "${BEARER_ACTIVE}" == "true" ]]; then
	log_console_step "Step 17 - Check Bearer prerequisites"
	check_container_engine "${CONTAINER_IMAGE_NAME_BEARER}" "${DIST_DIR}/oci__bearer_${BEARER_VERSION}.img"
fi

# 99
if [[ -z "$(command -v zip)" ]]; then
	if [[ "${IS_MAC}" == "true" ]]; then
		log_console_error "'zip' is not available. Please install it!"
	else
		log_console_error "'zip' is not available. Please install it ([Ubuntu] '$ sudo apt install zip')."
	fi
fi

# Conclusion!
if [ "${ARE_PREREQUISITES_MET}" = false ]; then
	[[ "${DEBUG}" == "true" ]] && set -x
	echo ""
	log_console_error "prerequisites are not satisified. Please fix any errors, then re-run."
	exit 1
else
	log_console_success "All prerequisites are met to start the application analysis."
fi
