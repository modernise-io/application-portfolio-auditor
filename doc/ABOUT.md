# About

## Features

This project consists of a set of utility shell scripts automating the analysis of many Java, .NET, Python, JavaScript ... applications by a set of tools. The scripts run on Linux / Unix / MacOS environments. Windows is not supported.

- **Comprehensive CLI**: The `audit` Command Line Interface (CLI) lowers the barriers to reliably analyze a large set of applications.

- **Hardened by default**: Systematically validates prerequisites and pre-configures analysis tools following best practices. All analysis tools used have been hardened for stability.

- **Wide variety of applications supported**: Covers most modern programming languages (Java, Python, .NET, NodeJS) and analyzes as well source as compiled binaries.

- **Combined intelligence:** Harnesses and combines insights of up to 17 free and open-source application analysis tools.

- **Portable results**: Exports reports as exploded directory, ZIP files, Kubernetes or Cloud-Foundry deployments.

- **Aggregated summaries**: Generates static HTML pages connecting all results to help you understand your portfolio from different perspectives such as:

    * Cloud-readiness ([Cloud Suitability Analyzer](https://github.com/vmware-tanzu/cloud-suitability-analyzer/) + [Windup](https://github.com/windup/windup) + [WAMT](https://www.ibm.com/support/pages/websphere-application-server-migration-toolkit))

    * Security ([OWASP Dependency-Check](https://www.owasp.org/index.php/OWASP_Dependency_Check) + [Find Security Bugs](https://find-sec-bugs.github.io/) + [Insider SAST](https://github.com/insidersec/insider) + [ShiftLeft SAST Scan](https://github.com/ShiftLeftSecurity/sast-scan) + [Syft](https://github.com/anchore/syft) + [Grype](https://github.com/anchore/grype) + [Trivy](https://github.com/aquasecurity/trivy) + [OSV](https://github.com/google/osv.dev) + [Bearer](https://github.com/Bearer/bearer)) 

    * Quality ([PMD](https://pmd.github.io/) + [ScanCode Toolkit](https://github.com/nexB/scancode-toolkit) +  [Microsoft Application Inspector](https://github.com/Microsoft/ApplicationInspector) +  [Archeologist](https://github.com/vmware-tanzu/application-portfolio-auditor))

    * Distribution of languages ([GitHub Linguist](https://github.com/github/linguist) + [CLOC](https://github.com/AlDanial/cloc))

## Usage

To view the full CLI usage, execute: `./audit -h`

### Commands

Application Portfolio Auditor supports the following commands: `audit [setup|check|download|package|run] <options>`

Here is a brief description of each command:
* `audit setup`: Download and install all required prerequisites
* `audit check`: Check available updates for all used components and analysis tools
* `audit download`: Download, prepare and update all used components and analysis tools
* `audit package`: Package all scripts, used components and analysis tools into a portable zip distribution
* `audit run <options>`: Run application analysis with a wide variety of options.

### Examples

* `$ ./audit -h`: Provide **h**elp by showing all available CLI options.
* `$ ./audit run -a -g small`: Decompile and run **a**ll analyzers (CSA, Windup, WAMT, OWASP DC, FSB, Linguist, CLOC, Scancode, PMD, MAI, Insider, Syft, Grype, Trivy, OSV, Archeologist, Bearer) on the apps in the `small` **g**roup (subfolder of `apps` -> `apps/small`)
* `$ ./audit run -a -d /my/apps`: Import, decompile, and run **a**ll tools to analyze only the apps in the `/my/apps` **d**irectory.
* `$ ./audit -c -w -o -g small` or `$ ./audit -cwo -g small` : Decompile and run **C**SA, **W**indup, and **O**WASP DC to analyze all apps in the `apps/small` folder.

## Structure

Application Portfolio Auditor is mainly implemented in [Bash](https://www.gnu.org/software/bash/), [Mustache](https://mustache.github.io/), [Python](https://www.python.org/), and leverages [Containers](https://opencontainers.org/).

### Scripts

The starting point for any execution of Application Portfolio Auditor is the `audit` script. `_shared_functions.sh` bundles common functions used by the other scripts. `_versions.sh` lists all versions of the tools and frameworks in use.

`audit` calls dynamically `XX__NAME.sh` scripts in increasing order:

* `00__check_prereqs.sh`: Check that the prerequisites to run the tools are met. 
* `00__weave_execution_plan.sh`: Identify application types, generate tool execution plans.
* `01__fernflower_decompile.sh`: Recursively unpack apps and decompiles relevant libraries using Fernflower.
* `01__unpack_sources.sh`: Unpack zipped application code and copy source code folders.
* `02__csa__01__analysis.sh`: Analysis of all applications using Cloud Suitability Analyzer (CSA).
* `02__csa__02__extract.sh`: Extract the Cloud Suitability Analyzer (CSA) results to a CSV file.
* `03__windup__01__package_discovery.sh`: Analysis of all Java binary applications to discover the used package using Windup.
* `03__windup__02__analysis.sh`: Analysis of all Java binary applications using Windup.
* `03__windup__03__extract.sh`: Extract the Windup analysis results to a CSV file.
* `04__wamt__01__analysis.sh`: Analysis of all Java binary applications using WAMT.
* `04__wamt__02__extract.sh`: Extract the WAMT results to a CSV file.
* `05__owasp_dc__01__analysis.sh`: Analysis of all applications using OWASP Dependency-Check.
* `05__owasp_dc__02__extract.sh`: Extract the OWASP Dependency-Check analysis results to a CSV file.
* `06__scancode__01__analysis.sh`: Analysis of all applications using ScanCode Toolkit.
* `06__scancode__02__extract.sh`: Extract the ScanCode analysis results to a CSV file.
* `07__pmd__01__analysis.sh`: Analysis of all Java applications using PMD source code analyzer.
* `07__pmd__02__extract.sh`: Extract the PMD results to a CSV file.
* `08__linguist_and_cloc__01__analysis.sh`: Identification of the used languages using CLOC and GitHub Linguist.
* `08__linguist_and_cloc__02__extract.sh`: Extract the language analysis results.
* `09__findsecbugs__01__analysis.sh`: Analysis of all Java applications using Find Security Bugs.
* `09__findsecbugs__02__extract.sh`: Extract the Find Security Bugs analysis results to a CSV file.
* `10__mai__analysis.sh`: Analysis of all applications using Microsoft Application Inspector.
* `10__mai__extract.sh`: Extract insights from the Microsoft Application Inspector analysis.
* `11__slscan__analysis.sh`: Analysis of all applications using ShiftLeft SAST-Scan.
* `11__slscan__extract.sh`: Extract the ShiftLeft SAST-Scan analysis results to a CSV file.
* `12__insider__analysis.sh`: Analysis of all applications using Insider SAST.
* `12__insider__extract.sh`: Extract the Insider SAST analysis results to a CSV file.
* `13__grype__analysis.sh`: Analysis of all applications using Syft and Grype.
* `13__grype__extract.sh`: Extract the Grype analysis results to a CSV file.
* `14__trivy__analysis.sh`: Analysis of all applications using Trivy.
* `14__trivy__extract.sh`: Extract the Trivy analysis results to a CSV file.
* `15__osv__analysis.sh`: Analysis of all applications using OSV.
* `15__osv__extract.sh`: Extract the OSV analysis results to a CSV file.
* `16__archeo__analysis.sh`: Analysis of all applications using Archeologist.
* `16__archeo__extract.sh`: Extract the Archeologist analysis results to a CSV file.
* `17__bearer__analysis.sh`: Analysis of all applications using Bearer.
* `17__bearer__extract.sh`: Extract the Bearer analysis results to a CSV file.
* `97__generate_reports.sh`: Generate HTML reports linking all generated results.
* `98__generate_timeline.sh`: Generate a timeline of the analysis.
* `99__package_reports.sh`: Package resulting reports as a zip file, cloud-foundry or Kubernetes deployment.


### Sub-directories

* `apps`: Contains all applications to be analyzed. Apps have to be grouped in subfolders or imported using the "-d" or "--import-dir" option. Subfolders are analyzed separately.

Example:
```
apps
├── group-1
│   ├── app1.ear
│   ├── app2.war
│   └── app3.zip
└── group-2
    ├── app4.jar
    └── app5_dir
```

* `bin`: Contains all unpacked and configured analysis tools.
* `conf`: Contains the configuration for every tool in use.
* `dist`: Contains the downloaded software distributions to install the tools.
* `reports`:  Centralises all reports and results generated by the analysis tools.
* `util`: Contains utility scripts to update and cleanup tools and scripts.


## Reports

Example of a plain-default report:

```
reports
└── 2024_03_08__09_54_49__medium
    ├── 00__Weave
    ├── 00__Weave.log
    ├── 01__Fernflower
    ├── 01__Fernflower.log
    ├── 02__CSA
    ├── 02__CSA.log
    ├── 03__WINDUP
    ├── 03__WINDUP.log
    ├── 03__WINDUP__packages
    ├── 03__WINDUP__packages.log
    ├── 04__WAMT
    ├── 04__WAMT.log
    ├── 05__OWASP_DC
    ├── 05__OWASP_DC.log
    ├── 06__SCANCODE
    ├── 06__SCANCODE.log
    ├── 07__PMD
    ├── 07__PMD.log
    ├── 08__LINGUIST
    ├── 08__LINGUIST.log
    ├── 09__FindSecBugs
    ├── 09__FindSecBugs.log
    ├── 10__MAI
    ├── 10__MAI.log
    ├── 12__INSIDER
    ├── 12__INSIDER.log
    ├── 13__GRYPE
    ├── 13__GRYPE.log
    ├── 14__TRIVY
    ├── 14__TRIVY.log
    ├── 15__OSV
    ├── 15__OSV.log
    ├── 16__ARCHEO
    ├── 16__ARCHEO.log
    ├── 17__BEARER
    ├── 17__BEARER.log
    ├── 98__timeline.log
    ├── Audit__2024_03_08__09_54_49__all__results.csv
    ├── cloud.html
    ├── index.html                      <== Starting point to explore the results !
    ├── info_rules.html
    ├── info.html
    ├── languages.html
    ├── launch_csa_ui.sh                <== Script to start the CSA UI
    ├── quality.html
    ├── run.log
    ├── security.html
    └── static
```
