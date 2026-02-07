#!/bin/sh -

##################################################################
#                        _            
#                     _ ( )           
#   ___    ___  _ __ (_)| |_      __  
# /',__) /'___)( '__)| || '_`\  /'__`\
# \__, \( (___ | |   | || |_) )(  ___/
# (____/`\____)(_)   (_)(_,__/'`\____)
# syslog-ng and logrotate installer for Asuswrt-Merlin
#
# Coded by cmkelley
#
# Original interest in syslog-ng on Asuswrt-Merlin inspired by tomsk & kvic
# Good ideas and code borrowed heavily from Adamm, dave14305, Jack Yaz, thelonelycoder, & Xentrx
#
# Installation command:
#   curl --retry 3 "https://raw.githubusercontent.com/AMTM-OSR/scribe/master/scribe.h" -o "/jffs/scripts/scribe" && chmod 0755 /jffs/scripts/scribe && /jffs/scripts/scribe install
#
##################################################################
# Last Modified: 2026-Feb-07
#-----------------------------------------------------------------

################       Shellcheck directives     ################
# shellcheck disable=SC1090
# shellcheck disable=SC1091
# shellcheck disable=SC2009
# SC2009 = Consider uing pgrep ~ Note that pgrep doesn't exist in asuswrt (exists in Entware procps-ng)
# shellcheck disable=SC2059
# SC2059 = Don't use variables in the printf format string. Use printf "..%s.." "$foo" ~ I (try to) only embed the ansi color escapes in printf strings
# shellcheck disable=SC2034
# shellcheck disable=SC3043
# shellcheck disable=SC3045
#################################################################

readonly script_name="scribe"
readonly scribe_ver="v3.2.9"
readonly scriptVer_TAG="26020700"
scribe_branch="master"
script_branch="$scribe_branch"

# Ensure firmware binaries are used, not Entware #
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:$PATH"

# Set TMP if not set #
[ -z "${TMP:+xSETx}" ] && export TMP=/opt/tmp

# Parse parameters #
action="X"
got_zip=false
banner=true
usbUnmountCaller=false

[ "${SCRIBE_LOGO:=xFALSEx}" = "nologo" ] && banner=false

while { [ $# -gt 0 ] && [ -n "$1" ] ; }
do
    case "$1" in
        gotzip)
            got_zip=true ; shift
            ;;
        nologo)
            banner=false ; shift
            ;;
        unmount)
            usbUnmountCaller=true ; shift
            ;;
        service_event | LogRotate)
            banner=false
            action="$1"
            break
            ;;
        *)
            action="$1" ; shift
            ;;
    esac
done
[ "$action" = "X" ] && action="menu"

# scribe constants #
# Version 'vX.Y_Z' format because I'm stubborn #
script_ver="$( echo "$scribe_ver" | sed 's/\./_/2' )"
readonly script_ver
readonly scriptVer_long="$scribe_ver ($scribe_branch)"
readonly script_author="AMTM-OSR"
readonly raw_git="https://raw.githubusercontent.com"
readonly script_zip_file="${TMP}/${script_name}_TEMP.zip"
readonly script_tmp_file="${TMP}/${script_name}_TEMP.tmp"
readonly script_d="/jffs/scripts"
readonly script_loc="${script_d}/$script_name"
readonly config_d="/jffs/addons/${script_name}.d"
readonly script_conf="${config_d}/config"
readonly optmsg="/opt/var/log/messages"
readonly jffslog="/jffs/syslog.log"
readonly tmplog="/tmp/syslog.log"
syslog_loc=""
export optmsg
export tmplog
export jffslog
export script_conf

##-------------------------------------##
## Added by Martinski W. [2025-Jul-07] ##
##-------------------------------------##
readonly branchxStr_TAG="[Branch: $scribe_branch]"
readonly versionDev_TAG="${scribe_ver}_${scriptVer_TAG}"
readonly scribeVerRegExp="v[0-9]{1,2}([.][0-9]{1,2})([_.][0-9]{1,2})"

if [ "$script_branch" = "master" ]
then SCRIPT_VERS_INFO=""
else SCRIPT_VERS_INFO="[$versionDev_TAG]"
fi

##----------------------------------------##
## Modified by Martinski W. [2025-Jul-07] ##
##----------------------------------------##
# router details #
readonly wrtMerlin="ASUSWRT-Merlin"
readonly fwVerReqd="3004.380.68"
fwName="$( uname -o )"
readonly fwName
fwVerBuild="$(nvram get firmver | sed 's/\.//g').$( nvram get buildno )"
fwVerExtNo="$(nvram get extendno)"
fwVersFull="${fwVerBuild}.${fwVerExtNo:=0}"
readonly fwVerBuild
readonly fwVerExtNo
readonly fwVersFull
model="$( nvram get odmpid )"
[ -z "$model" ] && model="$( nvram get productid )"
readonly model
arch="$( uname -m )"
readonly arch

# miscellaneous constants #
readonly sld="syslogd"
readonly sng="syslog-ng"
readonly sng_reqd="3.19"
readonly lr="logrotate"
readonly init_d="/opt/etc/init.d"
readonly S01sng_init="$init_d/S01$sng"
readonly rcfunc_sng="rc.func.$sng"
readonly rcfunc_loc="$init_d/$rcfunc_sng"
readonly sng_loc="/opt/sbin/$sng"
readonly sngctl_loc="${sng_loc}-ctl"
readonly lr_loc="/opt/sbin/$lr"
readonly sng_conf="/opt/etc/${sng}.conf"
readonly debug_sep="=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*="
readonly script_debug_name="${script_name}_debug.log"
readonly script_debug="${TMP}/$script_debug_name"
readonly sngconf_merged="${TMP}/${sng}-complete.conf"
readonly sngconf_error="${TMP}/${sng}-error.conf"
readonly lr_conf="/opt/etc/${lr}.conf"
readonly lr_daily="/opt/tmp/logrotate.daily"
readonly lr_temp="/opt/tmp/logrotate.temp"
readonly sngd_d="/opt/etc/${sng}.d"
readonly lrd_d="/opt/etc/${lr}.d"
readonly etc_d="/opt/etc/*.d"
readonly sng_share="/opt/share/$sng"
readonly lr_share="/opt/share/$lr"
readonly share_ex="/opt/share/*/examples"
readonly script_bakname="${TMP}/${script_name}-backup.tar.gz"
readonly fire_start="$script_d/firewall-start"
readonly srvcEvent="$script_d/service-event"
readonly postMount="$script_d/post-mount"
readonly unMount="$script_d/unmount"
readonly skynet="$script_d/firewall"
readonly sky_req="6.9.2"
readonly divers="/opt/bin/diversion"
readonly div_req="4.1"

##-------------------------------------##
## Added by Martinski W. [2025-Dec-05] ##
##-------------------------------------##
readonly HOMEdir="/home/root"
readonly TEMPdir="/tmp/var/tmp"
readonly optTempDir="/opt/tmp"
readonly optVarLogDir="/opt/var/log"
readonly syslogNgStr="syslog-ng"
readonly logRotateStr="logrotate"
readonly syslogNgCmd="/opt/sbin/$syslogNgStr"
readonly logRotateCmd="/opt/sbin/$logRotateStr"
readonly logRotateDir="/opt/etc/${logRotateStr}.d"
readonly logRotateShareDir="/opt/share/$logRotateStr"
readonly logRotateExamplesDir="${logRotateShareDir}/examples"
readonly logRotateTopConfig="/opt/etc/${logRotateStr}.conf"
readonly logRotateGlobalName="A01global"
readonly logRotateGlobalConf="${logRotateDir}/$logRotateGlobalName"
readonly LR_FLock_FD=513
readonly LR_FLock_FName="/tmp/scribeLogRotate.flock"
readonly logFilesRegExp="${optVarLogDir}/.*([.]log)?"
readonly filteredLogList="${config_d}/.filteredlogs"
readonly noConfigLogList="${config_d}/.noconfiglogs"
readonly syslogNg_ShareDir="/opt/share/$syslogNgStr"
readonly syslogNg_ExamplesDir="${syslogNg_ShareDir}/examples"
readonly syslogNg_ConfName=${syslogNgStr}.conf
readonly syslogNg_TopConfig="/opt/etc/$syslogNg_ConfName"
readonly syslogNg_WaitnSEM_FPath="${TEMPdir}/scribe_SysLogNg.WAITN.SEM"
readonly syslogNg_StartSEM_FPath="${TEMPdir}/scribe_SysLogNg.START.SEM"
readonly syslogD_InitRebootLogFPath="${optVarLogDir}/syslogd.ScribeInitReboot.LOG"
readonly sysLogLinesMAX=20480
readonly sysLogMsgeSizeMAX=2048
sysLogFiFoSizeMIN=1600

# color constants #
readonly red="\033[1;31m"
readonly green="\033[1;32m"
readonly yellow="\033[1;33m"
readonly blue="\033[1;34m"
readonly magenta="\033[1;35m"
readonly cyan="\033[1;36m"
readonly white="\033[1;37m"
readonly std="\e[0m"
readonly BOLD="\e[1m"
readonly CLRct="\e[0m"
readonly GRNct="\e[1;32m"

##-------------------------------------##
## Added by Martinski W. [2025-Nov-29] ##
##-------------------------------------##
readonly oneMByte=1048576
readonly twoMByte=2097152
readonly LR_CronJobMins=5
readonly LR_CronJobHour=0
readonly LR_CronTagStr="scribeLogRotate"
readonly validHourRegExp="(2|3|4|6|8|12|24)"
readonly validHourLstStr="2, 3, 4, 6, 8, 12, and 24."

##----------------------------------------##
## Modified by Martinski W. [2025-Jul-07] ##
##----------------------------------------##
# uiScribe add-on constants #
readonly uiscribeName="uiScribe"
readonly uiscribeAuthor="AMTM-OSR"
readonly uiscribeBranch="master"
readonly uiscribeRepo="$raw_git/$uiscribeAuthor/$uiscribeName/$uiscribeBranch/${uiscribeName}.sh"
readonly uiscribePath="$script_d/$uiscribeName"
readonly uiscribeVerRegExp="v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})"
readonly menuSepStr="${white} =*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=${CLRct}\n\n"

# Check if Scribe is already installed by looking for link in /opt/bin #
[ -e "/opt/bin/$script_name" ] && scribeInstalled=true || scribeInstalled=false

# Check if uiScribe is installed #
[ -e "$uiscribePath" ] && uiScribeInstalled=true || uiScribeInstalled=false

# Check if Skynet is installed
if [ -e "$fire_start" ] && grep -q "skynetloc" "$fire_start"
then
    skynet_inst=true
else
    skynet_inst=false
fi

#### functions ####

##-------------------------------------##
## Added by Martinski W. [2025-Jul-07] ##
##-------------------------------------##
SetUpRepoBranchVars()
{
   script_repoFile="$raw_git/$script_author/$script_name/$script_branch/${script_name}.sh"
   script_repo_ZIP="https://github.com/$script_author/$script_name/archive/${script_branch}.zip"
   unzip_dirPath="$TMP/${script_name}-$script_branch"
}

present(){ printf "$green present. $std\n"; }

updated(){ printf "$yellow updated. $std\n"; }

finished(){ printf "$green done. $std\n"; }

not_installed(){ printf "\n ${blue}%s ${red}NOT${white} installed!${std}\n" "$1"; }

PressEnterTo()
{ printf "$white Press <Enter> key to %s $std" "$1"; read -rs inputKey; echo; }

VersionStrToNum()
{ echo "$1" | sed 's/v//; s/_/./' | awk -F. '{ printf("%d%03d%02d\n", $1, $2, $3); }'; }

MD5_Hash(){ md5sum "$1" | awk -F' ' '{print $1}' ; }

strip_path(){ basename "$1"; }

delfr(){ rm -fr "$1"; }

Same_MD5_Hash(){ if [ "$(MD5_Hash "$1")" = "$(MD5_Hash "$2")" ]; then true; else false; fi; }

AppendDateTimeStamp()
{ [ -e "$1" ] && mv -f "$1" "${1}_$(date +'%Y-%m-%d_T%H%M%S')" ; }

SyslogNg_Running(){ if [ -n "$(pidof "$sng")" ]; then true; else false; fi; }

SyslogD_Running(){ if [ -n "$(pidof "$sld")" ]; then true; else false; fi; }

##-------------------------------------##
## Added by Martinski W. [2025-Nov-30] ##
##-------------------------------------##
_GetFileSize_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] || [ ! -s "$1" ]
   then echo 0 ; return 1
   fi
   ls -1l "$1" | awk -F ' ' '{print $3}'
   return 0
}

##----------------------------------------##
## Modified by Martinski W. [2026-Jan-10] ##
##----------------------------------------##
Clear_Syslog_Links()
{
    if [ -L "$tmplog" ]
    then delfr "$tmplog"
    fi
    if [ -L "${tmplog}-1" ]
    then delfr "${tmplog}-1"
    fi
    if [ -L "$jffslog" ] || [ -d "$jffslog" ]
    then delfr "$jffslog"
    fi
    if [ -L "${jffslog}-1" ] || [ -d "${jffslog}-1" ]
    then delfr "${jffslog}-1"
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2026-Jan-10] ##
##----------------------------------------##
Start_SyslogD()
{
    service start_logger

    "$usbUnmountCaller" && count=5 || count=30
    while ! SyslogD_Running && [ "$count" -gt 0 ]
    do
        sleep 1  #Give syslogd time to start up#
        count="$(( count - 1 ))"
    done
    if [ "$count" -eq 0 ] && ! "$usbUnmountCaller"
    then
        printf "\n ${red}UNABLE to start syslogd. ABORTING!!${std}\n"
        exit 1
    fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Jun-22] ##
##-------------------------------------##
_ServiceEventTime_()
{
    [ ! -d "$config_d" ] && mkdir "$config_d"
    [ ! -e "$script_conf" ] && touch "$script_conf"

    if [ $# -eq 0 ] || [ -z "$1" ]
    then return 1
    fi
    local timeNotFound  lastEventTime

    if ! grep -q "^SRVC_EVENT_TIME=" "$script_conf"
    then timeNotFound=true
    else timeNotFound=false
    fi

    case "$1" in
        update)
            if "$timeNotFound"
            then
                echo "SRVC_EVENT_TIME=$2" >> "$script_conf"
            else
                sed -i 's/^SRVC_EVENT_TIME=.*$/SRVC_EVENT_TIME='"$2"'/' "$script_conf"
            fi
            ;;
        check)
            if "$timeNotFound"
            then
                lastEventTime=0
                echo "SRVC_EVENT_TIME=0" >> "$script_conf"
            else
                lastEventTime="$(grep "^SRVC_EVENT_TIME=" "$script_conf" | cut -d'=' -f2)"
                if ! echo "$lastEventTime" | grep -qE "^[0-9]+$"
                then lastEventTime=0
                fi
            fi
            echo "$lastEventTime"
            ;;
    esac
}

##-------------------------------------##
## Added by Martinski W. [2025-Nov-29] ##
##-------------------------------------##
_Config_Option_Update_()
{
    [ ! -d "$config_d" ] && mkdir "$config_d"
    [ ! -e "$script_conf" ] && touch "$script_conf"

    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
    then return 1
    fi
    if ! grep -qE "^${1}=" "$script_conf"
    then
        echo "${1}=${2}" >> "$script_conf"
    else
        sed -i "s~${1}=.*~${1}=${2}~" "$script_conf"
    fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Nov-29] ##
##-------------------------------------##
_Config_Option_Get_()
{
   [ ! -d "$config_d" ] && mkdir "$config_d"
   [ ! -e "$script_conf" ] && touch "$script_conf"

   if [ ! -s "$script_conf" ]    || \
      [ $# -eq 0 ] || [ -z "$1" ] || \
      ! grep -qE "^${1}=" "$script_conf"
   then
       echo ; return 1
   fi
   grep "^${1}=" "$script_conf" | cut -d'=' -f2
}

##-------------------------------------##
## Added by Martinski W. [2025-Nov-29] ##
##-------------------------------------##
_Config_Option_Check_()
{
    if [ $# -eq 0 ] || [ -z "$1" ]
    then return 1
    fi
    if [ -n "$(_Config_Option_Get_ "$1")" ]
    then return 0
    else return 1
    fi
}

#-----------------------------------------------------------
# random routers point syslogd at /jffs instead of /tmp
# figure out where default syslog.log location is
# function assumes syslogd is running!
#-----------------------------------------------------------
##----------------------------------------##
## Modified by Martinski W. [2025-Nov-29] ##
##----------------------------------------##
Where_SyslogD()
{
    local findStr
    if [ -n "$(pidof syslogd)" ]
    then
        findStr="$(ps ww | grep '/syslogd' | grep -oE '\-O .*/syslog.log')"
        if [ -n "$findStr" ]
        then
            syslog_loc="$(echo "$findStr" | awk -F' ' '{print $2}')"
        fi
    fi
    [ -n "$syslog_loc" ] && _Config_Option_Update_ SYSLOG_LOC "$syslog_loc"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Nov-30] ##
##----------------------------------------##
Create_Config()
{
    printf "\n$white Detecting default syslog location... "
    if SyslogNg_Running
    then
        slg_was_rng=true
        printf "\n Briefly shutting down %s" "$sng"
        killall -q "$sng" 2>/dev/null
        count=10
        while SyslogNg_Running && [ "$count" -gt 0 ]
        do
            sleep 1
            count="$(( count - 1 ))"
        done
        Clear_Syslog_Links
    else
        slg_was_rng=false
    fi

    if ! SyslogD_Running
    then Start_SyslogD
    fi
    Where_SyslogD

    if "$slg_was_rng"
    then
        # If syslog-ng was running, kill syslogd and restart #
        $S01sng_init start
    elif [ -x "$sng_loc" ] && [ -x "$lr_loc" ] && \
         [ -d "$lrd_d" ] && [ -n "$syslog_loc" ] && \
         [ -s "$syslog_loc" ] && [ ! -L "$syslog_loc" ]
    then
        # Prepend /opt/var/messages to syslog & create link #
        cat "$syslog_loc" >> "$optmsg"
        mv -f "$optmsg" "$syslog_loc"
        ln -s "$syslog_loc" "$optmsg"
    fi
    # Assume uiScribe is still running if it was before stopping syslog-ng #
}

##----------------------------------------##
## Modified by Martinski W. [2026-Jan-30] ##
##----------------------------------------##
Read_Config()
{
    if [ -s "$script_conf" ] && grep -q "^SYSLOG_LOC=" "$script_conf"
    then
        syslog_loc="$(_Config_Option_Get_ SYSLOG_LOC)"
    else
        Create_Config
    fi
    export syslog_loc

    if ! _Config_Option_Check_ LR_CRONJOB_HOUR
    then
        _Config_Option_Update_ LR_CRONJOB_HOUR 24
    fi
    if ! _Config_Option_Check_ FILTER_INIT_REBOOT_LOG
    then
        _Config_Option_Update_ FILTER_INIT_REBOOT_LOG true
    fi

    # Set correct permissions to avoid "world-readable" status #
    if [ "$action" != "debug" ] && \
       [ -f /var/lib/logrotate.status ]
    then chmod 600 /var/lib/logrotate.status
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Aug-23] ##
##----------------------------------------##
Update_File()
{
    if [ $# -gt 2 ] && [ "$3" = "BACKUP" ]
    then AppendDateTimeStamp "$2"
    fi
    cp -fp "$1" "$2"
}

Yes_Or_No()
{
    read -r resp
    case "$resp" in
        [yY][eE][sS]|[yY])
            true
            ;;
        *)
            false
            ;;
    esac
}

##-------------------------------------##
## Added by Martinski W. [2025-Nov-23] ##
##-------------------------------------##
_CenterTextStr_()
{
    if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ] || \
       ! echo "$2" | grep -qE "^[1-9][0-9]+$"
    then return 1
    fi
    local stringLen="${#1}"
    local space1Len="$((($2 - stringLen)/2))"
    local space2Len="$space1Len"
    local totalLen="$((space1Len + stringLen + space2Len))"

    if [ "$totalLen" -lt "$2" ]
    then space2Len="$((space2Len + 1))"
    elif [ "$totalLen" -gt "$2" ]
    then space1Len="$((space1Len - 1))"
    fi
    if [ "$space1Len" -gt 0 ]
    then spaceLenX="$space1Len"
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-09] ##
##----------------------------------------##
ScriptLogo()
{
    if ! "$banner"
    then return 0
    fi
    local spaceLenT=45  spaceLenX=5  colorCT
    _CenterTextStr_ "$scribe_ver $branchxStr_TAG" "$spaceLenT"
    [ "$script_branch" = "master" ] && colorCT="$green" || colorCT="$magenta"
    clear
    printf "$white                            _\n"
    printf "                         _ ( )            \n"
    printf "       ___    ___  _ __ (_)| |_      __   \n"
    printf "     /',__) /'___)( '__)| || '_\`\\  /'__\`\\ \n"
    printf "     \\__, \\( (___ | |   | || |_) )(  ___/ \n"
    printf "     (____/\`\\____)(_)   (_)(_,__/'\`\\____) \n"
    printf "     %s and %s installation $std\n" "$sng" "$lr"
    printf "%*s${green}%s${std} ${colorCT}%s${std}\n" "$spaceLenX" '' "$scribe_ver" "$branchxStr_TAG"
    printf "      ${blue}https://github.com/AMTM-OSR/scribe${std}\n"
    printf "          ${blue}Original author: cmkelley${std}\n\n"
}

warning_sign()
{
    printf "\n\n$white"
    printf "                *********************\n"
    printf "                ***$red W*A*R*N*I*N*G$white ***\n"
    printf "                *********************\n\n"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-09] ##
##----------------------------------------##
Get_ZIP_File()
{
    if ! $got_zip
    then
        delfr "$unzip_dirPath"
        delfr "$script_zip_file"
        printf "\n$white Fetching %s from GitHub %s branch ...$std\n" "$script_name" "$script_branch"
        if curl -fL --retry 4 --retry-delay 5 --retry-connrefused "$script_repo_ZIP" -o "$script_zip_file"
        then
            printf "\n$white unzipping %s ...$std\n" "$script_name"
            unzip "$script_zip_file" -d "$TMP"
            /opt/bin/opkg update
            got_zip=true
        else
            printf "\n$white %s GitHub repository$red is unavailable! $std -- Aborting.\n" "$script_name"
            exit 1
        fi
    fi
}

Restart_uiScribe()
{
    if "$uiScribeInstalled"
    then
        printf "\n$white Restarting ${uiscribeName}...\n"
        $uiscribePath startup
    fi
}

Reload_SysLogNg_Config()
{
    printf "$white reloading %s ... $cyan" "$( strip_path $sng_conf )"
    $sngctl_loc reload
    printf "\n$std"
    Restart_uiScribe
}

Copy_SysLogNg_RcFunc()
{
    printf " ${white}copying %s to %s ...$std" "$rcfunc_sng" "$init_d"
    cp -fp "${unzip_dirPath}/init.d/$rcfunc_sng" "$init_d/"
    chmod 644 "$rcfunc_loc"
    finished
}

##-------------------------------------##
## Added by Martinski W. [2026-Jan-15] ##
##-------------------------------------##
Copy_SysLogNg_Top_Config()
{
    local forceUpdate=false
    local diffFile="/opt/tmp/syslogNG_diffs.TEMP.txt"
    local srceFile="${unzip_dirPath}/${syslogNgStr}.share/${syslogNg_ConfName}-scribe"

    [ ! -s "$srceFile" ] && return 1
    [ ! -d "$syslogNg_ExamplesDir" ] && mkdir -p "$syslogNg_ExamplesDir"
    if [ $# -gt 0 ] && [ "$1" = "force" ]
    then forceUpdate=true
    fi

    for destFile in "$syslogNg_TopConfig" "${syslogNg_ExamplesDir}/${syslogNg_ConfName}-scribe"
    do
        if [ ! -s "$destFile" ] || [ "$destFile" != "$syslogNg_TopConfig" ]
        then
            cp -fp "$srceFile" "$destFile"
        elif "$forceUpdate" || ! Same_MD5_Hash "$srceFile" "$destFile"
        then
            diff -U0 "$srceFile" "$destFile" 2>/dev/null | \
            grep -Ev "^(\-\-\-|\+\+\+)" | grep -E "^(\-|\+)" | \
            grep -Ev "^(\-|\+)[[:blank:]]+log_fifo_size\(" > "$diffFile"
            if [ -s "$diffFile" ] && \
               grep -qE "^(\-|\+)" "$diffFile" && \
               [ "$(wc -l < "$diffFile")" -gt 0 ]
            then
                printf " ${yellow}updating $destFile ..."
                Update_File "$srceFile" "$destFile" "BACKUP"
                finished
                printf " ${red}------------\n ***NOTICE***\n ------------${std}\n"
                printf " ${yellow}The file ${green}/opt/etc/syslog-ng.conf${yellow} has been replaced with"
                printf " a newer version.\n This means that any custom configuration options that you may"
                printf " have added\n or modified in the previously installed file are now removed.\n A backup"
                printf " of the previous file was created in the '${green}/opt/etc${yellow}' directory.${std}\n\n"
                PressEnterTo "continue..."
            fi
            rm -f "$diffFile"
        fi
        chmod 644 "$destFile"
    done
}

##-------------------------------------##
## Added by Martinski W. [2026-Jan-12] ##
##-------------------------------------##
Copy_LogRotate_Global_Options()
{
    local forceUpdate=false
    local srceFile="${unzip_dirPath}/${logRotateStr}.d/$logRotateGlobalName"

    [ ! -s "$srceFile" ] && return 1
    [ ! -d "$logRotateExamplesDir" ] && mkdir -p "$logRotateExamplesDir"
    if [ $# -gt 0 ] && [ "$1" = "force" ]
    then forceUpdate=true
    fi

    for destFile in "$logRotateGlobalConf" "${logRotateExamplesDir}/$logRotateGlobalName"
    do
        if [ ! -s "$destFile" ] || "$forceUpdate"
        then
            cp -fp "$srceFile" "$destFile"
            chmod 600 "$destFile"
        fi
    done
}

##-------------------------------------##
## Added by Martinski W. [2026-Jan-11] ##
##-------------------------------------##
_ShowSysLogNg_WaitStart_Msge_()
{
    local waitSecs=180
    if [ -s "$syslogNg_WaitnSEM_FPath" ]
    then waitSecs="$(head -n1 "$syslogNg_WaitnSEM_FPath")"
    fi
    printf " ${magenta}NOTICE:\n -------${CLRct}\n"
    printf " ${yellow}%s will start in about ${GRNct}%d${yellow} seconds...\n" "$sng" "$waitSecs"
    printf " Please wait until %s has been started.${CLRct}\n\n" "$sng"
}

##----------------------------------------##
## Modified by Martinski W. [2026-Jan-11] ##
##----------------------------------------##
Check_SysLogNg()
{
    printf "\n$white %34s" "checking $sng daemon ..."
    if SyslogNg_Running
    then
        printf " ${green}alive.${std}\n"
    else
        printf " ${red}dead.${std}\n"
        if [ -f "$syslogNg_WaitnSEM_FPath" ]
        then
            echo ; _ShowSysLogNg_WaitStart_Msge_
        fi
        printf "$white %34s" "the system logger (syslogd) ..."
        if SyslogD_Running
        then
            printf " ${green}is running.${std}\n\n"
            if [ ! -f "$syslogNg_WaitnSEM_FPath" ]
            then
                printf "    ${yellow}Type ${green}%s restart${yellow} at shell prompt or select ${green}rs${std}\n" "$script_name"
                printf "    ${yellow}from %s main menu to start %s.${std}\n\n" "$script_name" "$sng"
            fi
        else
            printf " ${red}is NOT running!${std}\n\n"
            if [ ! -f "$syslogNg_WaitnSEM_FPath" ]
            then
                printf "    ${yellow}Type ${green}%s -Fevd${yellow} at shell prompt or select '${green}sd${std}'\n" "$sng"
                printf "    ${yellow}from %s utilities menu ('${green}su${yellow}' option) to view %s\n" "$script_name" "$sng" 
                printf "    debugging information.${std}\n\n"
            fi
        fi
    fi
}

sed_SysLogNg_Init()
{
    printf "$white %34s" "checking $( strip_path "$S01sng_init" ) ..."
    if ! grep -q "$rcfunc_sng" "$S01sng_init"
    then
        sed -i "\~/opt/etc/init.d/rc.func$~i . $rcfunc_loc #${script_name}#\n" "$S01sng_init"
        updated
    else
        present
    fi
}

rd_warn(){
    printf "$yellow Use utility menu (su) option 'rd' to re-detect! $std\n"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Nov-29] ##
##----------------------------------------##
SysLogd_Check()
{
    local checksys_loc

    printf "$white %34s" "syslog.log default location ..."
    if [ "$syslog_loc" != "$jffslog" ] && [ "$syslog_loc" != "$tmplog" ]
    then
        printf "$red NOT SET!\n"
        rd_warn
        return 1
    else
        printf "$green %s $std\n" "$syslog_loc"
    fi
    printf "$white %34s" "... & agrees with config file ..."

    checksys_loc="$(_Config_Option_Get_ SYSLOG_LOC)"

    if [ -z "$checksys_loc" ]
    then
        printf "$red NO CONFIG FILE!\n"
        rd_warn
    elif [ "$syslog_loc" = "$checksys_loc" ]
    then
        printf "$green okay! $std\n"
    else
        printf "$red DOES NOT MATCH!\n"
        rd_warn
        return 1
    fi
}

sed_srvcEvent()
{
    printf "$white %34s" "checking $( strip_path "$srvcEvent" ) ..."
    if [ -f "$srvcEvent" ]
    then
        [ "$( grep -c "#!/bin/sh" "$srvcEvent" )" -ne 1 ] && sed -i "1s~^~#!/bin/sh -\n\n~" "$srvcEvent"
        if grep -q "$script_name kill-logger" "$srvcEvent"
        then sed -i "/$script_name kill-logger/d" "$srvcEvent"
        fi
        if grep -q "$script_name kill_logger" "$srvcEvent"
        then sed -i "/$script_name kill_logger/d" "$srvcEvent"
        fi
        if ! grep -q "^$script_loc service_event" "$srvcEvent"
        then
            echo "$script_loc service_event \"\$@\" & #${script_name}#" >> "$srvcEvent"
            updated
        else
            present
        fi
    else
        {
            echo "#!/bin/sh -" ; echo
            echo "$script_loc service_event \"\$@\" & #${script_name}#"
        } > "$srvcEvent"
        printf "$green created. $std\n"
    fi
    [ ! -x "$srvcEvent" ] && chmod 0755 "$srvcEvent"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-05] ##
##----------------------------------------##
LogRotate_CronJob_PostMount_Create()
{
    local foundLineCount  cronHourTmp
    local cronMinsStr="$LR_CronJobMins"
    local cronHourStr="$(_Get_LogRotate_CronHour_)"

    [ ! -x "$postMount" ] && chmod 0755 "$postMount"

    cronHourTmp="$(echo "$cronHourStr" | sed 's/\*/[\*]/')"

    foundLineCount="$(grep -cE "cru a $logRotateStr .* [*] [*] [*] $lr_loc $lr_conf" "$postMount")"
    if [ "$foundLineCount" -gt 0 ]
    then 
        sed -i "/cru a ${logRotateStr}/d" "$postMount"
    fi
    foundLineCount="$(grep -cE "cru a $LR_CronTagStr .* [*] [*] [*] $script_loc LogRotate" "$postMount")"

    if ! grep -qE "cru a $LR_CronTagStr \"$cronMinsStr $cronHourTmp [*] [*] [*] $script_loc LogRotate" "$postMount"
    then
        if [ "$foundLineCount" -gt 0 ]
        then 
            sed -i "/cru a ${LR_CronTagStr}/d" "$postMount"
        fi
        {
           echo '[ -x "${1}/entware/bin/opkg" ] && cru a '"$LR_CronTagStr"' "'"$cronMinsStr $cronHourStr"' * * * '"$script_loc"' LogRotate" #'"$script_name"'#'
        } >> "$postMount"
        return 0
    else
        return 1
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Nov-29] ##
##----------------------------------------##
LogRotate_CronJob_PostMount_Check()
{
    printf "$white %34s" "checking $( strip_path "$postMount" ) ..."
    if [ ! -s "$postMount" ]
    then
        printf "$red MISSING! \n"
        printf " Entware is not properly set up!\n"
        printf " Correct Entware installation before continuing! ${std}\n\n"
        exit 1
    fi
    if LogRotate_CronJob_PostMount_Create
    then
        updated
    else
        present
    fi
    # Set correct permissions to avoid "world-readable" status #
    [ -f /var/lib/logrotate.status ] && chmod 600 /var/lib/logrotate.status
}

##----------------------------------------##
## Modified by Martinski W. [2026-Jan-10] ##
##----------------------------------------##
sed_unMount()
{
    printf "$white %34s" "checking $( strip_path "$unMount" ) ..."
    if [ -f "$unMount" ]
    then
        [ "$( grep -c "#!/bin/sh" "$unMount" )" -ne 1 ] && sed -i "1s~^~#!/bin/sh -\n\n~" "$unMount"

        if grep -q " && $script_name stop nologo" "$unMount"
        then
            sed -i "/&& $script_name stop nologo/d" "$unMount" 
        fi
        if ! grep -q "&& $script_loc stop nologo unmount" "$unMount"
        then
            echo "[ \"\$(find \"\${1}/entware/bin/$script_name\" 2>/dev/null)\" ] && $script_loc stop nologo unmount #${script_name}#" >> "$unMount"
            updated
        else
            present
        fi
    else
        {
            echo "#!/bin/sh" ; echo
            echo "[ \"\$(find \"\${1}/entware/bin/$script_name\" 2>/dev/null)\" ] && $script_loc stop nologo unmount #${script_name}#"
        } > "$unMount"
        printf "$green created. $std\n"
    fi
    [ ! -x "$unMount" ] && chmod 0755 "$unMount"
}

##-------------------------------------##
## Added by Martinski W. [2025-Nov-29] ##
##-------------------------------------##
_Create_LogRotate_CronJob_()
{
    if [ $# -eq 0 ] || [ -z "$1" ]
    then return 1
    fi
    cru a "$LR_CronTagStr" "$LR_CronJobMins $1 * * * $script_loc LogRotate"
}

##-------------------------------------##
## Added by Martinski W. [2025-Nov-29] ##
##-------------------------------------##
_Get_LogRotate_CronHour_()
{
    local cronHourNum  cronHourStr

    cronHourNum="$(_Config_Option_Get_ LR_CRONJOB_HOUR)"
    if [ -z "$cronHourNum" ] || \
       ! echo "$cronHourNum" | grep -qE "^${validHourRegExp}$"
    then
        cronHourStr="$LR_CronJobHour"
        _Config_Option_Update_ LR_CRONJOB_HOUR 24
    elif [ "$cronHourNum" = "24" ]
    then
        cronHourStr="$LR_CronJobHour"
    else
        cronHourStr="*/$cronHourNum"
    fi

    echo "$cronHourStr"
}

##-------------------------------------##
## Added by Martinski W. [2025-Nov-29] ##
##-------------------------------------##
menu_LogRotate_CronJob_Time()
{
    local GREEN="\\\e[1;32m"  CLRD="\\\e[0m"
    local validHoursANDstr  validHoursORstr
    local cronHourNum  cronHourStr  hourInput  inputOK  retCode

    validHoursANDstr="$(echo "$validHourLstStr" | sed -E "s/([1-9]+)/${GREEN}\1${CLRD}/g")"
    validHoursORstr="$(echo "$validHoursANDstr" | sed 's/and/or/')"

    retCode=1
    inputOK=false

    while true
    do
        ScriptLogo
        printf "$menuSepStr"
        cronHourNum="$(_Config_Option_Get_ LR_CRONJOB_HOUR)"
        printf " ${BOLD}Current $lr cron job frequency: "
        printf "${green}Every ${cronHourNum} hours${CLRct}\n"
        printf "\n ${BOLD}Please specify how often to run the cron job."
        printf "\n Valid values are ${validHoursANDstr}\n"
        printf "\n Enter frequency in HOURS (${green}e${CLRct}=Exit):  "
        read -r hourInput

        if echo "$hourInput" | grep -qE "^[eE]$"
        then
            echo ; break
        elif [ -z "$hourInput" ] || \
             ! echo "$hourInput" | grep -qE "^${validHourRegExp}$"
        then
            printf "\n ${red}Please enter a valid number:${CLRct} ${validHoursORstr}\n\n"
            PressEnterTo "continue..."
        elif [ "$hourInput" -eq 24 ]
        then
            inputOK=true
            cronHourNum="$hourInput"
            cronHourStr="$LR_CronJobHour"
            echo ; break
        else
            inputOK=true
            cronHourNum="$hourInput"
            cronHourStr="*/$hourInput"
            echo ; break
        fi
    done

    if "$inputOK"
    then
        retCode=0
        _Config_Option_Update_ LR_CRONJOB_HOUR "$cronHourNum"
        _Create_LogRotate_CronJob_ "$cronHourStr"
        LogRotate_CronJob_PostMount_Create
    fi
    return "$retCode"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-05] ##
##----------------------------------------##
LogRotate_CronJob_Check()
{
    printf "$white %34s" "checking $lr cron job ..."

    if cru l | grep -q "#${logRotateStr}#"
    then
        cru d "$logRotateStr"
    fi
    if ! cru l | grep -q "#${LR_CronTagStr}#"
    then
        _Create_LogRotate_CronJob_ "$(_Get_LogRotate_CronHour_)"
        updated
    else
        present
    fi
}

Check_Dir_Links()
{
    printf "$white %34s" "checking directory links ..."
    if [ ! -L "$syslog_loc" ] || [ ! -d "/opt/var/run/syslog-ng" ]
    then
        #################################################################
        # load kill_logger() function to reset system path links/hacks
        # keep shellcheck from barfing on sourcing $rcfunc_loc
        # shellcheck disable=SC1091
        # shellcheck source=/opt/etc/init.d/rc.func.syslog-ng
        #################################################################
        . "$rcfunc_loc"
        kill_logger true
        updated
    else
        present
    fi
}

##-------------------------------------##
## Added by Martinski W. [2026-Jan-03] ##
##-------------------------------------##
_SysLogMsgSizeFromConfig_()
{
    if [ $# -eq 0 ] || [ -z "$1" ]
    then return 1
    fi
    local msgSizeNum  msgSizeOK=true

    msgSizeNum="$(grep -m1 'log_msg_size(' "$sng_conf" | cut -d ';' -f1 | grep -oE '[0-9]+')"
    if [ -n "$msgSizeNum" ] && [ "$msgSizeNum" -gt "$sysLogMsgeSizeMAX" ]
    then msgSizeOK=false
    fi

    case "$1" in
        check)
            "$msgSizeOK" && return 0 || return 1
            ;;
        update)
            "$msgSizeOK" && return 1  #NO Change#
            sed -i "s/log_msg_size($msgSizeNum)/log_msg_size($sysLogMsgeSizeMAX)/g" "$sng_conf"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

##-------------------------------------##
## Added by Martinski W. [2026-Jan-03] ##
##-------------------------------------##
_SysLogFiFoSizeFromConfig_()
{
    if [ $# -eq 0 ] || [ -z "$1" ]
    then return 1
    fi
    local fifoSizeNum  fifoSizeOK=true

    fifoSizeNum="$(grep -m1 'log_fifo_size(' "$sng_conf" | cut -d ';' -f1 | grep -oE '[0-9]+')"
    if [ -n "$fifoSizeNum" ] && [ "$fifoSizeNum" -lt "$sysLogFiFoSizeMIN" ]
    then fifoSizeOK=false
    fi

    case "$1" in
        check)
            "$fifoSizeOK" && return 0 || return 1
            ;;
        update)
            "$fifoSizeOK" && return 1  #NO Change#
            sed -i "s/log_fifo_size($fifoSizeNum)/log_fifo_size($sysLogFiFoSizeMIN)/g" "$sng_conf"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

##----------------------------------------##
## Modified by Martinski W. [2026-Jan-29] ##
##----------------------------------------##
SysLogNg_Config_Sync()
{
    local sng_conf_vtag1  sng_conf_vtag2  sng_version_str  sng_conf_verstr

    printf " ${white}%34s" "$(strip_path "$sng_conf") options check ..."
    sng_conf_vtag1="@version:"
    sng_conf_vtag2="${sng_conf_vtag1}[[:blank:]]*"
    sng_version_str="$( $sng --version | grep -m1 "$sng" | grep -oE '[0-9]{1,2}([_.][0-9]{1,2})' )"
    sng_conf_verstr="$( grep -Em1 "^$sng_conf_vtag2" "$sng_conf" | grep -oE '[0-9]{1,2}([_.][0-9]{1,2})' )"

    if grep -q 'stats_freq(' "$sng_conf"  || \
       ! _SysLogMsgSizeFromConfig_ check  || \
       ! _SysLogFiFoSizeFromConfig_ check || \
       [ "$sng_version_str" != "$sng_conf_verstr" ]
    then
        printf " ${red}out of sync!${std}\n"
        printf " ${cyan}*** Updating %s and restarting %s ***${std}\n" "$(strip_path "$sng_conf")" "$sng"
        $S01sng_init stop
        old_doc="doc\/syslog-ng-open"
        new_doc="list\/syslog-ng-open-source-edition"
        sed -i "s/$old_doc.*/$new_doc/" "$sng_conf"
        stats_freq="$( grep -m1 'stats_freq(' "$sng_conf" | cut -d ';' -f 1 | grep -oE '[0-9]*' )"
        [ -n "$stats_freq" ] && sed -i "s/stats_freq($stats_freq)/stats(freq($stats_freq))/g" "$sng_conf"

        if [ -n "$sng_version_str" ] && \
           [ -n "$sng_conf_verstr" ] && \
           [ "$sng_version_str" != "$sng_conf_verstr" ]
        then
            printf "\n ${red}%34s${std}\n" "version number out of sync!"
            sed -i "s/^${sng_conf_vtag2}${sng_conf_verstr}.*/$sng_conf_vtag1 $sng_version_str/" "$sng_conf"
            printf " ${white}%34s" "$(strip_path "$sng_conf") version ..."
            printf " ${yellow}updated! (%s)${std}\n" "$sng_version_str"
            logger -t "$script_name" "$(strip_path "$sng_conf") version number updated ($sng_version_str)!"
        fi
        if _SysLogMsgSizeFromConfig_ update
        then
            printf "\n ${red}%34s${std}\n" "Log message size out of sync!"
            printf " ${white}%34s" "$(strip_path "$sng_conf") log message size ..."
            printf " ${yellow}updated! (%d)${std}\n" "$sysLogMsgeSizeMAX"
        fi
        if _SysLogFiFoSizeFromConfig_ update
        then
            printf "\n ${red}%34s${std}\n" "Log FIFO size out of sync!"
            printf " ${white}%34s" "$(strip_path "$sng_conf") log FIFO size ..."
            printf " ${yellow}updated! (%d)${std}\n" "$sysLogFiFoSizeMIN"
        fi
        echo
        $S01sng_init start
        Restart_uiScribe
    else
        printf " ${green}in sync. (v%s)${std}\n" "$sng_version_str"
    fi
}

SysLogNg_Config_SyntaxCheck()
{
    printf "$white %34s" "$( strip_path "$sng_conf" ) syntax check ..."
    if $sng_loc -s >> /dev/null 2>&1
    then printf "$green okay! $std\n"
    else printf "$red FAILED! $std\n\n"
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jul-07] ##
##----------------------------------------##
GetScribeVersion()
{
    # only get scribe from github once #
    script_md5="$(MD5_Hash "$script_loc")"
    delfr "$script_tmp_file"
    curl -LSs --retry 4 --retry-delay 5 --retry-connrefused "$script_repoFile" -o "$script_tmp_file"
    [ ! -e "$script_tmp_file" ] && \
    printf "\n\n$white %s GitHub repository is unavailable! -- $red ABORTING! $std\n\n" "$script_name" && exit 1
    github_ver="$( grep -m1 "scribe_ver=" "$script_tmp_file" | grep -oE "$scribeVerRegExp" )"
    github_branch="$( grep -m1 "scribe_branch=" "$script_tmp_file" | awk -F\" '{ printf ( $2 ); }'; )" 
    githubVer_long="$github_ver ($github_branch)"
    github_md5="$(MD5_Hash "$script_tmp_file")"
    new_vers="none"
    if [ "$( VersionStrToNum "$github_ver" )" -lt "$( VersionStrToNum "$scribe_ver" )" ]; then new_vers="older"
    elif [ "$( VersionStrToNum "$github_ver" )" -gt "$( VersionStrToNum "$scribe_ver" )" ]; then new_vers="major"
    elif [ "$script_md5" != "$github_md5" ]; then new_vers="minor"
    fi
    delfr "$script_tmp_file"
}

ShowScribeVersion()
{
    printf "\n ${white}%34s ${green}%s\n" "$script_name installed version:" "$scriptVer_long"
    printf " ${white}%34s ${green}%s${std}\n" "$script_name GitHub version:" "$githubVer_long"
    case "$new_vers" in
        older)
            printf "      ${red}Local %s version GREATER THAN GitHub version!" "$script_name"
            ;;
        major)
            printf " ${yellow}%45s" "New version available for $script_name"
            ;;
        minor)
            printf " ${blue}%45s" "Minor patch available for $script_name"
            ;;
        none)
            printf " ${green}%40s" "$script_name is up to date!"
            ;;
    esac
    printf "${std}\n\n"
}

# Install default file in /opt/etc/$1.d #
setup_ddir()
{
    [ "$1" = "$sng" ] && d_dir="$sngd_d"
    [ "$1" = "$lr"  ] && d_dir="$lrd_d"
    
    for dfile in "${unzip_dirPath}/${1}.d"/*
    do
        dfbase="$( strip_path "$dfile" )"
        ddfile="$d_dir/$dfbase"
        { [ ! -e "$ddfile" ] || [ "$2" = "ALL" ]; } && \
        cp -p "$dfile" "$ddfile"
    done
    chmod 600 "$d_dir"/*
}

# Install example files in /opt/share/$1/examples #
setup_exmpls()
{
    [ "$1" = "$sng" ] && share="$sng_share" && conf="$sng_conf"
    [ "$1" = "$lr"  ] && share="$lr_share" && conf="$lr_conf"
    opkg="${1}.conf-opkg"
    conf_opkg="${conf}-opkg"

    [ "$2" != "ALL" ] && printf "\n$white"
    [ ! -d "$share" ] && mkdir "$share"
    [ ! -d "$share/examples" ] && mkdir "$share/examples"

    for exmpl in "${unzip_dirPath}/${1}.share"/*
    do
        shrfile="$share/examples/$( strip_path "$exmpl" )"
        if [ ! -e "$shrfile" ] || [ "$2" = "ALL" ]
        then
            Update_File "$exmpl" "$shrfile"
        elif ! Same_MD5_Hash "$exmpl" "$shrfile"
        then
            printf " updating %s\n" "$shrfile"
            Update_File "$exmpl" "$shrfile"
        fi
    done

    if [ -e "$conf_opkg" ]
    then
        Update_File "$conf_opkg" "$share/examples/$opkg" "BACKUP"
        delfr "$conf_opkg"
    elif [ ! -e "$share/examples/$opkg" ]
    then
        cp -fp "$conf" "$share/examples/$opkg"
        if [ "$1" = "$sng" ]
        then
            printf "\n$white NOTE: The %s file provided by the Entware %s package sources a very\n" "$( strip_path "$conf" )" "$sng"
            printf " complex set of logging functions most users don't need.$magenta A replacement %s has been\n" "$( strip_path "$conf" )"
            printf " installed to %s$white that corrects this issue. The %s file provided\n" "$conf" "$( strip_path "$conf" )"
            printf " by the Entware package has been moved to $cyan%s$white.\n" "$share/examples/$opkg"
        fi
    fi
    chmod 600 "$share/examples"/*
    printf "$std"
}

Force_Install()
{
    printf "\n$blue %s$white already installed!\n" "$1"
    [ "$1" != "$script_name" ] && printf "$yellow Forcing installation$red WILL OVERWRITE$yellow any modified configuration files!\n"
    printf "$white Do you want to force re-installation of %s [y|n]? $std" "$1"
    Yes_Or_No
    return $?
}

##----------------------------------------##
## Modified by Martinski W. [2026-Jan-15] ##
##----------------------------------------##
SysLogNg_ShowConfig()
{
    if [ -e "$sng_loc" ]
    then
        delfr "$sngconf_merged"
        delfr "$sngconf_error"
        if $sng_loc --preprocess-into="$sngconf_merged" 2> "$sngconf_error"
        then
            printf "\n\n" ; more "$sngconf_merged"
        else 
            printf "\n\n" ; more "$sngconf_error"
        fi
        echo ; PressEnterTo "continue..."
        return 0
    else
        not_installed "$sng"
        echo ; PressEnterTo "continue..."
        return 1
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2026-Jan-15] ##
##----------------------------------------##
Show_SysLogNg_LoadedConfig()
{
    delfr "$sngconf_merged"
    $sngctl_loc config --preprocessed > "$sngconf_merged"
    printf "\n\n" ; more "$sngconf_merged"
    echo ; PressEnterTo "continue..."
}

##-------------------------------------##
## Added by Martinski W. [2025-Dec-05] ##
##-------------------------------------##
_AcquireFLock_()
{
   local opts=""
   eval exec "$LR_FLock_FD>$LR_FLock_FName"
   
   if [ $# -eq 1 ] && [ "$1" = "nonblock" ]
   then opts="-n"
   fi
   flock -x $opts "$LR_FLock_FD"
   return "$?"
}

_ReleaseFLock_()
{ flock -u "$LR_FLock_FD" ; }

##-------------------------------------##
## Added by Martinski W. [2026-Jan-04] ##
##-------------------------------------##
_HasRouterMoreThan512MBtotalRAM_()
{
   local totalRAM_KB
   totalRAM_KB="$(awk -F ' ' '/^MemTotal:/{print $2}' /proc/meminfo)"
   if [ -n "$totalRAM_KB" ] && [ "$totalRAM_KB" -gt 524288 ]
   then return 0
   else return 1
   fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Dec-05] ##
##-------------------------------------##
_Generate_ListOf_Filtered_LogFiles_()
{
    local tmpSysLogList="${HOMEdir}/${script_name}_tempSysLogList_$$.txt"
    local tmpFilterList="${HOMEdir}/${script_name}_tempFltLogList_$$.txt"

    printf '' > "$tmpFilterList"
    [ ! -f "$filteredLogList" ] && printf '' > "$filteredLogList"

    if "$syslogNgCmd" --preprocess-into="$tmpSysLogList"
    then
        while read -r theLINE && [ -n "$theLINE" ]
        do
            logFilePath="$(echo "$theLINE" | sed -e 's/^[ ]*file("//;s/".*$//')"
            if grep -qE "^${logFilePath}$" "$tmpFilterList"
            then continue  #Avoid duplicates#
            fi
            echo "$logFilePath" >> "$tmpFilterList"
        done <<EOT
$(grep -A 1 "^destination" "$tmpSysLogList" | grep -E '[[:blank:]]*file\("/' | grep -v '.*/log/messages')
EOT
    fi

    if ! diff -q "$tmpFilterList" "$filteredLogList" >/dev/null 2>&1
    then
        mv -f "$tmpFilterList" "$filteredLogList"
    fi
    rm -f "$tmpSysLogList" "$tmpFilterList"
}

##-------------------------------------##
## Added by Martinski W. [2025-Dec-05] ##
##-------------------------------------##
_Generate_ListOf_LogFiles_Without_Configs_()
{
    local theLogConfigExp="${logRotateDir}/*"
    local configFilePath  configFileOK  theLogFile

    printf '' > "$noConfigLogList"
    [ ! -s "$filteredLogList" ] && return 1

    while IFS='' read -r theLINE || [ -n "$theLINE" ]
    do
        theLogFile="$(echo "$theLINE" | sed 's/ *$//')"
        configFileOK=false

        for configFilePath in $(ls -1 $theLogConfigExp 2>/dev/null)
        do
            if [ ! -s "$configFilePath" ] || \
               [ "${configFilePath##*/}" = "$logRotateGlobalName" ] || \
               ! grep -qE "$logFilesRegExp" "$configFilePath"
            then continue
            fi
            if grep -qE "$theLogFile" "$configFilePath"
            then
                configFileOK=true ; break
            fi
        done

        if ! "$configFileOK"
        then echo "$theLogFile" >> "$noConfigLogList"
        fi
    done < "$filteredLogList"

    [ ! -s "$noConfigLogList" ] && rm -f "$noConfigLogList"
}

##-------------------------------------##
## Added by Martinski W. [2025-Dec-05] ##
##-------------------------------------##
_DoPostRotateCleanup_()
{
    if [ ! -s "$logRotateGlobalConf" ] && \
       [ ! -s "${logRotateExamplesDir}/$logRotateGlobalName" ] 
    then return 1
    fi
    if [ -s "${config_d}/${logRotateGlobalName}.SAVED" ]
    then
        mv -f "${config_d}/${logRotateGlobalName}.SAVED" "$logRotateGlobalConf"
    else
        cp -fp "${logRotateExamplesDir}/$logRotateGlobalName" "$logRotateGlobalConf"
    fi
    chmod 600 "$logRotateGlobalConf"
}

##-------------------------------------##
## Added by Martinski W. [2025-Dec-05] ##
##-------------------------------------##
_RotateAllLogFiles_Preamble_()
{
    local lineNumInsert
    local tmpLogRotateAction="${HOMEdir}/${script_name}_tempLogRotateAction_$$.txt"

    doPostRotateCleanup=false
    _Generate_ListOf_Filtered_LogFiles_
    _Generate_ListOf_LogFiles_Without_Configs_

    if [ ! -s "$noConfigLogList" ] || \
       { [ ! -s "$logRotateGlobalConf" ] && \
         [ ! -s "${logRotateExamplesDir}/$logRotateGlobalName" ] ; }
    then return 1
    fi

    if [ ! -s "$logRotateGlobalConf" ] || \
       grep -qE "$logFilesRegExp" "$logRotateGlobalConf"
    then
        if [ ! -s "${logRotateExamplesDir}/$logRotateGlobalName" ]
        then return 1
        fi
        cp -fp "${logRotateExamplesDir}/$logRotateGlobalName" "$logRotateGlobalConf"
        chmod 600 "$logRotateGlobalConf"
    fi
    cp -fp "$logRotateGlobalConf" "${config_d}/${logRotateGlobalName}.SAVED"

    lineNumInsert="$(grep -wn -m1 "^endscript" "$logRotateGlobalConf" | cut -d':' -f1)"
    [ -z "$lineNumInsert" ] && return 1
    lineNumInsert="$((lineNumInsert + 1))"

    cat "$noConfigLogList" > "$tmpLogRotateAction"
    cat <<EOF >> "$tmpLogRotateAction"
{
   postrotate
      /usr/bin/killall -HUP syslog-ng
   endscript
}

EOF

    sed -i "${lineNumInsert}r $tmpLogRotateAction" "$logRotateGlobalConf"
    rm -f "$tmpLogRotateAction"
    doPostRotateCleanup=true
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-05] ##
##----------------------------------------##
_DoRotateLogFiles_()
{
    local doPostRotateCleanup=false
    local callType=DORUN  debugLog

    if [ $# -gt 0 ] && [ -n "$1" ]
    then callType="$1"
    fi

    _RotateAllLogFiles_Preamble_

    [ "$callType" = "DORUN" ] && \
    printf "\n$white %34s" "running $lr ..."

    if [ "$callType" != "DEBUG" ]
    then
        rm -f "$lr_daily"
        $logRotateCmd "$logRotateTopConfig" >> "$lr_daily" 2>&1
    else
        if [ $# -gt 1 ] && [ "$2" = "TEMP" ]
        then debugLog="$lr_temp"
        else debugLog="$script_debug"
        fi
        $logRotateCmd -d "$logRotateTopConfig" >> "$debugLog" 2>&1
    fi

    if [ "$callType" = "DORUN" ]
    then
        finished
        printf "\n$magenta checking %s log for errors $cyan\n\n" "$lr"
        tail -v "$lr_daily"
    fi
    sleep 1
    "$doPostRotateCleanup" && _DoPostRotateCleanup_
}

Menu_Status()
{
    Check_SysLogNg
    SysLogd_Check
    printf "\n ${magenta}checking system for necessary %s hooks ...\n\n" "$script_name"
    sed_SysLogNg_Init
    if SyslogNg_Running
    then sed_srvcEvent
    fi
    LogRotate_CronJob_PostMount_Check
    sed_unMount
    if SyslogNg_Running
    then
        LogRotate_CronJob_Check
        Check_Dir_Links
    fi
    printf "\n ${magenta}checking %s configuration ...\n\n" "$sng"
    SysLogNg_Config_Sync
    SysLogNg_Config_SyntaxCheck
    GetScribeVersion
    ShowScribeVersion
}

sng_ver_chk()
{
    sng_vers="$( $sng --version | grep -m1 "$sng" | grep -oE '[0-9]{1,2}([_.][0-9]{1,2})([_.][0-9]{1,2})?' )"
    if [ "$( VersionStrToNum "$sng_vers" )" -lt "$( VersionStrToNum "$sng_reqd" )" ]
    then
        printf "\n$red %s version %s or higher required!\n" "$sng" "$sng_reqd"
        printf "Please update your Entware packages and run %s install again.$cyan\n\n" "$script_name"
        /opt/bin/opkg remove "$sng"
        printf "$std\n\n"
        exit 1
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2026-Jan-30] ##
##----------------------------------------##
Setup_SysLogNG()
{
    printf "\n ${magenta}setting up %s ...${std}\n" "$sng"
    Copy_SysLogNg_RcFunc
    Copy_LogRotate_Global_Options force
    sed_SysLogNg_Init
    sed_srvcEvent
    sed_unMount
    if ! Same_MD5_Hash "$sng_share/examples/${sng}.conf-scribe" "$sng_conf"
    then
        printf " ${white}%34s" "updating $(strip_path "$sng_conf") ..."
        Update_File "$sng_share/examples/${sng}.conf-scribe" "$sng_conf" "BACKUP"
        finished
    fi
    SysLogNg_Config_Sync
}

Setup_LogRotate()
{
    # Assumes since Entware is required/installed, post-mount exists and is properly executable #
    printf "\n ${magenta}setting up %s ...\n" "$lr"
    LogRotate_CronJob_PostMount_Check
    LogRotate_CronJob_Check
}

##----------------------------------------##
## Modified by Martinski W. [2025-Aug-23] ##
##----------------------------------------##
Do_Install()
{
    forceOpt=""
    if [ $# -gt 1 ] && [ "$2" = "FORCE" ]
    then forceOpt="--force-reinstall"
    fi
    printf "\n$cyan"
    /opt/bin/opkg install $forceOpt "$1"
    [ "$1" = "$sng" ] && sng_ver_chk
    setup_ddir "$1" "ALL"
    setup_exmpls "$1" "ALL"
    [ "$1" = "$sng" ] && Setup_SysLogNG
    [ "$1" = "$lr"  ] && Setup_LogRotate
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-09] ##
##----------------------------------------##
Setup_Scribe()
{
    printf "\n ${white}setting up %s ...\n" "$script_name"
    cp -fp "$unzip_dirPath/${script_name}.sh" "$script_loc"
    chmod 0755 "$script_loc"
    [ ! -e "/opt/bin/$script_name" ] && ln -s "$script_loc" /opt/bin

    # Install correct firewall or skynet file, these are mutually exclusive #
    if "$skynet_inst"
    then
        delfr "$sngd_d/firewall"
        delfr "$lrd_d/firewall"
        if [ ! -e "$sngd_d/skynet" ] || [ "$1" = "ALL" ]
        then
            printf "$white installing %s Skynet filter ...\n" "$sng"
            cp -p "$sng_share/examples/skynet" "$sngd_d" 
        fi
        printf "$blue setting Skynet log file location$white ...\n"
        skynetlog="$( grep -m1 'file("' $sngd_d/skynet | awk -F\" '{ printf ( $2 ); }'; )"
        sh $skynet settings syslog "$skynetlog" > /dev/null 2>&1
    else
        delfr "$sngd_d/skynet"
        delfr "$lrd_d/skynet"
        if [ ! -e "$sngd_d/firewall" ] || [ "$1" = "ALL" ]
        then
            printf "$white installing %s firewall filter ...\n" "$sng"
            cp -p "$sng_share/examples/firewall" "$sngd_d"
            printf "$white installing firewall log rotation ...\n"
            cp -p "$lr_share/examples/firewall" "$lrd_d"
        fi
    fi
    finished
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-09] ##
##----------------------------------------##
Install_uiScribe()
{
    uiscribeVer="$(curl -fsL --retry 4 --retry-delay 5 "$uiscribeRepo" | grep "SCRIPT_VERSION=" | grep -m1 -oE "$uiscribeVerRegExp")"
    printf "\n$white Would you like to install$cyan %s %s$white, a script by Jack Yaz\n" "$uiscribeName" "$uiscribeVer"
    printf " that modifies the webui$yellow System Log$white page to show the various logs\n"
    printf " generated by %s in individual drop-down windows [y|n]? " "$sng"
    if Yes_Or_No
    then
        printf "\n"
        curl -LSs --retry 4 --retry-delay 5 --retry-connrefused "$uiscribeRepo" -o "$uiscribePath" && \
        chmod 0755 "$uiscribePath" && $uiscribePath install
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-09] ##
##----------------------------------------##
Uninstall_uiScribe()
{
    printf "\n"
    if "$uiScribeInstalled"
    then
        printf "$white $uiscribeName add-on is detected, uninstalling ...\n\n"
        $uiscribePath uninstall
    fi
}

PreInstall_Check()
{
    # Check for required components #
    reqsOK=true

    # Check if Entware & ASUSWRT-Merlin are installed and Merlin version number #
    if [ ! -x "/opt/bin/opkg" ]   || \
       [ "$fwName" != "$wrtMerlin" ] || \
       [ "$( VersionStrToNum "$fwVerBuild" )" -lt "$( VersionStrToNum "$fwVerReqd" )" ]
    then
        printf "\n\n$red %s version %s or later with Entware is required! $std\n" "$wrtMerlin" "$fwVerReqd"
        reqsOK=false
    fi

    # Check if diversion is installed and version number #
    if [ -x "$divers" ]
    then
        printf "\n\n$white Diversion detected, checking version ..."
        div_ver="$( grep -m1 "VERSION" $divers | grep -oE '[0-9]{1,2}([.][0-9]{1,2})' )"
        printf " version %s detected ..." "$div_ver"
        if [ "$( VersionStrToNum "$div_ver" )" -lt "$( VersionStrToNum "$div_req" )" ]
        then
            printf "$red update required!\n"
            printf " Diversion %s or later is required! $std\n" "$div_req"
            reqsOK=false
        else
            printf "$green okay! $std\n"
        fi
    fi

    # check if Skynet is installed and version number #
    if "$skynet_inst"
    then
        printf "\n\n$white Skynet detected, checking version ..."
        sky_ver="$( grep -m1 -oE 'v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})' "$skynet" )"
        printf " version %s detected ..." "$sky_ver"
        if [ "$( VersionStrToNum "$sky_ver" )" -lt "$( VersionStrToNum "$sky_req" )" ]
        then
            printf "$red update required!\n"
            printf " Skynet %s or later is required! $std\n" "$sky_req"
            reqsOK=false
        else
            printf "$green okay! $std\n"
        fi
    else
        printf "$white\n\n Skynet is$red NOT$white installed on this system!\n\n"
        printf " If you plan to install Skynet, it is recommended\n"
        printf " to stop %s installation now and install Skynet\n" "$script_name"
        printf " using amtm (https://github.com/decoderman/amtm).\n\n"
        printf " If Skynet is installed after %s, run \"%s install\"\n" "$script_name" "$script_name"
        printf " and force installation to configure %s and Skynet\n" "$script_name"
        printf " to work together.\n\n"
        if "$reqsOK"
        then
            printf " Do you want to continue installation of %s [y|n]? $std" "$script_name"
            if ! Yes_Or_No
            then
                reqsOK=false
            fi
        fi
    fi

    # Exit if requirements NOT met #
    if ! "$reqsOK"
    then
        printf "\n\n$magenta exiting %s installation. $std\n\n" "$script_name"
        delfr "$script_loc"
        exit 1
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2026-Jan-30] ##
##----------------------------------------##
Menu_Install()
{
    if [ ! -e "$sng_loc" ]
    then
        Do_Install "$sng"
    elif Force_Install "$sng"
    then
        $S01sng_init stop
        Do_Install "$sng" "FORCE"
    fi
    echo
    rm -f "$syslogNg_WaitnSEM_FPath"
    echo '1' > "$syslogNg_StartSEM_FPath"
    printf '' > "$syslogD_InitRebootLogFPath"
    $S01sng_init start

    if [ ! -e "$lr_loc" ]
    then
        Do_Install "$lr"
    elif Force_Install "$lr"
    then
        Do_Install "$lr" "FORCE"
    fi

    if _AcquireFLock_ nonblock
    then
        _DoRotateLogFiles_
        _ReleaseFLock_
    else
        printf "\n${red} Unable to acquire lock to run logrotate.${std}\n"
        printf "\n${red} The program may be currently running.${std}\n\n"
    fi

    if ! "$scribeInstalled"
    then
        Setup_Scribe "ALL"
    elif Force_Install "$script_name script"
    then
        Setup_Scribe "ALL"
    fi

    Reload_SysLogNg_Config
    printf "\n$white %s setup complete!\n\n" "$script_name"
    PressEnterTo "continue..."
    if ! "$uiScribeInstalled"
    then Install_uiScribe
    fi
}

Menu_Restart()
{
    if SyslogNg_Running
    then
        printf "\n ${yellow}Restarting %s...${std}\n" "$sng"
        $S01sng_init restart
    else
        printf "\n ${white}%s ${red}NOT${white} running! ${yellow}Starting...${std}\n" "$sng"
        $S01sng_init start
    fi
    sleep 2  #Allow time to start up#
    Restart_uiScribe
}

##-------------------------------------##
## Added by Martinski W. [2026-Jan-30] ##
##-------------------------------------##
_MoveLogMsgsToSystemLogFile_()
{
    local lastNLines  logNumLines  logFileSize

    ## Do NOT move very large files into JFFS/TMPFS ##
    lastNLines=100
    logNumLines="$(wc -l < "$optmsg")"
    logFileSize="$(_GetFileSize_ "$optmsg")"

    if [ "$(echo "$logFileSize $twoMByte" | awk -F ' ' '{print ($1 < $2)}')" -eq 1 ]
    then
        head -n -$lastNLines "$optmsg" > "${syslog_loc}-1"
    else
        if [ "$logNumLines" -le "$sysLogLinesMAX" ]
        then
            head -n -$lastNLines "$optmsg" > "${syslog_loc}-1"
        else
            startNum="$((logNumLines - sysLogLinesMAX))"
            tail -n +"$startNum" "$optmsg" | head -n -$lastNLines > "${syslog_loc}-1"
        fi
    fi
    tail -n $lastNLines "$optmsg" > "$syslog_loc"
}

##----------------------------------------##
## Modified by Martinski W. [2026-Jan-30] ##
##----------------------------------------##
StopSyslogNg()
{
    local messagesLogSAVED="${optmsg}.Scribe_SAVED.LOG"

    printf "\n ${white}Stopping %s...\n" "$sng"
    $S01sng_init stop
    # Remove any syslog links #
    Clear_Syslog_Links

    ##OFF##_MoveLogMsgsToSystemLogFile_
    printf '' > "$syslog_loc"
    printf '' > "${syslog_loc}-1"
    printf '' > "$syslogD_InitRebootLogFPath"

    if [ -s "$optmsg" ]
    then
        mv -f "$optmsg" "$messagesLogSAVED"
    fi
    ln -snf "$syslog_loc" "$optmsg"

    if [ "$syslog_loc" = "$jffslog" ]
    then
        ln -snf "$syslog_loc" "$tmplog"
        ln -snf "${syslog_loc}-1" "${tmplog}-1"
    fi

    printf " ${white}Starting system klogd and syslogd..."
    Start_SyslogD
    if ! "$banner"
    then return 0
    fi
    printf "\n ${yellow}%s will be started at the next router reboot.\n" "$sng"
    printf " You may type ${green}%s restart${yellow} at the shell prompt, or\n" "$script_name"
    printf " select '${green}rs${yellow}' from %s menu to restart %s.${std}\n\n" "$script_name" "$sng"
}

StopLogRotate()
{
    if cru l | grep -q "#${LR_CronTagStr}#"
    then cru d "$LR_CronTagStr"
    fi
}

Menu_Stop()
{
    StopSyslogNg
    StopLogRotate
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-05] ##
##----------------------------------------##
doUninstall()
{
    printf "\n\n"
    banner=false  # Suppress certain messages #
    if [ -e "$sng_loc" ]
    then
        if SyslogNg_Running
        then StopSyslogNg
        fi
        sed -i "/$script_name stop nologo/d" "$unMount"
        sed -i "/$script_name service_event/d" "$srvcEvent"
        delfr "$S01sng_init"
        delfr "$rcfunc_loc"
        printf "\n$cyan"
        /opt/bin/opkg remove "$sng"
        delfr "$sng_conf"
        delfr "$sngd_d"
        delfr "$sng_share"

        if "$skynet_inst" && ! "$reinst"
        then
            printf "$white restoring Skynet logging to %s ..." "$syslog_loc"
            sh $skynet settings syslog "$syslog_loc" > /dev/null 2>&1
        fi
    else
        not_installed "$sng"
    fi

    if [ -e "$lr_loc" ]
    then
        StopLogRotate
        sed -i "/cru a ${logRotateStr}/d" "$postMount"
        sed -i "/cru a ${LR_CronTagStr}/d" "$postMount"
        printf "\n$cyan"
        /opt/bin/opkg remove "$lr"
        delfr "$lr_conf"
        delfr "$lrd_d"
        delfr "$lr_share"
        delfr "$lr_daily"
    else
        not_installed "$lr"
    fi

    delfr "$unzip_dirPath"
    delfr "$script_zip_file"
    delfr "/opt/bin/$script_name"
    delfr "$script_loc"
    scribeInstalled=false
    if ! "$reinst"
    then
        printf "\n$white %s, %s, and %s have been removed from the system.\n" "$sng" "$lr" "$script_name"
        printf " It is recommended to reboot the router at this time.  If you do not\n"
        printf " wish to reboot the router, press ${blue}<Ctrl-C>${std} now to exit.\n\n"
        PressEnterTo "reboot:"
        service reboot; exit 0
    fi
}

Menu_Uninstall()
{
    andre="remove"
    uni="UN"
    if "$reinst"
    then
        andre="remove and reinstall"
        uni="RE"
    fi
    warning_sign
    printf "    This will completely$magenta %s$yellow %s$white and$yellow %s$white.\n" "$andre" "$sng" "$lr"
    printf "    Ensure you have backed up any configuration files you wish to keep.\n"
    printf "    All configuration files in$yellow %s$white,$yellow %s$white,\n" "$sngd_d" "$lrd_d"
    printf "   $yellow %s$white, and$yellow %s$white will be deleted!\n" "$sng_share" "$lr_share"
    warning_sign
    printf "    Type YES to$magenta %s$yellow %s$white: $std" "$andre" "$script_name"
    read -r wipeit
    case "$wipeit" in
        YES)
            if ! "$reinst" ; then Uninstall_uiScribe ; fi
            doUninstall
            ;;
        *)
            do_inst=false
            printf "\n\n$white *** %sINSTALL ABORTED! ***$std\n\n" "$uni"
            ;;
    esac
}

Menu_Filters()
{
    printf "\n$white    Do you want to update$yellow %s$white and$yellow %s$white filter files?\n" "$sng" "$lr"
    printf "$cyan        1) Adds any new files to$yellow %s$cyan directories\n" "$share_ex"
    printf "           and updates any example files that have changed.\n"
    printf "        2) Adds any new files to$yellow %s$cyan directories.\n" "$etc_d"
    printf "        3) Asks to update existing files in$yellow %s$cyan directories\n" "$etc_d"
    printf "$magenta           _IF_$cyan a corresponding file exists in$yellow %s$cyan,\n" "$share_ex"
    printf "$magenta           _AND_$cyan it is different from the file in$yellow %s$cyan.\n" "$etc_d"
    printf "$white           NOTE:$cyan You will be provided an opportunity to review\n"
    printf "           the differences between the existing file and the\n"
    printf "           proposed update.\n\n"
    printf "$yellow    If you are unsure, you should answer 'y' here; any changes to\n"
    printf "    the running configuration will require confirmation.\n\n"
    printf "$white        Update filter files? [y|n] $std"
    if Yes_Or_No
    then
        Get_ZIP_File
        for pckg in $sng $lr
        do
            setup_ddir "$pckg" "NEW"
            setup_exmpls "$pckg" "NEWER"
            check_dir="$( echo "$etc_d" | sed "s/\*/$pckg/" )"
            comp_dir="$( echo "$share_ex" | sed "s/\*/$pckg/" )"
            for upd_file in "$check_dir"/*
            do
                comp_file="$comp_dir/$( strip_path "$upd_file" )"
                if [ -e "$comp_file" ] && ! Same_MD5_Hash "$upd_file" "$comp_file"
                then
                    processed=false
                    printf "\n$white Update available for$yellow %s$white.\n" "$upd_file"
                    while ! $processed
                    do
                        printf "    (a)ccept, (r)eject, or (v)iew diff for this file? "
                        read -r dispo
                        case "$dispo" in
                            a)
                                Update_File "$comp_file" "$upd_file"
                                printf "\n ${green}%s updated!${std}\n" "$upd_file"
                                processed=true
                                ;;
                            r)
                                printf "\n ${magenta}%s not updated!${std}\n" "$upd_file"
                                processed=true
                                ;;
                            v)
                                echo
                                diff "$upd_file" "$comp_file" | more
                                echo
                                ;;
                            *)
                                echo
                                ;;
                        esac
                    done
                fi
            done
        done
        printf "\n ${white}%s and %s example files updated!${std}\n" "$sng" "$lr"
        Reload_SysLogNg_Config
    else
        printf "\n ${white}%s and %s example files ${red}not${white} updated!${std}\n" "$sng" "$lr"
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2026-Jan-30] ##
##----------------------------------------##
Menu_Update()
{
    local doUpdate=false

    if [ $# -eq 0 ] || [ -z "$1" ]
    then
        if [ "$new_vers" = "major" ] || [ "$new_vers" = "minor" ]
        then
            if [ "$new_vers" = "major" ]
            then printf "\n    ${green}New version"
            else printf "\n    ${cyan}Minor patch"
            fi
            printf " ${white}available!\n"
            printf "    Do you wish to upgrade? [y|n]${std}  "
        else
            printf "\n    ${white}No new version available. GitHub version"
            if [ "$new_vers" = "none" ]
            then printf " equal to"
            else printf " ${red}LESS THAN$white"
            fi
            printf " local version.\n"
            printf "    Do you wish to force re-installation of %s? [y|n]${std}  " "$script_name"
        fi
        Yes_Or_No && doUpdate=true || doUpdate=false
    fi

    if { [ $# -gt 0 ] && [ "$1" = "force" ] ; } || "$doUpdate"
    then
        Get_ZIP_File
        Setup_Scribe "NEWER"
        Copy_SysLogNg_RcFunc
        Copy_SysLogNg_Top_Config "$@"
        Copy_LogRotate_Global_Options "$@"
        printf "\n ${white}%s updated!${std}\n" "$script_name"
        rm -f "$syslogNg_WaitnSEM_FPath"
        echo '1' > "$syslogNg_StartSEM_FPath"
        printf '' > "$syslogD_InitRebootLogFPath"
        sh "$script_loc" filters gotzip nologo
        sh "$script_loc" status nologo
        run_scribe=true
    else
        printf "\n        ${white}*** %s ${red}NOT${white} updated! *** ${std}\n\n" "$script_name"
    fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Jul-07] ##
##-------------------------------------##
Update_Version()
{
   if SyslogNg_Running
   then
       GetScribeVersion
       ShowScribeVersion
       Menu_Update "$@"
   else
       not_recog=true
   fi
}

menu_forgrnd()
{
    local doStart=false
    if SyslogNg_Running
    then
        warning_sign
        printf " %s is currently running; starting the debugging\n" "$sng"
        printf " mode is usually not necessary if %s is running.\n" "$sng"
        printf " Debugging mode is intended for troubleshooting when\n"
        printf " %s will not start.\n\n" "$sng"
        printf " Are you certain you wish to start debugging mode [y|n]? $std"
        if ! Yes_Or_No; then return 1; fi
        doStart=true
    fi
    printf "\n$yellow NOTE: If there are no errors, debugging mode will\n"
    printf "       continue indefinitely. If this happens, type\n"
    printf "       <Ctrl-C> to halt debugging mode output.\n\n"
    PressEnterTo "start:"
    if "$doStart"
    then $S01sng_init stop; echo
    fi
    trap '' 2
    $sng_loc -Fevd
    trap - 2
    if "$doStart"
    then echo ; $S01sng_init start
    fi
    echo
}

##----------------------------------------##
## Modified by Martinski W. [2025-Aug-24] ##
##----------------------------------------##
Gather_Debug()
{
    local debugTarball="${script_debug}.tar.gz"
    delfr "$script_debug" "$debugTarball"

    printf "\n$white gathering debugging information...\n"
    GetScribeVersion

    {
        printf "%s\n" "$debug_sep"
        printf "### %s\n" "$(date +'%Y-%b-%d %I:%M:%S %p %Z (%a)')"
        printf "### Scribe Version: %s\n" "$scriptVer_long"
        printf "### Local Scribe md5:  %s\n" "$script_md5"
        printf "### GitHub Version: %s\n" "$githubVer_long"
        printf "### GitHub Scribe md5: %s\n" "$github_md5"
        printf "### Router: %s (%s)\n" "$model" "$arch"
        printf "### Firmware Version: %s %s\n" "$fwName" "$fwVersFull"
        printf "\n%s\n### check running log processes:\n" "$debug_sep"
        ps | grep -E "syslog|logrotate" | grep -v 'grep'
        printf "\n%s\n### check crontab:\n" "$debug_sep"
        cru l | grep "$lr"
        printf "\n%s\n### directory checks:\n" "$debug_sep"
        ls -ld /tmp/syslog*
        ls -ld /jffs/syslog*
        ls -ld "$optmsg"
        ls -ld "$script_conf"
        printf "\n%s\n### top output:\n" "$debug_sep"
        top -b -n1 | head -n 20
        printf "\n%s\n### log processes in top:\n" "$debug_sep"
        top -b -n1 | grep -E "syslog|logrotate" | grep -v 'grep'
        printf "\n%s\n### init.d directory:\n" "$debug_sep"
        ls -l /opt/etc/init.d
        printf "\n%s\n### check logrotate.status \n" "$debug_sep"
        ls -l /var/lib/logrotate.status
        printf "\n%s\n### contents of S01syslog-ng\n" "$debug_sep"
        cat /opt/etc/init.d/S01syslog-ng
        printf "\n%s\n### /opt/var/log directory:\n" "$debug_sep"
        ls -l /opt/var/log
        printf "\n%s\n### installed packages:\n" "$debug_sep"
        /opt/bin/opkg list-installed
        printf "\n%s\n### %s running configuration:\n" "$debug_sep" "$sng"
    } >> "$script_debug"

    if SyslogNg_Running
    then
        $sngctl_loc config --preprocessed >> "$script_debug"
    else
        printf "#### %s not running! ####\n%s\n" "$sng" "$debug_sep" >> "$script_debug"
    fi
    printf "\n%s\n### %s on-disk syntax check:\n" "$debug_sep" "$sng" >> "$script_debug"
    delfr "$sngconf_merged"
    delfr "$sngconf_error"
    $sng_loc --preprocess-into="$sngconf_merged" 2> "$sngconf_error"
    cat "$sngconf_merged" >> "$script_debug"
    if [ -s "$sngconf_error" ]
    then
        {
            printf "#### SYSLOG-NG SYNTAX ON-DISK CHECK FAILED! SEE BELOW ####\n"
            cat "$sngconf_error"
            printf "###### END SYSLOG-NG ON-DISK SYNTAX FAILURE OUTPUT ######\n"
        } >> "$script_debug"
    else
        printf "#### syslog-ng on-disk syntax check okay! ####\n" >> "$script_debug"
    fi

    printf "\n%s\n### logrotate debug output:\n" "$debug_sep" >> "$script_debug"
    if _AcquireFLock_
    then
        _DoRotateLogFiles_ DEBUG
        _ReleaseFLock_
    else
        printf "\nUnable to acquire lock to run logrotate.\n" >> "$script_debug"
        printf "\nThe program may be currently running.\n\n"  >> "$script_debug"
    fi

    printf "\n%s\n### Skynet log locations:\n" "$debug_sep" >> "$script_debug"
    if "$skynet_inst"
    then
        skynetloc="$( grep -ow "skynetloc=.* # Skynet" $fire_start 2>/dev/null | grep -vE "^#" | awk '{print $1}' | cut -c 11- )"
        skynetcfg="${skynetloc}/skynet.cfg"
        grep "syslog" "$skynetcfg" >> "$script_debug"
    else
        printf "#### Skynet not installed! ####\n%s\n" "$debug_sep" >> "$script_debug"
    fi
    printf "\n%s\n### end of output ###\n" "$debug_sep" >> "$script_debug"

    printf " Redacting username and USB drive names...\n"
    redact="$( echo "$USER" | awk  '{ print substr($0, 1, 8); }' )"
    sed -i "s/$redact/redacted/g" "$script_debug"
    mntNum=0
    for usbMount in /tmp/mnt/*
    do
        usbDrive="$(basename "$usbMount")"
        # note that if the usb drive name has a comma in it, then sed will fail #
        if [ -z "$(echo "$usbDrive" | grep ',')" ]
        then
            sed -i "s,${usbDrive},usb#${mntNum},g" "$script_debug"
        else
            printf "\n\n    USB drive $cyan%s$white has a comma in the drive name,$red unable to redact!$white\n\n" "$usbDrive"
        fi
        mntNum="$((mntNum + 1))"
    done

    printf " Creating tarball...\n"
    tar -zcvf "$debugTarball" -C "$TMP" "$script_debug_name" >/dev/null 2>&1
    finished
    printf "\n$std Debug output stored in $cyan%s$std, please review this file\n" "$script_debug"
    printf " to ensure you understand what information is being disclosed.\n\n"
    printf " Tarball of debug output is ${cyan}%s${std}\n" "$debugTarball"
}

menu_backup()
{
    printf "\n$white Backing up %s and %s Configurations ... \n" "$sng" "$lr"
    AppendDateTimeStamp "$script_bakname"
    tar -zcvf "$script_bakname" "$sng_conf" "$sngd_d" "$lr_conf" "$lrd_d" "$config_d"
    printf "\n$std Backup data is stored in $cyan%s$std.\n\n" "$script_bakname"
}

menu_restore()
{
    warning_sign
    printf " This will overwrite $yellow%s$white and $yellow%s$white,\n" "$sng_conf" "$lr_conf"
    printf " and replace all files in $yellow%s$white and $yellow%s$white!!\n" "$sngd_d" "$lrd_d"
    printf " The file must be named $cyan%s$white.\n\n" "$script_bakname"
    if [ ! -e "$script_bakname" ]
    then
        printf "   Backup file $magenta%s$white missing!!\n\n" "$script_bakname"
    else
        printf " Are you SURE you want to restore from $cyan%s$white (type YES to restore)? $std" "$script_bakname"
        read -r rstit
        case "$rstit" in
            YES)
                printf "\n$white Restoring %s and %s Configurations ... \n" "$sng" "$lr"
                delfr "$sngd_d"
                delfr "$lrd_d"
                tar -zxvf "$script_bakname" -C /
                chmod 600 "$sngd_d"/*
                chmod 600 "$lrd_d"/*
                printf "\n$std Backup data has been restored from $cyan%s$std.\n" "$script_bakname"
                Menu_Restart
                Menu_Status
                ;;
            *)
                printf "\n\n$white *** RESTORE ABORTED! ***$std\n\n"
                ;;
        esac
    fi
}

##-------------------------------------##
## Added by Martinski W. [2026-Jan-10] ##
##-------------------------------------##
_Create_SysLogNgStartDelay_BGScript_()
{
    cat << 'EOFT' > "$bgScript_FPath"
#!/bin/sh
# Script to delay starting syslog-ng service (created by Scribe)
#
set -u

readonly scriptFName="${0##*/}"
readonly TEMP_DIR="/tmp/var/tmp"
readonly logDateTime="%Y-%b-%d %I:%M:%S %p %Z"
readonly logFilePath="${TEMP_DIR}/${scriptFName%.*}.LOG"
readonly syslogNg_WaitnSEM_FPath="${TEMP_DIR}/scribe_SysLogNg.WAITN.SEM"
readonly syslogNg_StartSEM_FPath="${TEMP_DIR}/scribe_SysLogNg.START.SEM"

readonly S01syslogNg_srvc="/opt/etc/init.d/S01syslog-ng"
readonly logTagStr="${scriptFName}_[$$]"

export PATH="/sbin:/bin:/usr/sbin:/usr/bin:$PATH"

_LogDebugMsg_()
{
   local timeNow="$(date +"$logDateTime")"
   if [ $# -gt 1 ] && [ "$2" = "_START_" ]
   then echo "${timeNow}: $1"  > "$logFilePath"
   else echo "${timeNow}: $1" >> "$logFilePath"
   fi
   if [ $# -gt 1 ] && [ "$2" != "false" ]
   then logger -t "$logTagStr" "$1"
   fi
}

trap '' HUP

_LogDebugMsg_ "Start of Background Script [$scriptFName][$$]" _START_

tempSecs=0
sleepSecs=5
checkSecs=30
cntSleepSecs=0
sleepSecsMIN=120   #2.0 mins#
minSleepSecs=150   #2.5 mins#
sleepSecsMAX=210   #3.5 mins#
readyToStart=false
timeCheckStatus=true
sysLogNg_Param=""

if [ -s "$syslogNg_WaitnSEM_FPath" ]
then
    tempSecs="$(head -n1 "$syslogNg_WaitnSEM_FPath")"
    if echo "$tempSecs" | grep -qE "^[1-3][0-9]{2}$" && \
       [ "$tempSecs" -ge "$sleepSecsMIN" ] && [ "$tempSecs" -le "$sleepSecsMAX" ]
    then minSleepSecs="$tempSecs"
    fi
fi
echo "$minSleepSecs" > "$syslogNg_WaitnSEM_FPath"

while true
do
    if ! "$readyToStart" && \
       "$timeCheckStatus" && \
       [ -x /opt/bin/opkg ] && \
       [ -x "$S01syslogNg_srvc" ] && \
       [ "$(nvram get ntp_ready)" = "1" ] && \
       [ "$(nvram get start_service_ready)" = "1" ] && \
       [ "$(nvram get success_start_service)" = "1" ]
    then readyToStart=true
    fi
    if "$readyToStart" && [ "$cntSleepSecs" -ge "$minSleepSecs" ]
    then
        if [ -z "$(pidof syslog-ng)" ]
        then sysLogNg_Param=start
        else sysLogNg_Param=restart
        fi

        rm -f "$syslogNg_WaitnSEM_FPath"
        _LogDebugMsg_ "Calling [$S01syslogNg_srvc $sysLogNg_Param]..." true
        echo "$cntSleepSecs" > "$syslogNg_StartSEM_FPath"
        nohup "$S01syslogNg_srvc" "$sysLogNg_Param" &
        _LogDebugMsg_ "Exiting Background Loop [$cntSleepSecs][$$]..." true
        break
    fi
    if [ "$cntSleepSecs" -ge "$sleepSecsMAX" ]
    then
        rm -f "$syslogNg_WaitnSEM_FPath"
        _LogDebugMsg_ "Exiting Background Loop [$cntSleepSecs][$$]..." true
        break  #Escape WITHOUT starting service??#
    fi
    if "$timeCheckStatus"
    then
        _LogDebugMsg_ "Sleeping $checkSecs secs [$cntSleepSecs][$$]..." true
    fi
    sleep "$sleepSecs"
    cntSleepSecs="$((cntSleepSecs + sleepSecs))"
    echo "$((minSleepSecs - cntSleepSecs))" > "$syslogNg_WaitnSEM_FPath"
    if [ "$((cntSleepSecs % checkSecs))" -eq 0 ]
    then timeCheckStatus=true
    else timeCheckStatus=false
    fi
done

_LogDebugMsg_ "End of Background Script [$scriptFName][$$]" false
rm -f "$0"

#EOF#
EOFT

   chmod a+x "$bgScript_FPath"
}

##-------------------------------------##
## Added by Martinski W. [2026-Jan-10] ##
##-------------------------------------##
_Launch_SysLogNgStartDelay_BGScript_()
{
    local taskPID  logTag="${script_name}_$$"
    local bgScript_FName="scribe_SysLogNg_Delay.sh"
    local bgScript_FPath="${TEMPdir}/$bgScript_FName"

    if [ -s "$bgScript_FPath" ] && \
       [ -x "$bgScript_FPath" ] && \
       [ -n "$(pidof "$bgScript_FName")" ]
    then
        logger -st "$logTag" -p 4 "INFO: Script [$bgScript_FName] is already running..."
        return 1
    fi

    _Create_SysLogNgStartDelay_BGScript_

    if [ ! -s "$bgScript_FPath" ] || [ ! -x "$bgScript_FPath" ]
    then
        logger -st "$logTag" -p 3 "**ERROR**: Script [$bgScript_FPath] NOT found."
        return 1
    fi

    "$bgScript_FPath" & taskPID=$!
    logger -st "$logTag" -p 5 "INFO: Background script [$bgScript_FName] started. PID: [$taskPID]"
}

##-------------------------------------##
## Added by Martinski W. [2026-Jan-10] ##
##-------------------------------------##
_Create_SysLoggerCheck_BGScript_()
{
    cat << 'EOFT' > "$bgScript_FPath"
#!/bin/sh
# Script to check for system loggers (created by Scribe)
#
set -u

readonly scriptFName="${0##*/}"
readonly TEMP_DIR="/tmp/var/tmp"
readonly logDateTime="%Y-%b-%d %I:%M:%S %p %Z"
readonly logFilePath="${TEMP_DIR}/${scriptFName%.*}.LOG"

export PATH="/sbin:/bin:/usr/sbin:/usr/bin:$PATH"

_LogDebugMsg_()
{
   local timeNow="$(date +"$logDateTime")"
   if [ $# -gt 1 ] && [ "$2" = "_START_" ]
   then echo "${timeNow}: $1"  > "$logFilePath"
   else echo "${timeNow}: $1" >> "$logFilePath"
   fi
}

trap '' HUP

_LogDebugMsg_ "Start of Background Script [$scriptFName][$$]" _START_

readyOK=false
klogdEXIT=false
syslogdEXIT=false

tryCount=0
maxCount=30

while true
do
    usleep 500000  #0.5 sec#
    [ -z "$(pidof klogd)" ] && klogdEXIT=true
    [ -z "$(pidof syslogd)" ] && syslogdEXIT=true
    if "$klogdEXIT" && "$syslogdEXIT"
    then
        _LogDebugMsg_ "System loggers [klogd & syslogd] were terminated."
        _LogDebugMsg_ "Exiting Background Loop [$tryCount][$$]..."
        break
    fi
    if [ "$tryCount" -gt "$maxCount" ]
    then
        _LogDebugMsg_ "Exiting Background Loop [$tryCount][$$]..."
        break  #Something went wrong#
    fi
    [ -n "$(pidof klogd)" ] && killall -q klogd
    [ -n "$(pidof syslogd)" ] && killall -q syslogd

    _LogDebugMsg_ "Sleeping [$tryCount][$$]..."
    sleep 1
    tryCount="$((tryCount + 1))"
done

_LogDebugMsg_ "End of Background Script [$scriptFName][$$]"
rm -f "$0"

#EOF#
EOFT

   chmod a+x "$bgScript_FPath"
}

##-------------------------------------##
## Added by Martinski W. [2026-Jan-10] ##
##-------------------------------------##
_Launch_SysLoggerCheck_BGScript_()
{
    local taskPID  logTag="${script_name}_$$"
    local bgScript_FName="scribe_SysLogger_Check.sh"
    local bgScript_FPath="${TEMPdir}/$bgScript_FName"

    if [ -s "$bgScript_FPath" ] && \
       [ -x "$bgScript_FPath" ] && \
       [ -n "$(pidof "$bgScript_FName")" ]
    then
        logger -st "$logTag" -p 4 "INFO: Script [$bgScript_FName] is already running..."
        return 1
    fi

    _Create_SysLoggerCheck_BGScript_

    if [ ! -s "$bgScript_FPath" ] || [ ! -x "$bgScript_FPath" ]
    then
        logger -st "$logTag" -p 3 "**ERROR**: Script [$bgScript_FPath] NOT found."
        return 1
    fi

    "$bgScript_FPath" & taskPID=$!
}

##----------------------------------------##
## Modified by Martinski W. [2024-Jul-07] ##
##----------------------------------------##
Menu_About()
{
    printf "$menuSepStr"
    printf " About ${magenta}${SCRIPT_VERS_INFO}${CLRct}\n"
    cat <<EOF
  $script_name replaces the firmware system logging service with
  syslog-ng (https://github.com/syslog-ng/syslog-ng/releases),
  which facilitates breaking the monolithic logfile provided by
  syslog into individualized log files based on user criteria.

 License
  $script_name is free to use under the GNU General Public License
  version 3 (GPL-3.0) https://opensource.org/licenses/GPL-3.0

 Help & Support
  https://www.snbforums.com/forums/asuswrt-merlin-addons.60/?prefix_id=7

 Source code
  https://github.com/AMTM-OSR/scribe
EOF
    printf "${CLRct}\n"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Jul-07] ##
##----------------------------------------##
Menu_Help()
{
    printf "$menuSepStr"
    printf " HELP ${magenta}${SCRIPT_VERS_INFO}${CLRct}\n"
    cat <<EOF
 Available commands:
  $script_name about                explains functionality
  $script_name install              installs script
  $script_name remove / uninstall   uninstalls script
  $script_name update               checks for script updates
  $script_name forceupdate          updates to latest version (force update)
  $script_name [show-]config        checks on-disk syslog-ng configuration
  $script_name status               displays current scribe status    
  $script_name reload               reload syslog-ng configuration file
  $script_name restart / start      restarts (or starts if not running) syslog-ng
  $script_name debug                creates debug file
  $script_name develop              switch to development branch version
  $script_name stable               switch to stable/production branch version
  $script_name help                 displays this help
EOF
    printf "${CLRct}\n"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jan-04] ##
##----------------------------------------##
Utils_Menu()
{
    printf "$magenta        %s Utilities ${CLRct}\n\n" "$script_name"
    printf "    ${GRNct}bu${CLRct}. Backup configuration files\n"
    printf "    ${GRNct}rt${CLRct}. Restore configuration files\n\n"
    printf "     ${GRNct}d${CLRct}. Generate debug file\n"
    printf "    ${GRNct}rd${CLRct}. Re-detect syslog.log location\n"
    printf "    ${GRNct}ck${CLRct}. Check on-disk %s config\n" "$sng"
    if SyslogNg_Running
    then
        printf "    ${GRNct}lc${CLRct}. Show loaded %s config\n" "$sng"
    fi
    printf "    ${GRNct}sd${CLRct}. Run %s debugging mode\n" "$sng"
    printf "    ${GRNct}ld${CLRct}. Show %s debug info\n\n" "$lr"
    printf "    ${GRNct}ui${CLRct}. "
    if "$uiScribeInstalled"
    then printf "Run"
    else printf "Install"
    fi
    printf " %s\n" "$uiscribeName"
    printf "     ${GRNct}e${CLRct}. Exit to Main Menu\n"
}

##----------------------------------------##
## Modified by Martinski W. [2026-Jan-11] ##
##----------------------------------------##
Main_Menu()
{
    if SyslogNg_Running
    then
        resPrefix="Res"
        insPrefix="Rei"
    else
        resPrefix="S"
        if [ ! -f "$syslogNg_WaitnSEM_FPath" ]
        then insPrefix="I"
        else insPrefix="Rei"
        fi
    fi
    andLRcron="& $lr cron"

    if "$scribeInstalled"
    then
        if ! SyslogNg_Running && [ -f "$syslogNg_WaitnSEM_FPath" ]
        then
            _ShowSysLogNg_WaitStart_Msge_
        fi
        printf "     ${GRNct}s${CLRct}. Show %s status\n" "$script_name"
        if SyslogNg_Running
        then
            printf "    ${GRNct}rl${CLRct}. Reload %s.conf\n" "$sng"
            printf "    ${GRNct}lr${CLRct}. Run logrotate now\n"
        fi
        if SyslogNg_Running || [ ! -f "$syslogNg_WaitnSEM_FPath" ]
        then
            printf "    ${GRNct}rs${CLRct}. %s %s " "${resPrefix}tart" "$sng"
            SyslogNg_Running && echo || printf "${andLRcron}\n"
        fi
        if SyslogNg_Running
        then
            printf "    ${GRNct}st${CLRct}. Stop %s ${andLRcron}\n" "$sng"
            printf "    ${GRNct}ct${CLRct}. Set $lr cron job run frequency\n\n"
            printf "     ${GRNct}u${CLRct}. Check for script updates\n"
            printf "    ${GRNct}uf${CLRct}. Force update %s with latest version\n" "$script_name"
            printf "    ${GRNct}ft${CLRct}. Update filters\n"
        fi
        if [ -f "$syslogNg_WaitnSEM_FPath" ]
        then
            echo
        else
            printf "    ${GRNct}su${CLRct}. %s utilities\n\n" "$script_name"
        fi
    fi
    printf "     ${GRNct}e${CLRct}. Exit %s\n" "$script_name"
    printf "    ${GRNct}is${CLRct}. %s %s\n" "${insPrefix}nstall" "$script_name" 
    printf "    ${GRNct}zs${CLRct}. Remove %s\n" "$script_name"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-05] ##
##----------------------------------------##
Scribe_Menu()
{
    while true
    do
        pause=true
        not_recog=false
        run_scribe=false
        ScriptLogo
        printf "$menuSepStr"
        case "$menu_type" in
            utils)
                Utils_Menu
                ;;
            *)
                Main_Menu
                ;;
        esac
        printf "\n$menuSepStr"
        printf "$magenta Please select an option: $std"
        read -r choice

        if "$scribeInstalled" || \
           [ "$choice" = "e" ] || \
           [ "$choice" = "is" ] || \
           [ "$choice" = "zs" ]
        then
            case "$choice" in
                s)
                    Menu_Status
                    ;;
                rl)
                    if SyslogNg_Running
                    then
                        Reload_SysLogNg_Config
                    else
                        not_recog=true
                    fi
                    ;;
                lr)
                    if _AcquireFLock_ nonblock
                    then
                        _DoRotateLogFiles_
                        _ReleaseFLock_
                    else
                        printf "\n${red} Unable to acquire lock to run logrotate.${std}\n"
                        printf "\n${red} The program may be currently running.${std}\n\n"
                    fi
                    ;;
                rs)
                    Menu_Restart
                    Menu_Status
                    ;;
                st)
                    if SyslogNg_Running
                    then
                        Menu_Stop
                    else
                        not_recog=true
                    fi
                    ;;
                ct)
                    if SyslogNg_Running
                    then
                        menu_LogRotate_CronJob_Time
                        [ $? -ne 0 ] && pause=false
                    else
                        not_recog=true
                    fi
                    ;;
                u)
                    Update_Version
                    ;;
                uf)
                    Update_Version force
                    ;;
                ft)
                    if SyslogNg_Running
                    then
                        Menu_Filters
                    else
                        not_recog=true
                    fi
                    ;;
                su)
                    menu_type="utils"
                    pause=false
                    ;;
                bu)
                    menu_backup
                    ;;
                rt)
                    menu_restore
                    ;;
                d)
                    Gather_Debug
                    printf "\n$white Would you like to review the debug data (opens in less)? [y|n] $std"
                    if Yes_Or_No; then pause=false; less "$script_debug"; fi
                    ;;
                ck)
                    SysLogNg_ShowConfig
                    pause=false
                    ;;
                rd)
                    Create_Config
                    ;;
                lc)
                    if SyslogNg_Running
                    then
                        Show_SysLogNg_LoadedConfig
                        pause=false
                    else
                        not_recog=true
                    fi
                    ;;
                sd)
                    menu_forgrnd
                    ;;
                ld)
                    delfr "$lr_temp"
                    if _AcquireFLock_
                    then
                        _DoRotateLogFiles_ DEBUG TEMP
                        _ReleaseFLock_
                        printf "\n\n" ; more "$lr_temp"
                        echo ; PressEnterTo "continue..."
                        pause=false
                    else
                        printf "\n${red} Unable to acquire lock to run logrotate.${std}\n"
                        printf "\n${red} The program may be currently running.${std}\n\n"
                    fi
                    ;;
                ui)
                    if "$uiScribeInstalled"
                    then
                        $uiscribePath
                        pause=false
                    else
                        Install_uiScribe
                    fi
                    ;;
                e)
                    if [ "$menu_type" = "main" ]
                    then
                        printf "\n$white Thanks for using scribe! $std\n\n\n"
                        exit 0
                    else
                        menu_type="main"
                        pause=false
                    fi
                    ;;
                is)
                    do_inst=true
                    reinst=false
                    if "$scribeInstalled"
                    then
                        reinst=true
                        Menu_Uninstall
                    fi
                    if "$do_inst"
                    then
                        PreInstall_Check
                        Get_ZIP_File
                        Menu_Install
                        sh "$script_loc" status nologo
                        run_scribe=true
                    fi
                    ;;
                zs)
                    reinst=false
                    Menu_Uninstall
                    ;;
                *)
                    not_recog=true
                    ;;
            esac
        else
            not_recog=true
        fi
        if "$not_recog"
        then
            [ -n "$choice" ] && \
            printf "\n${red} INVALID input [$choice]${std}"
            printf "\n${red} Please choose a valid option.${std}\n\n"
        fi
        if "$pause"
        then PressEnterTo "continue..."
        fi
        if "$run_scribe"
        then sh "$script_loc" ; exit 0
        fi
    done
}

##############
#### MAIN ####
##############

SetUpRepoBranchVars

## Increase FIFO queue size if 1GB RAM or more ##
if _HasRouterMoreThan512MBtotalRAM_
then sysLogFiFoSizeMIN=2048
fi

if ! SyslogD_Running && ! SyslogNg_Running && \
   ! "$usbUnmountCaller" && [ "$action" != "SysLoggerCheck" ]
then
    printf "\n\n ${red}*WARNING*${white}: No system logger was running!!${std}\n"
    printf "Starting system loggers (klogd and syslogd)..."
    Start_SyslogD
fi

if [ "$action" != "help" ] && \
   [ "$action" != "about" ] && \
   [ "$action" != "install" ]
then
    # Read or create config file #
    Read_Config
fi

if [ "$action" = "menu" ]
then
    menu_type="main"
    Scribe_Menu
elif ! echo "$action" | grep -qE '^(LogRotate|SysLog)'
then
    ScriptLogo
fi

##----------------------------------------##
## Modified by Martinski W. [2025-Dec-05] ##
##----------------------------------------##
cliParamCheck=true
case "$action" in
    about)
        Menu_About
        cliParamCheck=false
        ;;
    help)
        Menu_Help
        cliParamCheck=false
        ;;
    install)
        if "$scribeInstalled"
        then
            printf "\n$white     *** %s already installed! *** \n\n" "$script_name"
            printf " Please use menu command 'is' to reinstall. ${std}\n\n"
            exit 1
        fi
        PreInstall_Check
        Get_ZIP_File
        Menu_Install
        sh "$script_loc" status nologo
        exit 0
        ;;
    uninstall | remove)
        reinst=false
        Menu_Uninstall
        ;;
    update)
        Update_Version
        ;;
    forceupdate)
        Update_Version force
        ;;
    develop)
        script_branch="develop"
        SetUpRepoBranchVars
        Update_Version force
        ;;
    stable)
        script_branch="master"
        SetUpRepoBranchVars
        Update_Version force
        ;;

    #Show total combined config#
    show-config | config)
        if "$scribeInstalled"
        then
            if SysLogNg_ShowConfig
            then SysLogNg_Config_SyntaxCheck
            fi
        fi
        ;;

    #Verify syslog-ng is running and logrotate Cron Job exists#
    status)
        if "$scribeInstalled"
        then Menu_Status
        fi
        ;;

    reload)
        if SyslogNg_Running
        then Reload_SysLogNg_Config
        fi
        ;;

    #Restart (or start if not running) syslog-ng#
    restart | start)
        if "$scribeInstalled"
        then
            Menu_Restart
            Menu_Status
            cliParamCheck=false
        fi
        ;;

    #Stop syslog-ng & logrotate Cron Job#
    stop)
        if SyslogNg_Running || "$usbUnmountCaller"
        then
            Menu_Stop
            cliParamCheck=false
        fi
        ;;

    # Calling logrotate via a Cron Job ##
    LogRotate)
        if _AcquireFLock_ nonblock
        then
            _DoRotateLogFiles_ CRON
            _ReleaseFLock_
        fi
        exit 0
        ;;

    LogRotateDebug)
        if _AcquireFLock_
        then
            delfr "$lr_temp"
            _DoRotateLogFiles_ DEBUG TEMP
            _ReleaseFLock_
            echo ; more "$lr_temp" ; echo
        else
            printf "\n${red} Unable to acquire lock to run logrotate.${std}\n"
            printf "\n${red} The program may be currently running.${std}\n\n"
        fi
        exit 0
        ;;

    #Generate Debug tarball#
    debug)
        if "$scribeInstalled"
        then Gather_Debug
        fi
        ;;

    #Update syslog-ng and logrotate filters - only used in update process#
    filters)
        if SyslogNg_Running
        then Menu_Filters
        fi
        ;;

    SysLoggerCheck)
        _Launch_SysLoggerCheck_BGScript_
        exit 0
        ;;

    SysLogNgStartDelay)
        _Launch_SysLogNgStartDelay_BGScript_
        exit 0
        ;;

    #Kill syslogd & klogd#
    service_event)
        if ! SyslogNg_Running || [ -z "$2" ] || \
           [ "$2" = "stop" ] || [ "$3" = "ntpd" ] || \
           echo "$3" | grep -qE "^$uiscribeName"
        then exit 0
        fi
        #################################################################
        # load kill_logger() function to reset system path links/hacks
        # keep shellcheck from barfing on sourcing $rcfunc_loc
        # shellcheck disable=SC1091
        # shellcheck source=/opt/etc/init.d/rc.func.syslog-ng
        #################################################################
        currTimeSecs="$(date +'%s')"
        lastTimeSecs="$(_ServiceEventTime_ check)"
        thisTimeDiff="$(echo "$currTimeSecs $lastTimeSecs" | awk -F ' ' '{printf("%s", $1 - $2);}')"
        
        #Only once every 20 minutes at most#
        if [ "$thisTimeDiff" -ge 1200 ]
        then
            _ServiceEventTime_ update "$currTimeSecs"
            . "$rcfunc_loc"
            kill_logger false
            SysLogNg_Config_Sync
            _ServiceEventTime_ update "$(date +'%s')"
        else
            exit 1
        fi
        ;;
    *)
        printf "\n${red} Parameter [$action] is NOT recognized.${std}\n\n"
        printf " For a brief description of available commands, run: ${green}$script_name help${std}\n\n"
        exit 1
        ;;
esac

if ! "$scribeInstalled" && "$cliParamCheck"
then
    printf "\n${yellow} %s ${white}is NOT installed, command \"%s\" not valid!${std}\n\n" "$script_name" "$action"
elif ! SyslogNg_Running && "$cliParamCheck"
then
    printf "\n${yellow} %s ${white}is NOT running, command \"%s\" not valid!${std}\n\n" "$sng" "$action"
else
    echo
fi

#EOF#
