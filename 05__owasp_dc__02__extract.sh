#!/usr/bin/env bash
# Copyright 2019-2024 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

##############################################################################################################
# Extract key results from the report files generated by ...
#   "Open Web Application Security Project (OWASP) Dependency-Check" - https://www.owasp.org/index.php/OWASP_Dependency_Check
##############################################################################################################

# ----- Please adjust

# ------ Do not modify
VERSION=${OWASP_DC_VERSION}
STEP=$(get_step)
SEPARATOR=","
NUMBER_RE='^[0-9]+$'
APP_DIR_OUT="${REPORTS_DIR}/${STEP}__OWASP_DC"
RESULT_FILE="${APP_DIR_OUT}/_results_extracted.csv"
#RESULT_FILE_FULL="${APP_DIR_OUT}/_results_extracted_full.csv"
export LOG_FILE="${APP_DIR_OUT}.log"

function generate_csv() {

	echo "Applications${SEPARATOR}OWASP vulns" >"${RESULT_FILE}"
	#echo "Applications${SEPARATOR}OWASP Low vulns${SEPARATOR}OWASP Medium vulns${SEPARATOR}OWASP High vulns${SEPARATOR}OWASP Critical vulns${SEPARATOR}OWASP Total vuln libs" >"${RESULT_FILE_FULL}"

	while read -r FILE; do
		APP="$(basename "${FILE}")"
		log_extract_message "app '${APP}'"

		ODC_JSON_IN="${APP_DIR_OUT}/${APP}_dc_report.json"
		ODC_OUTPUT_STATS="${APP_DIR_OUT}/${APP}_dc_report.stats"

		if [ -f "${ODC_JSON_IN}" ]; then

			set +e
			# shellcheck disable=SC2126
			COUNT_VULN_LIBS=$(jq ".dependencies[].vulnerabilities | length" "${ODC_JSON_IN}" | grep -v '^0$' | wc -l | tr -d ' ')
			COUNT_ALL_LIBS=$(jq ".dependencies[].vulnerabilities | length" "${ODC_JSON_IN}" | wc -l | tr -d ' ')

			if [[ ${COUNT_ALL_LIBS} =~ ${NUMBER_RE} && ${COUNT_ALL_LIBS} -gt 0 ]]; then
				PERCENT_VULN_LIBS=$((100 * COUNT_VULN_LIBS / COUNT_ALL_LIBS))
			else
				PERCENT_VULN_LIBS=0
			fi

			declare -i COUNT_VULNS_LOW=0
			declare -i COUNT_VULNS_MEDIUM=0
			declare -i COUNT_VULNS_HIGH=0
			declare -i COUNT_VULNS_CRITICAL=0

			# Extract the CSVV2 and CVSS3 scores
			while read -r SCORES; do
				# Max of CVSS2 and CVSS3
				CVSS=$(echo "${SCORES}" | awk -F ' ' '{ print ($1 >= $2) ? $1 : $2 }')
				if [[ $(awk -v cvss="${CVSS}" 'BEGIN { print (cvss >= 9.0) ? "T" : "F" }') == "T" ]]; then
					COUNT_VULNS_CRITICAL=$((COUNT_VULNS_CRITICAL + 1))
				elif [[ $(awk -v cvss="${CVSS}" 'BEGIN { print (cvss >= 7.0) ? "T" : "F" }') == "T" ]]; then
					COUNT_VULNS_HIGH=$((COUNT_VULNS_HIGH + 1))
				elif [[ $(awk -v cvss="${CVSS}" 'BEGIN { print (cvss >= 4.0) ? "T" : "F" }') == "T" ]]; then
					COUNT_VULNS_MEDIUM=$((COUNT_VULNS_MEDIUM + 1))
				else
					COUNT_VULNS_LOW=$((COUNT_VULNS_LOW + 1))
				fi
			done < <(jq '.dependencies[]?.vulnerabilities[]? | "\(.cvssv3.baseScore) \(.cvssv2.score)"' "${ODC_JSON_IN}" | tr -d '"' | sed s/null/0/g)

			COUNT_VULNS_ALL=$((COUNT_VULNS_LOW + COUNT_VULNS_MEDIUM + COUNT_VULNS_HIGH + COUNT_VULNS_CRITICAL))

			echo "${APP}${SEPARATOR}${COUNT_VULNS_ALL}" >>"${RESULT_FILE}"
			#echo "${APP}${SEPARATOR}${COUNT_VULNS_LOW}${SEPARATOR}${COUNT_VULNS_MEDIUM}${SEPARATOR}${COUNT_VULNS_HIGH}${SEPARATOR}${COUNT_VULNS_CRITICAL}${SEPARATOR}${COUNT_VULN_LIBS}" >>"${RESULT_FILE_FULL}"

			if [[ "${TRIVY_ACTIVE}" == "true" ||
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
				echo "ODC__ALL_LIBS=${COUNT_ALL_LIBS}"
				echo "ODC__VULN_LIBS=${COUNT_VULN_LIBS}"
				echo "ODC__VULNS_ALL=${COUNT_VULNS_ALL}"
				echo "ODC__VULNS_LOW=${COUNT_VULNS_LOW}"
				echo "ODC__VULNS_MEDIUM=${COUNT_VULNS_MEDIUM}"
				echo "ODC__VULNS_HIGH=${COUNT_VULNS_HIGH}"
				echo "ODC__VULNS_CRITICAL=${COUNT_VULNS_CRITICAL}"
				echo "ODC__PERCENT_VULN_LIBS=${PERCENT_VULN_LIBS}"
				echo "HAS_ANOTHER_SECURITY_REPORT=${HAS_ANOTHER_SECURITY_REPORT}"
			} >"${ODC_OUTPUT_STATS}"

			set -e
		else
			echo "${APP}${SEPARATOR}n/a" >>"${RESULT_FILE}"
			#echo "${APP}${SEPARATOR}n/a${SEPARATOR}n/a${SEPARATOR}n/a${SEPARATOR}n/a${SEPARATOR}n/a" >>"${RESULT_FILE_FULL}"
		fi
	done <"${REPORTS_DIR}/00__Weave/list__all_apps.txt"

	log_console_success "Results: ${RESULT_FILE}"
}

function main() {
	if [[ -d "${APP_DIR_OUT}" ]]; then
		generate_csv
	else
		LOG_FILE=/dev/null
		log_console_error "OWASP result directory does not exist: ${APP_DIR_OUT}"
	fi
}

main
