#!/usr/bin/env bash
# Copyright 2019-2024 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

##############################################################################################################
# Extract key results from the reports generated by ...
#   "Trivy" - https://trivy.dev/
##############################################################################################################

# ----- Please adjust

# ------ Do not modify
VERSION=${TRIVY_VERSION}
STEP=$(get_step)
SEPARATOR=","
NUMBER_RE='^[0-9]+$'
APP_DIR_OUT="${REPORTS_DIR}/${STEP}__TRIVY"
RESULT_FILE="${APP_DIR_OUT}/_results_extracted.csv"
export LOG_FILE="${APP_DIR_OUT}.log"
APP_LIST="${REPORTS_DIR}/00__Weave/list__all_apps.txt"

function generate_csv() {
	echo "Applications${SEPARATOR}Trivy vulns" >"${RESULT_FILE}"
	while read -r APP; do
		APP_NAME="$(basename "${APP}")"
		log_extract_message "app '${APP_NAME}'"
		TRIVY_OUTPUT="${APP_DIR_OUT}/${APP_NAME}_trivy.csv"
		TRIVY_OUTPUT_STATS="${APP_DIR_OUT}/${APP_NAME}_trivy.stats"
		COUNT_VULNS_ALL="n/a"
		if [ -f "${TRIVY_OUTPUT}" ]; then
			set +e
			COUNT_ALL_LIBS="$(wc -l <(grep "${APP_NAME}" "${LOG_FILE}" | grep "Parsing " | grep -v '"'"${APP_NAME}"'"') | tr -d ' ' | cut -d'/' -f 1)"
			COUNT_VULNS_ALL=$(wc -l <(tail -n +2 "${TRIVY_OUTPUT}") | tr -d ' ' | cut -d'/' -f 1)
			COUNT_VULN_LIBS="$(wc -l <(tail -n +2 "${TRIVY_OUTPUT}" | cut -d',' -f 1 -f 4 | sort | uniq) | tr -d ' ' | cut -d'/' -f 1)"
			COUNT_VULNS_LOW=$(wc -l <(tail -n +2 "${TRIVY_OUTPUT}" | grep '"LOW"') | tr -d ' ' | cut -d'/' -f 1)
			COUNT_VULNS_MEDIUM=$(wc -l <(tail -n +2 "${TRIVY_OUTPUT}" | grep '"MEDIUM"') | tr -d ' ' | cut -d'/' -f 1)
			COUNT_VULNS_HIGH=$(wc -l <(tail -n +2 "${TRIVY_OUTPUT}" | grep '"HIGH"') | tr -d ' ' | cut -d'/' -f 1)
			COUNT_VULNS_CRITICAL=$(wc -l <(tail -n +2 "${TRIVY_OUTPUT}" | grep '"CRITICAL"') | tr -d ' ' | cut -d'/' -f 1)
			if [[ ${COUNT_ALL_LIBS} =~ ${NUMBER_RE} && ${COUNT_ALL_LIBS} -gt 0 ]]; then
				PERCENT_VULN_LIBS=$((100 * COUNT_VULN_LIBS / COUNT_ALL_LIBS))
			else
				PERCENT_VULN_LIBS=0
			fi
			if [[ "${OWASP_ACTIVE}" == "true" ||
				"${SCANCODE_ACTIVE}" == "true" ||
				"${FSB_ACTIVE}" == "true" ||
				"${SLSCAN_ACTIVE}" == "true" ||
				"${INSIDER_ACTIVE}" == "true" ||
				"${GRYPE_ACTIVE}" == "true" ||
				"${OSV_ACTIVE}" == "true" ||
				"${BEARER_ACTIVE}" == "true" ]]; then
				HAS_ANOTHER_SECURITY_REPORT='TRUE'
			else
				HAS_ANOTHER_SECURITY_REPORT=''
			fi
			{
				echo "TRIVY__ALL_LIBS=${COUNT_ALL_LIBS}"
				echo "TRIVY__VULN_LIBS=${COUNT_VULN_LIBS}"
				echo "TRIVY__VULNS_ALL=${COUNT_VULNS_ALL}"
				echo "TRIVY__VULNS_LOW=${COUNT_VULNS_LOW}"
				echo "TRIVY__VULNS_MEDIUM=${COUNT_VULNS_MEDIUM}"
				echo "TRIVY__VULNS_HIGH=${COUNT_VULNS_HIGH}"
				echo "TRIVY__VULNS_CRITICAL=${COUNT_VULNS_CRITICAL}"
				echo "TRIVY__PERCENT_VULN_LIBS=${PERCENT_VULN_LIBS}"
				echo "HAS_ANOTHER_SECURITY_REPORT=${HAS_ANOTHER_SECURITY_REPORT}"
			} >"${TRIVY_OUTPUT_STATS}"
			set -e
		fi
		echo "${APP_NAME}${SEPARATOR}${COUNT_VULNS_ALL}" >>"${RESULT_FILE}"
	done <"${APP_LIST}"
	log_console_success "Results: ${RESULT_FILE}"
}

function main() {
	if [[ -d "${APP_DIR_OUT}" ]]; then
		generate_csv
	else
		LOG_FILE=/dev/null
		log_console_error "Trivy result directory does not exist: ${APP_DIR_OUT}"
	fi
}

main
