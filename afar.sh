#!/bin/bash

set -e

OPTIND=1
CUCKOO_RUNNING="FALSE"
REMNUX_RUNNING="FALSE"
WINDOWS_RUNNING="FALSE"
# shellcheck source=/dev/null
{ [ -e ~/.cert-config.cfg ] && . ~/.cert-config.cfg; } || { [ -e config.cfg ] && . config.cfg; }

function show_help {
    echo "    $0 [-h] [-v] [-o] [-w] [-c config] [-C] [-R] [-W] [-Z] file1 ... fileN"
    echo "        -c config       Load config file. Default is config.cfg."
    echo "        -h              Show help"
    echo "        -o              Open summary when done"
    echo "        -p              Paus before stopping and deleting VM"
    echo "        -r              Run report generation again and exit"
    echo "        -v              Verbose"
    echo "        -w              Start Windows directly"
    echo "        -Z              Remove WORKDIR without questions"
    echo "        -C              Don't use Cuckoo"
    echo "        -R              Don't use REMnux"
    echo "        -W              Don't use Windows"
}

while getopts "vc:h?oprwCRWZ" opt; do
	case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    o)  OPEN_BROWSER=1
        ;;
    p)  PAUSE=1
        ;;
    r)  REPORT_ONLY=1
        ;;
    v)  VERBOSE=1
        echo "Verbose logging."
        ;;
    w)  USE_WINDOWS=1
        ;;
    c)  CONFIG=$OPTARG
		[[ ! -e $CONFIG ]] && echo "Config file $CONFIG does not exists!." && exit 1
        # shellcheck source=/dev/null
		. $CONFIG
        ;;
    Z)  [[ -z $WORKDIR ]] && echo "No WORKDIR." && show_help && exit 1
        [ ! -z "$VERBOSE" ] && echo -n "Clean old WORKDIR."
        rm -rf "$WORKDIR"
        [ ! -z "$VERBOSE" ] && echo " Done."
        ;;
    C)  unset CUCKOO
        ;;
    R)  unset REMNUX
        ;;
    W)  unset WINDOWS
        ;;
    esac
done

shift $((OPTIND-1))
[ "$1" = "--" ] && shift

# Check for config (only one value)
[ -z "$WORKDIR" ] && echo "No config found. Default is config.cfg or add -c <path>" && exit 1
# Check environment
[ -z "$REPORT_ONLY" ] && [ $# == 0 ] && echo "Need a zip file as argument." && exit 1
[ -z "$REPORT_ONLY" ] && [ ! -f "$1" ] && echo "No file to analyze found (checked first only)." && exit 1
[ -z "$REPORT_ONLY" ] && [ ! -z "$CUCKOO" ] && [ -d "$CUCKOO_CLONE_DIR" ] && echo "The directory $CUCKOO_CLONE_DIR exists. Remove it and run the script again." && exit 1
[ -z "$REPORT_ONLY" ] && [ ! -z "$REMNUX" ] && [ -d "$REMNUX_CLONE_DIR" ] && echo "The directory $REMNUX_CLONE_DIR exists. Remove it and run the script again." && exit 1
[ -z "$REPORT_ONLY" ] && [ ! -z "$WINDOWS" ] && [ -d "$WINDOWS_CLONE_DIR" ] && echo "The directory $WINDOWS_CLONE_DIR exists. Remove it and run the script again." && exit 1
[ -z "$REPORT_ONLY" ] && [ -d "$WORKDIR" ] && echo "Report and workdir 'work' exists. Remove it and run the script again." && exit 1
[ -z "$REPORT_ONLY" ] && mkdir -p "$WORKDIR"

# Start scripts
function startVM {
    [ ! -z "$CUCKOO" ] && start_cuckoo || echo "No Cuckoo client configured."
    [ ! -z "$REMNUX" ] && start_remnux || echo "No Remnux client configured."
    [ ! -z $USE_WINDOWS ] && start_windows
    return 0
}

function wait_for_linux {
    [ ! -z "$REMNUX" ] && echo -n "Wait for REMnux."
    [ ! -z "$REMNUX" ] && vmrun -T fusion getGuestIPAddress "$REMNUX_CLONE" -wait > /dev/null
    [ ! -z "$REMNUX" ] && echo " Done."
    [ ! -z "$CUCKOO" ] && echo -n "Wait for Cuckoo."
    [ ! -z "$CUCKOO" ] && vmrun -T fusion getGuestIPAddress "$CUCKOO_CLONE" -wait > /dev/null
    [ ! -z "$CUCKOO" ] && echo " Done."
    return 0
}

function copy_to_linux_submit_cuckoo {
    for virus in $WORKDIR/*/2_file/*; do
        nr=$(echo "$virus" | sed -e 's!/2_file/.*!!' | sed -e 's!.*/!!')
        [ -e "$WORKDIR/$nr/6_duplicate" ] && echo "Duplicate. Next" && continue
        virus_file="$(basename "$virus")"
        VM_VIRUS_FILE="/tmp/virus/$nr/$virus_file"
        [[ ! -d "$WORKDIR/$nr" ]] && mkdir "$WORKDIR/$nr"

        # Copy file to VM
        [[ ! -z "$CUCKOO" ]] && echo -n "Copy script for Cuckoo submit."
        [[ ! -z "$CUCKOO" ]] && vmrun -gu "$CU" -gp "$CP" -T fusion CopyFileFromHostToGuest "$CUCKOO_CLONE" "scripts/submit.sh" "/tmp/submit.sh"
        [[ ! -z "$CUCKOO" ]] && echo " Done."
        [[ ! -z "$CUCKOO" ]] && echo -n "Copy $virus to Cuckoo."
        [[ ! -z "$CUCKOO" ]] && vmrun -gu "$CU" -gp "$CP" -T fusion createDirectoryInGuest "$CUCKOO_CLONE" "/tmp/virus/$nr"
        [[ ! -z "$CUCKOO" ]] && vmrun -gu "$CU" -gp "$CP" -T fusion CopyFileFromHostToGuest "$CUCKOO_CLONE" "$virus" "$VM_VIRUS_FILE"
        [[ ! -z "$CUCKOO" ]] && echo -n " Submit $VM_VIRUS_FILE to Cuckoo."
        [[ ! -z "$CUCKOO" ]] && vmrun -gu "$CU" -gp "$CP" -T fusion runProgramInGuest "$CUCKOO_CLONE" /bin/bash /tmp/submit.sh "$VM_VIRUS_FILE"
        [[ ! -z "$CUCKOO" ]] && echo " Done."
        [[ ! -z "$REMNUX" ]] && echo -n "Copy $virus to REMnux.."
        [[ ! -z "$REMNUX" ]] && vmrun -gu "$RU" -gp "$RP" -T fusion createDirectoryInGuest "$REMNUX_CLONE" "/tmp/virus/$nr"
        [[ ! -z "$REMNUX" ]] && vmrun -gu "$RU" -gp "$RP" -T fusion CopyFileFromHostToGuest "$REMNUX_CLONE" "$virus" "$VM_VIRUS_FILE"
        [[ ! -z "$REMNUX" ]] && echo " Done."
    done
    return 0
}

function analyze_in_remnux_windows {
    for virus in $WORKDIR/*/2_file/*; do
        nr=$(echo "$virus" | sed -e 's!/2_file/.*!!' | sed -e 's!.*/!!')
        [ -e "$WORKDIR/$nr/6_duplicate" ] && echo "Duplicate. Next" && continue
        filetype="$(file -b "$virus")"
        filetypeshort=$(file -b "$virus" | awk '{print $1}')
        virus_file="$(basename "$virus")"
        VM_VIRUS_FILE="/tmp/virus/$nr/$virus_file"

        # Run script for all files
        run_script_in_remnux "all"

        if echo "$filetypeshort" | grep -E "(autorun.ini)" > /dev/null ; then
            # Autorun
            submit_to_cuckoo "Autorun" "autorun"
            continue
        elif echo "$filetypeshort" | grep -E "(HTML|ASCII)" > /dev/null ; then
            # HTML and ASCII
            submit_to_cuckoo "HTML or ASCII" "html_or_ascii"
            continue
        elif echo "$filetype" | grep -E "MS Windows shortcut" > /dev/null ; then
            # LNK file
            run_program_in_windows "lnk"
            [[ -e $WORKDIR/$nr/lnk.txt ]] && [[ -e /usr/local/bin/dos2unix ]] && \
                /usr/local/bin/dos2unix "$WORKDIR/$nr/lnk.txt" > /dev/null 2>&1
            LNK_FILE=("$WORKDIR/$nr/20"*".json")
            [ -e "${LNK_FILE[0]}" ] && mv "$WORKDIR/$nr/20"*".json" "$WORKDIR/$nr/LECmd.json"
        elif echo "$filetypeshort" | grep -E "(PDF)" > /dev/null ; then
            # PDF file
            run_script_in_remnux "pdf"
        elif echo "$filetypeshort" | grep -E "(PE32)" > /dev/null ; then
            # PE32 file
            run_script_in_remnux "pe32"
        elif echo "$filetypeshort" | grep -E "(Zip)" > /dev/null && unzip -o -P "" -l "$virus" | grep -E "docProps/" > /dev/null ; then
            # Word file
            run_script_in_remnux "word"
        elif echo "$filetypeshort" | grep -E "(Zip)" > /dev/null ; then
            # Regular zip
            submit_to_cuckoo "Zip" "zip"
        elif echo "$filetypeshort" | grep -E "(CDF)" > /dev/null ; then
        # Word file - CDF
            run_script_in_remnux "word"
        else
            touch "$WORKDIR/$nr/1_unhandled"
        fi
    done
    return 0
}

# Shutdown scripts
function shutdownCuckoo {
    VM_RUNNING=$(vmrun -T fusion list | head -1 | awk '{print $4}')
    VM_TARGET=$((VM_RUNNING - 1))
    echo -n "Stop Cuckoo clone."
    vmrun -T fusion stop "$CUCKOO_CLONE" hard
    echo -n " Wait."
    until [[ $(vmrun -T fusion list | head -1 | awk '{print $4}') == "$VM_TARGET" ]] ; do
        sleep 1
    done
    sleep 5
    echo -n " Delete it."
    vmrun -T fusion deleteVM "$CUCKOO_CLONE"
    echo " Done."
    CUCKOO_RUNNING="FALSE"
}

function shutdownRemnux {
    VM_RUNNING=$(vmrun -T fusion list | head -1 | awk '{print $4}')
    VM_TARGET=$((VM_RUNNING - 1))
    echo -n "Stop REMnux clone."
    vmrun -T fusion stop "$REMNUX_CLONE" hard
    echo -n " Wait."
    until [[ $(vmrun -T fusion list | head -1 | awk '{print $4}') == "$VM_TARGET" ]] ; do
        sleep 1
    done
    sleep 5
    echo -n " Delete it."
    vmrun -T fusion deleteVM "$REMNUX_CLONE"
    echo " Done."
    REMNUX_RUNNING="FALSE"
}

function shutdownWindows {
    VM_RUNNING=$(vmrun -T fusion list | head -1 | awk '{print $4}')
    VM_TARGET=$((VM_RUNNING - 1))
    echo -n "Stop Windows clone."
    vmrun -T fusion stop "$WINDOWS_CLONE" hard
    echo -n " Wait."
    until [[ $(vmrun -T fusion list | head -1 | awk '{print $4}') == "$VM_TARGET" ]] ; do
        sleep 1
    done
    sleep 5
    echo -n " Delete it."
    vmrun -T fusion deleteVM "$WINDOWS_CLONE" hard
    echo " Done."
    WINDOWS_RUNNING="FALSE"
}

function shutdownVM {
    [ $CUCKOO_RUNNING == "TRUE" ] && shutdownCuckoo
    [ $REMNUX_RUNNING == "TRUE" ] && shutdownRemnux
    [ $WINDOWS_RUNNING == "TRUE" ] && shutdownWindows
    exit 0
}

function submit_to_cuckoo {
    if [[ -z $CUCKOO ]]; then
        echo "No Cuckoo client available."
    else
        # Start Cucko clone and install tools if not running.
        [[ $CUCKOO_RUNNING == "FALSE" ]] && start_cuckoo
        echo "Filetype: $1" >> "$WORKDIR/$nr/0_report.txt"
        echo "Only run in Cuckoo" >> "$WORKDIR/$nr/0_report.txt"
        touch "$WORKDIR/$nr/1_$2"
    fi
    return 0
}

function run_script_in_remnux {
    [ -z "$REMNUX" ] && return
    [[ $1 != "all" ]] && echo "Filetype is: $1" >> "$WORKDIR/$nr/0_report.txt"
    [[ $1 != "all" ]] && echo -n "Run $1 script on $VM_VIRUS_FILE in REMnux."
    vmrun -gu "$RU" -gp "$RP" -T fusion CopyFileFromHostToGuest "$REMNUX_CLONE" "scripts/$1.sh" "/tmp/$1.sh"
    vmrun -gu "$RU" -gp "$RP" -T fusiolon runProgramInGuest "$REMNUX_CLONE" /bin/bash "/tmp/$1.sh" "$VM_VIRUS_FILE"
    [[ $1 != "all" ]] && echo -n "Retrieve report."
    vmrun -gu "$RU" -gp "$RP" -T fusion CopyFileFromGuestToHost "$REMNUX_CLONE" "/tmp/$1_report.zip" "$WORKDIR/$nr/$1_report.zip"
    [[ $1 != "all" ]] && echo " Done."
    ( cd "$WORKDIR/$nr" && unzip "$1_report.zip" > /dev/null && rm -f "$1_report.zip" )
    [[ $1 != "all" ]] && touch "$WORKDIR/$nr/1_$1"
    return 0
}

function start_cuckoo {
    : ${CUCKOO_SNAPSHOT:="$(vmrun -T fusion listSnapshots "$CUCKOO" | tail -1)"}
    echo -n "Cuckoo: clone using '$CUCKOO_SNAPSHOT'."
    vmrun -T fusion clone "$CUCKOO" "$CUCKOO_CLONE" linked -snapshot="$CUCKOO_SNAPSHOT" -cloneName="CUCKOO_Clone" || \
        (echo "" && echo "Failed to clone Cuckoo" && exit 1)
    echo -n " Start clone."
    vmrun -T fusion start "$CUCKOO_CLONE" nogui > /dev/null
    echo " Done."
    CUCKOO_RUNNING="TRUE"
}

function start_remnux {
    : ${REMNUX_SNAPSHOT:="$(vmrun -T fusion listSnapshots "$REMNUX" | tail -1)"}
    echo -n "REMnux: clone using '$REMNUX_SNAPSHOT'."
    vmrun -T fusion clone "$REMNUX" "$REMNUX_CLONE" linked -snapshot="$REMNUX_SNAPSHOT" -cloneName="REMNUX_Clone" || \
        (echo "" && echo "Failed to clone Cuckoo" && exit 1)
    echo -n " Start clone."
    vmrun -T fusion start "$REMNUX_CLONE" nogui > /dev/null
    echo " Done."
    REMNUX_RUNNING="TRUE"
}

function start_windows {
    : ${WINDOWS_SNAPSHOT:="$(vmrun -T fusion listSnapshots "$WINDOWS" | tail -1)"}
    echo -n "Windows: clone using $CUCKOO_SNAPSHOT."
    vmrun -T fusion clone "$WINDOWS" "$WINDOWS_CLONE" linked -snapshot="$WINDOWS_SNAPSHOT" -cloneName="Windows_clone"
    echo -n " Start clone."
    vmrun -T fusion start "$WINDOWS_CLONE" nogui > /dev/null
    echo -n " Wait for boot."
    WINDOWS_IP=$(vmrun -T fusion getGuestIPAddress "$WINDOWS_CLONE" -wait)
    [ ! -z  $VERBOSE ] && echo -n " Windows ip: $WINDOWS_IP."
    echo " Done."
    if ! vmrun -gu "$WU" -gp "$WP" -T fusion directoryExistsInGuest "$WINDOWS_CLONE" "c:\\Run" > /dev/null ; then
        echo -n "Create default directory structure under c:\\Run iand copy files."
        vmrun -gu "$WU" -gp "$WP" -T fusion createDirectoryInGuest "$WINDOWS_CLONE" "c:\\Run"
        vmrun -gu "$WU" -gp "$WP" -T fusion createDirectoryInGuest "$WINDOWS_CLONE" "c:\\Run\\Report"
        vmrun -gu "$WU" -gp "$WP" -T fusion createDirectoryInGuest "$WINDOWS_CLONE" "c:\\Run\\Virus"
        for exe in exe/*; do
            vmrun -gu "$WU" -gp "$WP" -T fusion CopyFileFromHostToGuest "$WINDOWS_CLONE" "$exe" "c:\\Run\\$(basename "$exe")"
        done
        echo " Done."
    fi
    WINDOWS_RUNNING="TRUE"
}

function post_start_cuckoo {
    echo -n "Start Cuckoo Sandbox and Suricata."
    vmrun -gu "$CU" -gp "$CP" -T fusion runProgramInGuest "$CUCKOO_CLONE" /bin/bash /home/cuckoo/cuckoo-tools/bin/start.sh
    echo -n " Copy script for Cuckoo API."
    vmrun -gu "$CU" -gp "$CP" -T fusion CopyFileFromHostToGuest "$CUCKOO_CLONE" "scripts/api_start.sh" "/tmp/api_start.sh"
    echo -n " Start it."
    vmrun -gu "$CU" -gp "$CP" -T fusion runProgramInGuest "$CUCKOO_CLONE" /bin/bash /tmp/api_start.sh
    echo " Done."
    if ! vmrun -gu "$CU" -gp "$CP" -T fusion directoryExistsInGuest "$CUCKOO_CLONE" "/tmp/virus" > /dev/null ; then
        echo -n "Create default /tmp/virus in Cuckoo."
        vmrun -gu "$CU" -gp "$CP" -T fusion createDirectoryInGuest "$CUCKOO_CLONE" "/tmp/virus"
        echo " Done."
    fi
    return 0
}

function post_start_remnux {
    if ! vmrun -gu "$RU" -gp "$RP" -T fusion directoryExistsInGuest "$REMNUX_CLONE" "/tmp/virus" > /dev/null ; then
        echo -n "Create default /tmp/virus in REMnux."
        vmrun -gu "$RU" -gp "$RP" -T fusion createDirectoryInGuest "$REMNUX_CLONE" "/tmp/virus"
        echo " Done."
    fi
    return 0
}

function run_program_in_windows {
    if [[ -z $WINDOWS ]]; then
        echo "No Windows client available."
    else
        # Start Windows clone and install tools if not running.
        [[ $WINDOWS_RUNNING == "FALSE" ]] && start_windows
        echo "Filetype is: $1" >> "$WORKDIR/$nr/0_report.txt"
        echo -n "Windows: $1.ps1. Copy script."
        vmrun -gu "$WU" -gp "$WP" -T fusion CopyFileFromHostToGuest "$WINDOWS_CLONE" "scripts/$1.ps1" "c:\\Run\\$1.ps1"
        echo -n " Copy $virus."
        vmrun -gu "$WU" -gp "$WP" -T fusion CopyFileFromHostToGuest "$WINDOWS_CLONE" "$virus" "c:\\Run\\Virus\\$(basename "$virus")"
        echo -n " Run script."
        vmrun -gu "$WU" -gp "$WP" -T fusiolon runProgramInGuest "$WINDOWS_CLONE" \
            C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe "c:\\Run\\$1.ps1" "c:\\Run\\Virus\\$(basename "$virus")"
        echo -n " Retrieve report."
        vmrun -gu "$WU" -gp "$WP" -T fusion CopyFileFromGuestToHost "$WINDOWS_CLONE" "c:\\Run\\$1_report.zip" "$WORKDIR/$nr/$1_report.zip"
        echo " Done."
        CURRENT_DIR=$PWD
        cd "$WORKDIR/$nr" || exit 1
        unzip "$1_report.zip" > /dev/null
        rm -f "$1_report.zip"
        cd "$CURRENT_DIR" || exit 1
        touch "$WORKDIR/$nr/1_$1"
    fi
    return 0
}

# Zip - might be word file
# The following assumption are made:
# - 7z and rar are handled in VM running in Cuckoo
# - 7z and rar files with multiple malware have been unpacked before.
# - zip files can be of the following types:
#   - regular zip file
#   - new office file (.dotx etc)
#   - file extracted from SCEP quarantine (done by internal script)
function unpack_files {
    echo -n "Prepare files. "
    i=1
    SAVEIFS=$IFS
    IFS=$(echo -en "\n\b")
    for file in "$@"; do
        filetypeshort=$(file -b "$file" | awk '{print $1}')
        if [[ $filetypeshort == "Zip" ]]; then
            TEMPDIR=$(mktemp -d)
            unzip -o -P "" "$file" -d "$TEMPDIR" > /dev/null 2>&1 || true
            unzip -o -P virus "$file" -d "$TEMPDIR" > /dev/null 2>&1 || true
            unzip -o -P infected "$file" -d "$TEMPDIR" > /dev/null 2>&1 || true
            # Zip file with from SCEP quarantine on Windows.
            if [[ -e "$TEMPDIR/MpCmdRun-output.txt" ]]; then
                for extracted in $TEMPDIR/*; do
                    if ! echo "$extracted" | grep -E "MpCmdRun-output.txt$" > /dev/null ; then
                        mkdir -p "$WORKDIR/$i/2_file"
                        generate_report
                        cp "$extracted" "$WORKDIR/$i/2_file"
                        cp "$TEMPDIR/MpCmdRun-output.txt" "$WORKDIR/$i/"
                        i=$(( i+1 ))
                    fi
                done
            # Word file
            elif [[ -d  $TEMPDIR/word && -d $TEMPDIR/docProps ]]; then
                mkdir -p "$WORKDIR/$i/2_file"
                generate_report
                cp "$file" "$WORKDIR/$i/2_file/"
                i=$(( i+1 ))
            # Regular zip file (also copy original)
            else
                # Copy original
                mkdir -p "$WORKDIR/$i/2_file"
                generate_report
                cp "$file" "$WORKDIR/$i/2_file"
                i=$(( i+1 ))
                # Copy extracted
                while IFS= read -r -d '' extracted; do
                    mkdir -p "$WORKDIR/$i/2_file"
                    generate_report
                    cp "$extracted" "$WORKDIR/$i/2_file"
                    i=$(( i+1 ))
                done <  <(find "$TEMPDIR/" -type f -print0)
            fi
            rm -rf "$TEMPDIR"
        else
            # All other files
            mkdir -p "$WORKDIR/$i/2_file"
            generate_report
            cp "$file" "$WORKDIR/$i/2_file/"
            i=$(( i+1 ))
        fi
        echo -n "*"
    done
    return 0
}

function clean_filenames {
    while IFS= read -r -d '' filename; do
        newfilename=$(echo "$filename" | sed -e "s/[^-_.\/a-zA-Z0-9]/_/g")
        if [[ "$newfilename" != "$filename" ]]; then
            mv "$filename" "$newfilename"
            [ ! -z "$VERBOSE" ] && echo"" && echo "Renamed file $filename to $newfilename."
        fi
    done <   <(find "$WORKDIR"/*/2_file/* -type f -print0)
    echo " Done."
}

function sha_and_duplicates {
    # Calculate sha and find duplicate
    for id in $(find "$WORKDIR" -maxdepth 1 -type d -name "[1-9]*" | sed -e 's!.*/!!' | sort -n); do
		shasum -a 256 "$WORKDIR/$id/2_file"/* > "$WORKDIR/$id/9_sha256.txt"
		[ "$id" == "1" ] && continue
		sha="$(shasum -a 256 "$WORKDIR/$id/2_file"/* | awk '{print $1}')"
		for compare in $(seq 1 $((id - 1))); do
			if grep "$sha" "$WORKDIR/$compare/9_sha256.txt" > /dev/null ; then
				(cd "$WORKDIR/$id" && ln -s ../"$compare" 5_duplicate_of_"$compare" && touch 6_duplicate)
				continue
			fi
		done
	done
    return 0
}

function prepare_files {
    unpack_files "$@"
    clean_filenames
    sha_and_duplicates
    return 0
}

function generate_report {
    echo -n "Date: " >  "$WORKDIR/$i/0_report.txt"
    date >> "$WORKDIR/$i/0_report.txt"
}

function get_cuckoo_reports {
    echo -n "Copy script to get Cuckoo reports."
    vmrun -gu "$CU" -gp "$CP" -T fusion CopyFileFromHostToGuest "$CUCKOO_CLONE" "scripts/get_cuckoo_reports.sh" "/tmp/get_cuckoo_reports.sh"
    echo " Done."
    echo -n "Wait for reports from Cuckoo. This will take time. Go grab a cup of coffee and plan new automation projects."
    vmrun -gu "$CU" -gp "$CP" -T fusiolon runProgramInGuest "$CUCKOO_CLONE" /bin/bash /tmp/get_cuckoo_reports.sh
    echo " Done."
    echo -n " Retrieve reports for Cuckoo."
    vmrun -gu "$CU" -gp "$CP" -T fusion CopyFileFromGuestToHost "$CUCKOO_CLONE" "/tmp/cuckoo_reports.zip" "$WORKDIR/cuckoo_reports.zip"
    echo " Done."
}

function handle_cuckoo_reports {
    cd "$WORKDIR/" || exit 1
    echo -n "Unzip Cuckoo reports."
    unzip cuckoo_reports.zip > /dev/null
    rm -f cuckoo_reports.zip
    cd cuckoo || exit 1
    for archive in *.bz2; do
        id=$(echo "$archive" | cut -f1 -d.)
        mkdir "$id"
        TMP_PWD=$PWD
        cd "$id" || exit 1
        tar xfj "../$archive"
        nr=$(json_pp < task.json | grep target | awk '{print $3}' | cut -f4 -d/)
        cd "$TMP_PWD" || exit 1
        mv "$id" "../$nr/3_cuckoo"
        rm -f "$archive"
    done

    cd "$WORKDIR" || exit 1
    for dir in [1-9]*; do
        (
            cd "$dir" || exit 1
            ln -s 3_cuckoo/reports/report.html 4_cuckoo_report.html
        )
    done
    cd "$CURRENT_DIR" || exit 1
    IFS=$SAVEIFS
    echo " Done."
}

function add_summary_start {
    {
        sed '/<body>/,$d' < "$WORKDIR/1/3_cuckoo/reports/report.html"
        echo '<body>'
        echo '<div class="section-title"><h2>Summary</h2></div>'
    } > "$REPORT"
}

function add_summary_end {
    {
        echo '<script>'
        sed '1,/^<script>/d' < "$WORKDIR"/1/3_cuckoo/reports/report.html | sed -e '/<\/section>/,$d'
    } >> "$REPORT"
}

function add_summary_entry {
    # $1: Color
    #   - success: green
    #   - warning: yellow
    #   - error: red
    # $2: Alert type, ex: suricata_alert
    # $3: Message, ex: Raised Suricata alerts
    # Global: $id
    echo "<div>"
    echo "    <div class=\"alert alert-$1 signature\">"
    echo "        <b>$2<a href=\"javascript:showHide('signature_${id}${2}');\">  details</a></b>"
    echo "        <div id=\"signature_${id}${2}\" style=\"display: none;\">$3</div>"
    echo "    </div>"
    echo "</div>"
}

function yara_summary_entry {
    unset color
    if [ -e "$WORKDIR/$id/yara.txt" ]; then
        color="success"
        alert_type="yara"
        message="<pre>$(cat "$WORKDIR/$id/yara.txt")</pre>"
    fi
    if [ -e "$WORKDIR/$id/yara_documents.txt" ]; then
        color="warning"
        alert_type="yara_document"
        message="<pre>$(cat "$WORKDIR/$id/yara_documents.txt")</pre>"
    fi
    if [ -e "$WORKDIR/$id/yara_malware.txt" ]; then
        color="error"
        alert_type="yara_malware"
        message="$(cat "$WORKDIR/$id/yara_malware.txt")"
    fi
    [ ! -z "$color" ] && add_summary_entry "$color" "$alert_type" "$message"
    return 0
}

function generate_summary_report {
    if [ ! -f "$WORKDIR"/1/3_cuckoo/reports/report.html ] ; then
        echo "No Cuckoo reports found."
        if [ -z "$REPORT_ONLY" ]; then
            return
        else
            exit 1
        fi
    fi
    echo -n "Generate summary report."
    REPORT="$WORKDIR/index.html"
    add_summary_start
    for id in $(find "$WORKDIR" -maxdepth 1 -type d -name "[1-9]*" | sed -e 's!.*/!!' | sort -n); do
        if [ -e "$WORKDIR/$id/6_duplicate" ]; then
            dup=($(find "$WORKDIR/$id/"5* 2> /dev/null || true))
            # shellcheck disable=SC2001
            dup_id=$(echo "${dup[0]}" | sed -e 's/.*_//')
            filename=($(find "$WORKDIR/$id/2_file/"* | sed -e 's!.*/2_file/!!' 2> /dev/null || true))
            {
                echo '<section id="signatures">'
                echo "<div class=\"section-title\"> <h4>Signatures file $id - ${filename[0]}</h4></div>"
                echo "<div><a href=\"$WORKDIR/$dup_id/\">Duplicate of file $dup_id</a></div>"
                echo "<div><a href=\"$WORKDIR/$dup_id/3_cuckoo/reports/report.html\">Full Cuckoo report for file $dup_id</a></div>"
                echo '</section>'
            } >> "$REPORT"
        else
            {
                filetype=($(find "$WORKDIR/$id/"1* | sed -e 's!.*/1_!!' 2> /dev/null || true))
                filename=($(find "$WORKDIR/$id/2_file/"* | sed -e 's!.*/2_file/!!' 2> /dev/null || true))
                echo '<section id="file">'
                sed '1,/<section id="file">/d' < "$WORKDIR/$id"/3_cuckoo/reports/report.html | \
                    sed -e '/<\/section>/,$d' | \
                    sed -e "s/File Details/File Details file $id - ${filetype[0]} - ${filename[0]}/" | \
                    sed -e "s/'virustotal/'virustotal$id/" | \
                    sed -e "s/\"virustotal\"/\"virustotal$id\"/"
                echo '</section>'
                echo '<section id="signatures">'
                sed '1,/<section id="signatures">/d' < "$WORKDIR/$id"/3_cuckoo/reports/report.html | \
                    sed -e '/<\/section>/,$d' | \
                    sed -e "s/<h4>Signatures<\/h4>//" | \
                    sed -e "s/signature_/signature_$id/"

                yara_summary_entry

                echo "<div><a href=\"$WORKDIR/$id/3_cuckoo/reports/report.html\">Full Cuckoo report for file $id</a></div>"
                echo "<div><a href=\"$WORKDIR/$id/\">Directory listning for file $id</a></div>"
                echo '</section>'
            } >> "$REPORT"
        fi
    done
    add_summary_end
    echo " Done."
    [ ! -z "$OPEN_BROWSER" ] && open "$REPORT"
    return 0
}

trap shutdownVM SIGHUP SIGINT SIGTERM

if [ ! -z "$REPORT_ONLY" ] ; then
    generate_summary_report
    exit 0
fi

startVM
prepare_files "$@"
wait_for_linux
[ ! -z "$CUCKOO" ] && post_start_cuckoo
[ ! -z "$REMNUX" ] && post_start_remnux
copy_to_linux_submit_cuckoo
analyze_in_remnux_windows

# Done with REMnux and Windows
[[ $REMNUX_RUNNING == "TRUE" && -z $PAUSE ]] && shutdownRemnux
[[ $WINDOWS_RUNNING == "TRUE" && -z $PAUSE ]] && shutdownWindows

# Get reports from Cuckoo
[ ! -z "$CUCKOO" ] && get_cuckoo_reports
[ ! -z "$CUCKOO" ] && handle_cuckoo_reports
generate_summary_report

# Clean up
if [ ! -z $PAUSE ] ; then
    read -r -p "Type yes to try to stop and delete the clones: " yes
    [ "$yes" == "yes" ] && shutdownVM
else
    shutdownVM
fi
