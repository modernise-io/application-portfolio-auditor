#!/usr/bin/env bash
# Copyright 2019-2024 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

##############################################################################################################
# Extract warnings counts from the reports generated by ...
#   "Find Security Bugs" - https://find-sec-bugs.github.io/
##############################################################################################################

# ------ Do not modify
VERSION=${FSB_VERSION}
STEP=$(get_step)
SEPARATOR=","
APP_DIR_OUT="${REPORTS_DIR}/${STEP}__FindSecBugs"
RESULT_FILE="${APP_DIR_OUT}/_results_extracted.csv"
export LOG_FILE="${APP_DIR_OUT}".log
LIST_JAVA_BIN="${REPORTS_DIR}/00__Weave/list__java-bin.txt"

function generate_csv() {
	if [[ -s "${LIST_JAVA_BIN}" ]]; then
		#RESULT_FILE_FULL="${APP_DIR_OUT}/_results_extracted_full.csv"
		echo "Applications${SEPARATOR}FSB Bugs" >"${RESULT_FILE}"
		#echo "Applications${SEPARATOR}FSB Low Bugs${SEPARATOR}FSB Medium Bugs${SEPARATOR}FSB High Bugs${SEPARATOR}FSB Total Bugs" >"${RESULT_FILE_FULL}"
		while read -r APP_FILE; do
			APP="$(basename "${APP_FILE}")"
			FILE="${APP_DIR_OUT}/${APP}_fsb.html"
			FSB_OUTPUT_STATS="${APP_DIR_OUT}/${APP}.stats"

			COUNT_ISSUES_HIGH=''
			COUNT_ISSUES_MEDIUM=''
			COUNT_ISSUES_LOW=''
			if [[ -f "${FILE}" ]]; then
				set +e
				if [[ -s "${FILE}" ]]; then
					# Tough cleanup to prevent issues with xmllint
					TMP_FILE="${FILE}.tmp"
					echo "<html><body>" >"${TMP_FILE}"
					sed -n '/<table width="500" cellpadding="5" cellspacing="2">*/,/<\/table>/p' "${FILE}" >>"${TMP_FILE}"
					echo "</body></html>" >>"${TMP_FILE}"
					COUNT_ISSUES_HIGH=$(xmllint --xpath 'string(/html/body/table[1]/tr[2]/td[2])' "${TMP_FILE}" | tr -d '\n' | tr -d ' ')
					COUNT_ISSUES_MEDIUM=$(xmllint --xpath 'string(/html/body/table[1]/tr[3]/td[2])' "${TMP_FILE}" | tr -d '\n' | tr -d ' ')
					COUNT_ISSUES_LOW=$(xmllint --xpath 'string(/html/body/table[1]/tr[4]/td[2])' "${TMP_FILE}" | tr -d '\n' | tr -d ' ')
					rm -f "${TMP_FILE}"
				fi
				[[ -z "${COUNT_ISSUES_HIGH}" || -e "${COUNT_ISSUES_HIGH}" ]] && COUNT_ISSUES_HIGH=0
				[[ -z "${COUNT_ISSUES_MEDIUM}" || -e "${COUNT_ISSUES_MEDIUM}" ]] && COUNT_ISSUES_MEDIUM=0
				[[ -z "${COUNT_ISSUES_LOW}" || -e "${COUNT_ISSUES_LOW}" ]] && COUNT_ISSUES_LOW=0
				COUNT_ISSUES_ALL=$((COUNT_ISSUES_HIGH + COUNT_ISSUES_MEDIUM + COUNT_ISSUES_LOW))
				echo "${APP}${SEPARATOR}${COUNT_ISSUES_ALL##*( )}" >>"${RESULT_FILE}"

				if [[ "${OWASP_ACTIVE}" == "true" ||
					"${SCANCODE_ACTIVE}" == "true" ||
					"${TRIVY_ACTIVE}" == "true" ||
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
					echo "FSB__ISSUES_ALL=${COUNT_ISSUES_ALL}"
					echo "FSB__ISSUES_LOW=${COUNT_ISSUES_LOW}"
					echo "FSB__ISSUES_MEDIUM=${COUNT_ISSUES_MEDIUM}"
					echo "FSB__ISSUES_HIGH=${COUNT_ISSUES_HIGH}"
					echo "HAS_ANOTHER_SECURITY_REPORT=${HAS_ANOTHER_SECURITY_REPORT}"
				} >"${FSB_OUTPUT_STATS}"
				set -e
				#echo "${APP}${SEPARATOR}${COUNT_LOW}${SEPARATOR}${COUNT_MED}${SEPARATOR}${COUNT_HIGH}${SEPARATOR}${COUNT_TOTAL##*( )}" >>"${RESULT_FILE_FULL}"
			else
				echo "${APP}${SEPARATOR}n/a" >>"${RESULT_FILE}"
				#echo "${APP}${SEPARATOR}n/a${SEPARATOR}n/a${SEPARATOR}n/a${SEPARATOR}n/a" >>"${RESULT_FILE_FULL}"
			fi
		done <"${REPORTS_DIR}/00__Weave/list__all_apps.txt"
		log_console_success "Results: ${RESULT_FILE}"
	else
		log_console_warning "No binary Java application found. Skipping FindSecBug analysis result extraction."
	fi
}

function main() {
	if [[ -d "${APP_DIR_OUT}" ]]; then
		generate_csv
	else
		log_console_error "FindSecBugs missing directory: ${APP_DIR_OUT}"
	fi
}

main
