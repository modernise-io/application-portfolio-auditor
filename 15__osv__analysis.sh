#!/usr/bin/env bash
# Copyright 2019-2024 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

##############################################################################################################
# Analyze all applications in ${APP_DIR_IN} grouped in sub-folders using ...
#   "OSV" - https://osv.dev/
#
# "OSV" is a distributed vulnerability database for Open Source.
##############################################################################################################

# ----- Please adjust

# ------ Do not modify
VERSION=${OSV_VERSION}
STEP=$(get_step)
BASE_DIR="${REPORTS_DIR}/${STEP}__OSV"
export LOG_FILE="${BASE_DIR}.log"
export OUT_DIR_SYFT="${BASE_DIR}"
export OUT_DIR_OSV="${BASE_DIR}"
APP_LIST="${REPORTS_DIR}/00__Weave/list__all_init_apps.txt"

# Analyze all applications present in provided list.
function analyze() {

	if [[ -s "${APP_LIST}" ]]; then
		while read -r APP; do
			APP_NAME=$(basename "${APP}")
			APP_FOLDER=$(dirname "${APP}")
			log_analysis_message "app '${APP_NAME}'"

			set +e

			PREFIX=""
			if [[ -f "${APP}" ]]; then
				PREFIX="file"
			elif [[ -d "${APP}" ]]; then
				PREFIX="dir"
			fi

			APP_NAME_SHORT="${APP_NAME}"
			if [[ "${APP_NAME}" == *\.zip ]]; then
				APP_NAME_SHORT="${APP_NAME%.*}"
			fi

			RESULT_JSON="${APP_NAME_SHORT}_syft_spdx.json"
			if [[ -z "${PREFIX}" ]]; then
				log_console_error "Invalid application: '${APP}'"
			else
				## Run -Syft- to generate SBOM
				${CONTAINER_ENGINE} run ${CONTAINER_ENGINE_ARG} \
					-v "${APP_FOLDER}:/src" -v "${OUT_DIR_SYFT}:/out" \
					-e SYFT_CHECK_FOR_APP_UPDATE=false \
					"${CONTAINER_IMAGE_NAME_SYFT}" \
					"${PREFIX}:/src/${APP_NAME}" -o "spdx-json=/out/${RESULT_JSON}" 2>>"${LOG_FILE}"
			fi

			RESULT_FILE_SYFT="${OUT_DIR_SYFT}/${RESULT_JSON}"
			# Check if SBOM is not empty
			if [[ -f "${RESULT_FILE_SYFT}" ]] && [[ -s "${RESULT_FILE_SYFT}" ]]; then
				## Run -OSV- using the -Syft- output file
				${CONTAINER_ENGINE} run ${CONTAINER_ENGINE_ARG} --rm \
					-v "${OUT_DIR_SYFT}:/src:delegated" \
					-v "${OUT_DIR_OSV}:/out:delegated" \
					--name OSV "${CONTAINER_IMAGE_NAME_OSV}" \
					--sbom="/src/${RESULT_JSON}" \
					--format json --output "/out/${APP_NAME_SHORT}_osv.json" 2>>"${LOG_FILE}"

				${CONTAINER_ENGINE} run ${CONTAINER_ENGINE_ARG} --rm \
					-v "${OUT_DIR_SYFT}:/src:delegated" \
					-v "${OUT_DIR_OSV}:/out:delegated" \
					--name OSV "${CONTAINER_IMAGE_NAME_OSV}" \
					--sbom=/src/${RESULT_JSON} \
					--format table --output /out/${APP_NAME_SHORT}_osv.txt 2>>"${LOG_FILE}"

				RESULT_FILE_OSV_JSON="${OUT_DIR_OSV}/${APP_NAME_SHORT}_osv.json"
				RESULT_FILE_OSV_CSV="${OUT_DIR_OSV}/${APP_NAME_SHORT}_osv.csv"
				echo 'Library,Version,Vulnerability,Severity, Summary, Details' >"${RESULT_FILE_OSV_CSV}"
				#jq -r '.results[].packages[] | .package as $pkg | .vulnerabilities[] | [$pkg.name, $pkg.version, $pkg.ecosystem, .id, (.summary | gsub("\n"; "")), (.details | gsub("\n"; "")), .severity[0].score] | @csv' "${OUT_DIR_OSV}/${APP_NAME_SHORT}.json" >> "${OUT_DIR_OSV}/${APP_NAME_SHORT}.csv"
				jq -r '.results[].packages[] | .package as $pkg | .vulnerabilities[] | [ ($pkg.name | split(":") | .[0]), $pkg.version, .id, .database_specific.severity, (.summary | gsub("\n"; "")), (.details | gsub("\n"; ""))] | @csv' "${RESULT_FILE_OSV_JSON}" >>"${RESULT_FILE_OSV_CSV}"
				stream_edit 's/"MODERATE"/"Medium"/g' "${RESULT_FILE_OSV_CSV}"
				stream_edit 's/"LOW"/"Low"/g' "${RESULT_FILE_OSV_CSV}"
				stream_edit 's/"HIGH"/"High"/g' "${RESULT_FILE_OSV_CSV}"
				stream_edit 's/"CRITICAL"/"Critical"/g' "${RESULT_FILE_OSV_CSV}"
			fi
			set -e
		done <"${APP_LIST}"
	fi
}

function main() {
	log_tool_info "Syft v${SYFT_VERSION}"
	log_tool_info "OSV v${VERSION}"
	if [[ -n $(${CONTAINER_ENGINE} images -q "${CONTAINER_IMAGE_NAME_SYFT}") ]]; then
		if [[ -n $(${CONTAINER_ENGINE} images -q "${CONTAINER_IMAGE_NAME_OSV}") ]]; then
			# Analyze all applications present in the ${APP_GROUP_DIR} directory.
			check_debug_mode
			mkdir -p "${OUT_DIR_SYFT}" "${OUT_DIR_OSV}"
			analyze
			log_console_success "Open this directory for the results: ${OUT_DIR_OSV}"
		else
			log_console_error "OSV analysis canceled. Container image unavailable: '${CONTAINER_IMAGE_NAME_OSV}'"
		fi
	else
		log_console_error "OSV analysis canceled. Container image unavailable: '${CONTAINER_IMAGE_NAME_SYFT}'"
	fi
}

main
