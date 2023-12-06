#!/usr/bin/env bash
# Copyright 2019-2023 VMware, Inc.
# SPDX-License-Identifier: Apache-2.0

##############################################################################################################
# Library tracking versions of all used tools and frameworks.
##############################################################################################################

# Current version of Application Portfolio Auditor
export TOOL_VERSION='2.0.6'

# Java version used for Bagger and Fernflower
export JAVA_VERSION='20'

# List of the versions for all tools in use.

# Migration & cloud readiness
#export WINDUP_VERSION='6.3.0' - Visualization of new version is a step back.
export WINDUP_VERSION='6.1.11'
export CSA_VERSION='4.1.11'
export WAMT_VERSION='23.0.0.5'

# Languages
export LINGUIST_VERSION='7.27.0'
export CLOC_VERSION='1.98'

# License & Authors
export SCANCODE_VERSION='32.0.8'

# Code quality / bugs
export MAI_VERSION='1.9.16'
export PMD_VERSION='6.55.0'
export JQA_VERSION='1.8.0'
export SCC_VERSION='2.12.0'

# Security
export PMD_GDS_VERSION='2.33.0'
export OWASP_DC_VERSION='8.4.3'
export FSB_VERSION='1.12.0'
export SLSCAN_VERSION='2.1.1'
export INSIDER_VERSION='3.0.0'
export TRIVY_VERSION='0.47.0'
export SYFT_VERSION='0.98.0'
export GRYPE_VERSION='0.73.4'

# Other
export DONET_RUNTIME_VERSION="8.0.0-alpine3.18"
export MUSTACHE_VERSION="3.0.4"
export NGINX_VERSION="1.25.3"
export NIST_MIRROR_VERSION="1.6.0"
export D3_VERSION="7.8.5"
export JQUERY_VERSION="3.7.1"
export BOOTSTRAP_VERSION="5.3.2"
export BOOTSTRAP_ICONS_VERSION="1.11.2"
export TIMELINES_CHART_VERSION="2.12.1"
