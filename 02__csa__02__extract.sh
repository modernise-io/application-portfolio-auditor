#!/usr/bin/env bash
# Copyright 2019-2023 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

##############################################################################################################
# Extract key results from the database file generated by ...
#	"Cloud Suitability Analyzer" - https://github.com/vmware-tanzu/cloud-suitability-analyzer
##############################################################################################################

STEP=$(get_step)
SEPARATOR=","
S="${SEPARATOR}"
APP_DIR_OUT="${REPORTS_DIR}/${STEP}__CSA"
DB_LOCATION="${APP_DIR_OUT}/csa.db"
MISSING_FILE="${APP_DIR_OUT}__results_missing.csv"
RESULT_BAGGER_FILE="${APP_DIR_OUT}__results_extracted_bagger.csv"
RESULT_FILE="${APP_DIR_OUT}__results_extracted.csv"
BAGGER_DB_TMP="${APP_DIR_OUT}/tmp"
JAVA_OPTS_TMP=-Djava.io.tmpdir="${BAGGER_DB_TMP}"
export LOG_FILE=/dev/null

function check_missing_apps() {
	GROUP_DIR=${1}
	GROUP=$(basename "${GROUP_DIR}")

	log_extract_message "group '${GROUP}'"

	while read -r FILE; do
		APP="$(basename "${FILE}")"
		if [[ -f "${RESULT_BAGGER_FILE}" ]]; then
			if ! grep -q "${GROUP}${S}${APP}${S}" "${RESULT_BAGGER_FILE}"; then
				echo "${GROUP}${S}${APP}${S}${APP}${S}n/a${S}${S}${S}${S}${S}${S}${S}${S}${S}${S}${S}${S}${S}${S}${S}${S}${S}" >>"${MISSING_FILE}"
			fi
		else
			echo "${GROUP}${S}${APP}${S}${APP}${S}n/a${S}${S}${S}${S}${S}${S}${S}${S}${S}${S}${S}${S}${S}${S}${S}${S}${S}" >>"${MISSING_FILE}"
		fi
	done <"${REPORTS_DIR}/list__${GROUP}__all_apps.txt"
}

function main() {
	# Extract results using bagger
	rm -f "${RESULT_BAGGER_FILE}"
	if [[ -f "${DB_LOCATION}" ]]; then
		# Creating "BAGGER_DB_TMP" directory to avoid issues with default tmpdir (https://stackoverflow.com/questions/25389290/sqlite-java-lang-unsatisfiedlinkerror-in-linux)
		rm -Rf "${BAGGER_DB_TMP}"
		mkdir -p "${BAGGER_DB_TMP}"
		set +e
		java "${JAVA_OPTS_TMP}" -jar "${INSTALL_DIR}"/bagger__${JAVA_VERSION}.jar "${DB_LOCATION}" "${RESULT_BAGGER_FILE}" "${S}"
		set -e
		rm -Rf "${BAGGER_DB_TMP}"
	else
		log_console_error "CSA database file does not exist: ${DB_LOCATION}"
		exit
	fi

	# Check missing entries
	rm -f "${MISSING_FILE}"
	for_each_group check_missing_apps

	# Add missing entries
	touch "${RESULT_BAGGER_FILE}" "${MISSING_FILE}"
	cat "${RESULT_BAGGER_FILE}" "${MISSING_FILE}" | sort | uniq >"${RESULT_FILE}"
}

main