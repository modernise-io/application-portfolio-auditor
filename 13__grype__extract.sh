#!/usr/bin/env bash
# Copyright 2019-2023 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

##############################################################################################################
# Extract key results from the reports generated by ...
#   "Grype" & "Syft" - https://anchore.com/opensource/
##############################################################################################################

# ----- Please adjust

# ------ Do not modify
STEP=$(get_step)
SEPARATOR=","

function generate_csv() {
	APP_DIR_INCOMING=${1}
	GROUP=$(basename "${APP_DIR_INCOMING}")
	APP_DIR_OUT="${REPORTS_DIR}/${STEP}__GRYPE__${GROUP}"
	RESULT_FILE="${APP_DIR_OUT}/results_extracted.csv"

	if [[ ! -d "${APP_DIR_OUT}" ]]; then
		LOG_FILE=/dev/null
		log_console_error "Grype result directory does not exist: ${APP_DIR_OUT}"
		exit
	fi

	export LOG_FILE=${REPORTS_DIR}/${STEP}__GRYPE.log
	log_extract_message "group '${GROUP}'"

	rm -f "${RESULT_FILE}"
	echo "Applications${SEPARATOR}Grype vulns" >>"${RESULT_FILE}"

	while read -r APP; do
		APP_NAME="$(basename "${APP}")"
		log_extract_message "app '${APP_NAME}'"
		GRYPE_OUTPUT="${APP_DIR_OUT}/${APP_NAME}_grype.csv"
		COUNT_VULNS="n/a"
		if [ -f "${GRYPE_OUTPUT}" ]; then
			COUNT_VULNS=$(wc -l <(tail -n +2 "${GRYPE_OUTPUT}") | tr -d ' ' | cut -d'/' -f 1)
		fi
		echo "${APP_NAME}${SEPARATOR}${COUNT_VULNS}" >>"${RESULT_FILE}"

	done <"${REPORTS_DIR}/list__${GROUP}__all_apps.txt"

	log_console_success "Results: ${RESULT_FILE}"
}

function main() {
	for_each_group generate_csv
}

main