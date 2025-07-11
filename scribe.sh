#!/bin/sh -
#
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
# install command:
#   curl --retry 3 "https://raw.githubusercontent.com/AMTM-OSR/scribe/master/scribe.h" -o "/jffs/scripts/scribe" && chmod 0755 /jffs/scripts/scribe && /jffs/scripts/scribe install
#
# shellcheck disable=SC1090
# shellcheck disable=SC2009
# SC2009 = Consider uing pgrep ~ Note that pgrep doesn't exist in asuswrt (exists in Entware procps-ng)
# shellcheck disable=SC2059
# SC2059 = Don't use variables in the printf format string. Use printf "..%s.." "$foo" ~ I (try to) only embed the ansi color escapes in printf strings
# shellcheck disable=SC2034
# shellcheck disable=SC3043
# shellcheck disable=SC3045
##################################################################
# Last Modified: 2025-Jun-23
#-----------------------------------------------------------------

# ensure firmware binaries are used, not Entware
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:$PATH"

# set TMP if not set #
[ -z "$TMP" ] && export TMP=/opt/tmp

# parse parameters
action="X"
got_zip=false
banner=true
[ "${SCRIBE_LOGO:=xFALSEx}" = "nologo" ] && banner=false

while { [ $# -gt 0 ] && [ -n "$1" ] ; }
do
    case "$1" in
        gotzip)
            got_zip=true
            shift
            ;;
        nologo)
            banner=false
            shift
            ;;
        service_event)
            banner=false
            action="$1"
            break
            ;;
        *)
            action="$1"
            shift
            ;;
    esac
done
[ "$action" = "X" ] && action="menu"

# scribe constants #
readonly script_name="scribe"
scribe_branch="master"
readonly script_branch="$scribe_branch"
readonly scribe_ver="v3.2.2"
# version number for amtm compatibility, but keep vX.Y_Z otherwise because I'm stubborn #
script_ver="$( echo "$scribe_ver" | sed 's/\./_/2' )"
readonly script_ver
readonly script_long="$scribe_ver ($script_branch)"
readonly script_longer="$scribe_ver (Branch: $script_branch)"
readonly script_author="AMTM-OSR"
readonly raw_git="https://raw.githubusercontent.com"
readonly script_repo_file="$raw_git/$script_author/$script_name/$script_branch/${script_name}.sh"
readonly script_repo_ZIP="https://github.com/$script_author/$script_name/archive/${script_branch}.zip"
readonly unzip_dir="$TMP/${script_name}-$script_branch"
readonly script_zip_file="$TMP/${script_name}_TEMP.zip"
readonly script_tmp_file="$TMP/${script_name}_TEMP.tmp"
readonly script_d="/jffs/scripts"
readonly script_loc="$script_d/$script_name"
readonly conf_d="/jffs/addons/${script_name}.d"
readonly script_conf="$conf_d/config"
readonly optmsg="/opt/var/log/messages"
readonly jffslog="/jffs/syslog.log"
readonly tmplog="/tmp/syslog.log"
export script_conf
export optmsg
export jffslog
export tmplog

##----------------------------------------##
## Modified by Martinski W. [2024-Aug-25] ##
##----------------------------------------##
# router details
readonly merlin="ASUSWRT-Merlin"
readonly fwreqd="3004.380.68"
fwname="$( uname -o )"
readonly fwname
fwvers="$(nvram get firmver | sed 's/\.//g').$( nvram get buildno )"
readonly fwvers
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
readonly sngctl_loc="$sng_loc-ctl"
readonly lr_loc="/opt/sbin/$lr"
readonly sng_conf="/opt/etc/$sng.conf"
readonly debug_sep="=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*="
readonly script_debug_name="${script_name}_debug.log"
readonly script_debug="$TMP/$script_debug_name"
readonly sngconf_merged="$TMP/$sng-complete.conf"
readonly sngconf_error="$TMP/$sng-error.conf"
readonly lr_conf="/opt/etc/$lr.conf"
readonly lr_daily="/opt/tmp/logrotate.daily"
readonly lr_temp="/opt/tmp/logrotate.temp"
readonly sngd_d="/opt/etc/$sng.d"
readonly lrd_d="/opt/etc/$lr.d"
readonly etc_d="/opt/etc/*.d"
readonly sng_share="/opt/share/$sng"
readonly lr_share="/opt/share/$lr"
readonly share_ex="/opt/share/*/examples"
readonly script_bakname="$TMP/${script_name}-backup.tar.gz"
readonly fire_start="$script_d/firewall-start"
readonly srvcEvent="$script_d/service-event"
readonly postMount="$script_d/post-mount"
readonly unMount="$script_d/unmount"
readonly skynet="$script_d/firewall"
readonly sky_req="6.9.2"
readonly divers="/opt/bin/diversion"
readonly div_req="4.1"

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-09] ##
##----------------------------------------##
# uiScribe constants #
readonly uiscribeName="uiScribe"
readonly uiscribeAuthor="AMTM-OSR"
readonly uiscribeBranch="master"
readonly uiscribeRepo="$raw_git/$uiscribeAuthor/$uiscribeName/$uiscribeBranch/${uiscribeName}.sh"
readonly uiscribePath="$script_d/$uiscribeName"

# color constants
readonly red="\033[1;31m"
readonly green="\033[1;32m"
readonly yellow="\033[1;33m"
readonly blue="\033[1;34m"
readonly magenta="\033[1;35m"
readonly cyan="\033[1;36m"
readonly white="\033[1;37m"
readonly std="\033[0m"

readonly header="=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=${std}\n\n"

# check if scribe is already installed by looking for link in /opt/bin
[ -e "/opt/bin/$script_name" ] && is_inst=true || is_inst=false

# check if uiScribe is installed #
[ -e "$uiscribePath" ] && uiscribeInstalled=true || uiscribeInstalled=false

# check if Skynet is installed
if [ -e "$fire_start" ] && grep -q "skynetloc" "$fire_start"
then
    skynet_inst=true
else
    skynet_inst=false
fi

#### functions ####

present(){ printf "$green present. $std\n"; }

updated(){ printf "$yellow updated. $std\n"; }

finished(){ printf "$green done. $std\n"; }

not_installed(){ printf "\n$blue %s$red NOT$white installed! $std\n" "$1"; }

enter_to(){ printf "$white Press <Enter> key to %s: $std" "$1"; read -rs inputKey; echo; }

ver_num(){ echo "$1" | sed 's/v//; s/_/./' | awk -F. '{ printf("%d%03d%02d\n", $1, $2, $3); }'; }

md5_file(){ md5sum "$1" | awk '{ printf( $1 ); }'; } # get md5sum of file

strip_path(){ basename "$1"; }

dlt(){ rm -rf "$1"; }

same_same(){ if [ "$( md5_file "$1" )" = "$( md5_file "$2" )" ]; then true; else false; fi; }

date_stamp(){ [ -e "$1" ] && mv "$1" "$1-$( date -Iseconds | cut -c 1-19 )"; }

sng_rng(){ if [ -n "$( pidof $sng )" ]; then true; else false; fi; }

sld_rng(){ if [ -n "$( pidof $sld )" ]; then true; else false; fi; }

# NB: ensure system log is backed up before doing this!
clear_loglocs()
{
    dlt $tmplog
    dlt $tmplog-1
    dlt $jffslog
    dlt $jffslog-1
}

start_syslogd()
{
    service start_logger
    count=30
    while ! sld_rng && [ "$count" -gt 0 ]
    do
        sleep 1 # give syslogd time to start up
        count="$(( count - 1 ))"
    done
    if [ "$count" -eq 0 ]
    then printf "\n$red UNABLE TO START SYSLOGD!  ABORTING!\n$std"; exit 1
    fi
}

##-------------------------------------##
## Added by Martinski W. [2025-Jun-22] ##
##-------------------------------------##
_ServiceEventTime_()
{
    [ ! -d "$conf_d" ] && mkdir "$conf_d"
    [ ! -e "$script_conf" ] && touch "$script_conf"
    if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1; fi
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

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-22] ##
##----------------------------------------##
CFG_Write_Syslog_Path()
{
    [ ! -d "$conf_d" ] && mkdir "$conf_d"
    [ ! -e "$script_conf" ] && touch "$script_conf"
    if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1; fi

    if ! grep -q "^SYSLOG_LOC=" "$script_conf"
    then
        echo "SYSLOG_LOC=$1" >> "$script_conf"
    else
        sed -i "s~SYSLOG_LOC=.*~SYSLOG_LOC=$1~" "$script_conf"
    fi
}

# random routers point syslogd at /jffs instead of /tmp
# figure out where default syslog.log location is
# function assumes syslogd is running!
where_syslogd()
{
    sld_ps="$( ps ww | grep "syslogd" )"
    syslog_loc="$( awk -v psww="$sld_ps" 'BEGIN { n=split (psww, psary); for (i = 1; i <= n; i++) if ( psary[i] ~ "-O" ) break; print psary[i+1] }' )"
    CFG_Write_Syslog_Path "$syslog_loc"
}

create_conf()
{
    printf "\n$white Detecting default syslog location "
    if sng_rng
    then
        slg_was_rng=true
        printf "\n Briefly shutting down %s" "$sng"
        killall $sng 2>/dev/null
        count=10
        while sng_rng && [ "$count" -gt 0 ]
        do
            sleep 1
            count="$(( count - 1 ))"
        done
        clear_loglocs
    else
        slg_was_rng=false
    fi

    if ! sld_rng; then start_syslogd; fi
    where_syslogd
    if "$slg_was_rng"
    then
        # if syslog-ng was running, kill syslogd and restart
        $S01sng_init start
    else
        # prepend /opt/var/messages to syslog & create link
        cat "$syslog_loc" >> "$optmsg" && mv -f "$optmsg" "$syslog_loc"
        ln -s "$syslog_loc" "$optmsg"
    fi
    # assume uiScribe is still running if it was before stopping syslog-ng #
}

read_conf()
{
    if [ -f "$script_conf" ]
    then # assumes if $script_conf exists, it is correctly formatted
        syslog_loc="$(grep "^SYSLOG_LOC=" "$script_conf" | cut -f2 -d'=')"
    else # scribe started with no config file
        create_conf
    fi
    export syslog_loc
}

update_file()
{
    [ -n "$3" ] && [ "$3" = "backup" ] && date_stamp "$2"
    cp -pf "$1" "$2"
}

# Check Yes or No #
yes_no()
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

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-09] ##
##----------------------------------------##
ScriptLogo()
{
    if ! $banner; then return; fi
    clear 
    printf "$white                            _\n"
    printf "                         _ ( )            \n"
    printf "       ___    ___  _ __ (_)| |_      __   \n"
    printf "     /',__) /'___)( '__)| || '_\`\\  /'__\`\\ \n"
    printf "     \\__, \\( (___ | |   | || |_) )(  ___/ \n"
    printf "     (____/\`\\____)(_)   (_)(_,__/'\`\\____) \n"
    printf "     %s and %s installation $std\n" "$sng" "$lr"
    printf "         $green %-28s$std\n" "$script_longer"
    printf "     ${blue}https://github.com/AMTM-OSR/uiScribe${std}\n"
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
        dlt "$unzip_dir"
        dlt "$script_zip_file"
        printf "\n$white fetching %s from GitHub %s branch ...$std\n" "$script_name" "$script_branch"
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

Hup_uiScribe()
{
    if "$uiscribeInstalled"
    then
        printf "$white Restarting uiScribe ..."
        $uiscribePath startup
    fi
}

rld_sngconf()
{
    printf "$white reloading %s ... $cyan" "$( strip_path $sng_conf )"
    $sngctl_loc reload
    printf "\n$std"
    Hup_uiScribe
}

copy_rcfunc()
{
    printf "$white copying %s to %s ...$std" "$rcfunc_sng" "$init_d"
    cp -pf "$unzip_dir/init.d/$rcfunc_sng" "$init_d/"
    chmod 644 "$rcfunc_loc"
    finished
}

check_sng()
{
    printf "\n$white %34s" "checking $sng daemon ..."
    if sng_rng
    then
        printf "$green alive. $std\n"
    else
        printf "$red dead. $std\n"
        printf "$white %34s" "the system logger (syslogd) ..."
        if sld_rng
        then
            printf "$green is running. $std\n\n"
            printf "$yellow    Type$red %s restart$yellow at shell prompt or select$red rs$yellow\n" "$script_name"
            printf "    from %s main menu to start %s.\n" "$script_name" "$sng"
        else
            printf "$red is not running! $std\n\n"
            printf "$white    Type$red %s -Fevd$white at shell prompt or select$red sd$white\n" "$sng"
            printf "    from %s utilities menu ($red%s$white) to view %s\n" "$script_name" "su" "$sng" 
            printf "    debugging data.\n"
        fi
    fi
}

sed_sng()
{
    printf "$white %34s" "checking $( strip_path $S01sng_init ) ..."
    if ! grep -q $rcfunc_sng $S01sng_init
    then
        sed -i "\~/opt/etc/init.d/rc.func~i . $rcfunc_loc # added by $script_name\n" $S01sng_init
        updated
    else
        present
    fi
}

rd_warn(){
    printf "$yellow Use utility menu (su) option 'rd' to re-detect! $std\n"
}

syslogd_check()
{
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
    checksys_loc="$(grep "^SYSLOG_LOC=" "$script_conf" | cut -f2 -d'=')"
    if [ ! -f "$script_conf" ]
    then # scribe started with no config file
        printf "$red NO CONFIG FILE!\n"
        rd_warn
    # assumes if $script_conf exists, it is correctly formatted
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
        if grep -q "$script_name kill-logger" "$srvcEvent" ; then sed -i "/$script_name kill-logger/d" "$srvcEvent" ; fi
        if grep -q "$script_name kill_logger" "$srvcEvent" ; then sed -i "/$script_name kill_logger/d" "$srvcEvent" ; fi
        if ! grep -q "$script_name service_event" "$srvcEvent"
        then
            echo "$script_loc service_event \"\$@\" & # added by $script_name" >> "$srvcEvent"
            updated
        else
            present
        fi
    else
        {
            echo "#!/bin/sh -" ; echo
            echo "$script_loc service_event \"\$@\" & # added by $script_name"
        } > "$srvcEvent"
        printf "$green created. $std\n"
    fi
    [ ! -x "$srvcEvent" ] && chmod 0755 "$srvcEvent"
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-16] ##
##----------------------------------------##
lr_post()
{
    printf "$white %34s" "checking $( strip_path "$postMount" ) ..."
    if [ ! -f "$postMount" ]
    then
        printf "$red MISSING! \n"
        printf " Entware is not properly set up!\n"
        printf " Correct Entware installation before continuing! $std\n\n"
        exit 1
    fi
    if ! grep -q "$lr" "$postMount"
    then
        echo "cru a $lr \"5 0 * * * $lr_loc $lr_conf >> $lr_daily 2>&1\" # added by $script_name" >> "$postMount"
        updated
    else
        present
    fi
    [ -f /var/lib/logrotate.status ] && chmod 600 /var/lib/logrotate.status
}

sed_unMount()
{
    printf "$white %34s" "checking $( strip_path "$unMount" ) ..."
    if [ -f "$unMount" ]
    then
        [ "$( grep -c "#!/bin/sh" "$unMount" )" -ne 1 ] && sed -i "1s~^~#!/bin/sh -\n\n~" "$unMount"
        if ! grep -q "$script_name stop" "$unMount"
        then
            echo "[ \"\$(find \$1/entware*/bin/$script_name 2> /dev/null)\" ] && $script_name stop nologo # added by $script_name" >> "$unMount"
            updated
        else
            present
        fi
    else
        {
            echo "#!/bin/sh" ; echo
            echo "[ \"\$(find \$1/entware*/bin/$script_name 2> /dev/null)\" ] && $script_name stop nologo # added by $script_name"
        } > "$unMount"
        printf "$green created. $std\n"
    fi
    [ ! -x "$unMount" ] && chmod 0755 "$unMount"
}

lr_cron()
{
    printf "$white %34s" "checking $lr cron job ..."
    if ! cru l | grep -q $lr
    then
        cru a $lr "5 0 * * * $lr_loc $lr_conf >> $lr_daily 2>&1"
        updated
    else
        present
    fi
}

dir_links()
{
    printf "$white %34s" "checking directory links ..."
    if [ ! -L "$syslog_loc" ] || [ ! -d "/opt/var/run/syslog-ng" ]
    then
        #################################################################
        # load kill_logger() function to reset system path links/hacks
        # keep shellcheck from barfing on sourcing $rcfunc_loc
        # shellcheck disable=SC1090
        # shellcheck source=/opt/etc/init.d/rc.func.syslog-ng
        #################################################################
        . $rcfunc_loc
        kill_logger
        updated
    else
        present
    fi
}

##----------------------------------------##
## Modified by Martinski W. [2024-Aug-25] ##
##----------------------------------------##
sync_conf()
{
    printf "$white %34s" "$( strip_path "$sng_conf" ) version check ..."
    sng_conf_vtag1="@version:"
    sng_conf_vtag2="${sng_conf_vtag1}[[:blank:]]*"
    sng_version_str="$( $sng --version | grep -m1 "$sng" | grep -oE '[0-9]{1,2}([_.][0-9]{1,2})' )"
    sng_conf_verstr="$( grep -Em1 "$sng_conf_vtag2" "$sng_conf" | grep -oE '[0-9]{1,2}([_.][0-9]{1,2})' )"

    if [ "$sng_version_str" != "$sng_conf_verstr" ] || grep -q 'stats_freq(' "$sng_conf"
    then
        printf "$red out of sync! (%s) $std\n" "$sng_conf_verstr"
        printf "$cyan *** Updating %s and restarting %s *** $std\n" "$( strip_path "$sng_conf" )" "$sng"
        $S01sng_init stop
        old_doc="doc\/syslog-ng-open"
        new_doc="list\/syslog-ng-open-source-edition"
        sed -i "s/$old_doc.*/$new_doc/" "$sng_conf"
        stats_freq="$( grep -m1 'stats_freq(' $sng_conf | cut -d ';' -f 1 | grep -oE '[0-9]*' )"
        [ -n "$stats_freq" ] && sed -i "s/stats_freq($stats_freq)/stats(freq($stats_freq))/g" "$sng_conf"
        if [ -n "$sng_version_str" ] && [ -n "$sng_conf_verstr" ]
        then
            sed -i "s/^${sng_conf_vtag2}${sng_conf_verstr}.*/$sng_conf_vtag1 $sng_version_str/" "$sng_conf"
        fi
        $S01sng_init start
        Hup_uiScribe
        printf "$white %34s" "$( strip_path "$sng_conf" ) version ..."
        printf "$yellow updated! (%s) $std\n" "$sng_version_str"
        logger -t "$script_name" "$( strip_path "$sng_conf" ) version number updated ($sng_version_str)!"
    else
        printf "$green in sync. (%s) $std\n" "$sng_version_str"
    fi
}

sng_syntax()
{
    printf "$white %34s" "$( strip_path "$sng_conf" ) syntax check ..."
    if $sng_loc -s >> /dev/null 2>&1; then printf "$green okay! $std\n"; else printf "$red FAILED! $std\n\n"; fi
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-09] ##
##----------------------------------------##
get_vers()
{
    # only get scribe from github once #
    script_md5="$( md5_file "$script_loc")"
    dlt "$script_tmp_file"
    curl -LSs --retry 4 --retry-delay 5 --retry-connrefused "$script_repo_file" -o "$script_tmp_file"
    [ ! -e "$script_tmp_file" ] && \
    printf "\n\n$white %s GitHub repository is unavailable! -- $red ABORTING! $std\n\n" "$script_name" && exit 1
    github_ver="$( grep -m1 "scribe_ver=" "$script_tmp_file" | grep -oE 'v?[0-9]{1,2}([.][0-9]{1,2})([_.][0-9]{1,2})' | sed 's/\./_/2' )"
    github_branch="$( grep -m1 "scribe_branch=" "$script_tmp_file" | awk -F\" '{ printf ( $2 ); }'; )" 
    github_long="$github_ver ($github_branch)"
    github_md5="$( md5_file "$script_tmp_file")"
    new_vers="none"
    if [ "$( ver_num "$github_ver" )" -lt "$( ver_num "$scribe_ver" )" ]; then new_vers="older"
    elif [ "$( ver_num "$github_ver" )" -gt "$( ver_num "$scribe_ver" )" ]; then new_vers="major"
    elif [ "$script_md5" != "$github_md5" ]; then new_vers="minor"
    fi
    dlt "$script_tmp_file"
}

prt_vers()
{
    printf "\n$white %34s$green %s \n" "$script_name installed version:" "$script_long"
    printf "$white %34s$green %s $std\n" "$script_name GitHub version:" "$github_long"
    case "$new_vers" in
        older)
            printf "$red      Local %s version greater than GitHub version!" "$script_name"
            ;;
        major)
            printf "$yellow %45s" "New $script_name version available"
            ;;
        minor)
            printf "$blue %45s" "Minor $script_name update available"
            ;;
        none)
            printf "$green %40s" "$script_name is up to date!"
            ;;
    esac
    printf "$std\n\n"
}

# install default file in /usr/etc/$1.d #
setup_ddir()
{
    [ "$1" = "$sng" ] && d_dir="$sngd_d"
    [ "$1" = "$lr"  ] && d_dir="$lrd_d"
    
    for dfile in "$unzip_dir/$1.d"/*
    do
        dfbase="$( strip_path "$dfile" )"
        ddfile="$d_dir/$dfbase"
        { [ ! -e "$ddfile" ] || [ "$2" = "ALL" ]; } && cp -p "$dfile" "$ddfile"
    done
    chmod 600 "$d_dir"/*
}

# install example files in /usr/share/$1/examples
setup_exmpls()
{
    [ "$1" = "$sng" ] && share="$sng_share" && conf="$sng_conf"
    [ "$1" = "$lr"  ] && share="$lr_share" && conf="$lr_conf"
    opkg="$1.conf-opkg"
    conf_opkg="$conf-opkg"

    [ "$2" != "ALL" ] && printf "\n$white"
    [ ! -d "$share" ] && mkdir "$share"
    [ ! -d "$share/examples" ] && mkdir "$share/examples"

    for exmpl in "$unzip_dir/$1.share"/*
    do
        shrfile="$share/examples/$( strip_path "$exmpl" )"
        if [ ! -e "$shrfile" ] || [ "$2" = "ALL" ]
        then
            update_file "$exmpl" "$shrfile"
        elif ! same_same "$exmpl" "$shrfile"
        then
            printf " updating %s\n" "$shrfile"
            update_file "$exmpl" "$shrfile"
        fi
    done

    if [ -e "$conf_opkg" ]
    then
        update_file "$conf_opkg" "$share/examples/$opkg" "backup"
        dlt "$conf_opkg"
    elif [ ! -e "$share/examples/$opkg" ]
    then
        cp -pf "$conf" "$share/examples/$opkg"
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

force_install()
{
    printf "\n$blue %s$white already installed!\n" "$1"
    [ "$1" != "$script_name" ] && printf "$yellow Forcing installation$red WILL OVERWRITE$yellow any modified configuration files!\n"
    printf "$white Do you want to force re-installation of %s [y|n]? $std" "$1"
    yes_no
    return $?
}

show_config()
{
    if [ -e "$sng_loc" ]
    then
        dlt "$sngconf_merged"
        dlt "$sngconf_error"
        if $sng_loc --preprocess-into="$sngconf_merged" 2> "$sngconf_error"
        then
            less "$sngconf_merged"
        else 
            less "$sngconf_error"
        fi
        true
    else
        not_installed "$sng"
        false
    fi
}

show_loaded()
{
    dlt "$sngconf_merged"
    $sngctl_loc config --preprocessed > "$sngconf_merged"
    less "$sngconf_merged"
}

run_logrotate()
{
    dlt "$lr_daily"
    printf "\n$white %34s" "running $lr ..."
    $lr_loc $lr_conf >> $lr_daily 2>&1
    finished
    printf "\n$magenta checking %s log for errors $cyan\n\n" "$lr"
    tail -v "$lr_daily"
}

menu_status()
{
    check_sng
    syslogd_check
    printf "\n$magenta checking system for necessary %s hooks ...\n\n" "$script_name"
    sed_sng
    if sng_rng; then sed_srvcEvent; fi
    lr_post
    sed_unMount
    if sng_rng; then lr_cron; dir_links; fi
    printf "\n$magenta checking %s configuration ...\n\n" "$sng"
    sync_conf
    sng_syntax
    get_vers
    prt_vers
}

sng_ver_chk()
{
    sng_vers="$( $sng --version | grep -m1 "$sng" | grep -oE '[0-9]{1,2}([_.][0-9]{1,2})([_.][0-9]{1,2})?' )"
    if [ "$( ver_num "$sng_vers" )" -lt "$( ver_num "$sng_reqd" )" ]
    then
        printf "\n$red %s version %s or higher required!\n" "$sng" "$sng_reqd"
        printf "Please update your Entware packages and run %s install again.$cyan\n\n" "$script_name"
        /opt/bin/opkg remove "$sng"
        printf "$std\n\n"
        exit 1
    fi
}

setup_sng()
{
    printf "\n$magenta setting up %s ...\n$std" "$sng"
    copy_rcfunc
    sed_sng
    sed_srvcEvent
    sed_unMount
    if [ "$( md5_file "$sng_share/examples/$sng.conf-scribe" )" != "$( md5_file "$sng_conf" )" ]
    then
        printf "$white %34s" "updating $( strip_path $sng_conf ) ..."
        update_file $sng_share/examples/$sng.conf-scribe $sng_conf "backup"
        finished
    fi
    sync_conf
}

setup_lr()
{
    # assumes since entware is required / installed, post-mount exists and is properly executable
    printf "\n$magenta setting up %s ...\n" "$lr"
    lr_post
    lr_cron
}

install()
{
    force=""
    [ "X$2" = "XFORCE" ] && force="--force-reinstall"
    printf "\n$cyan"
    /opt/bin/opkg install $force "$1" 
    [ "$1" = "$sng" ] && sng_ver_chk
    setup_ddir "$1" "ALL"
    setup_exmpls "$1" "ALL"
    [ "$1" = "$sng" ] && setup_sng
    [ "$1" = "$lr"  ] && setup_lr
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-09] ##
##----------------------------------------##
setup_Scribe()
{
    printf "\n$white setting up %s ..." "$script_name"
    cp -fp "$unzip_dir/${script_name}.sh" "$script_loc"
    chmod 0755 "$script_loc"
    [ ! -e "/opt/bin/$script_name" ] && ln -s "$script_loc" /opt/bin

    # install correct firewall or skynet file, these are mutually exclusive #
    if $skynet_inst
    then
        dlt "$sngd_d/firewall"
        dlt "$lrd_d/firewall"
        if [ ! -e "$sngd_d/skynet" ] || [ "$1" = "ALL" ]
        then
            printf "$white installing %s Skynet filter ..." "$sng"
            cp -p "$sng_share/examples/skynet" "$sngd_d" 
        fi
        printf "$blue setting Skynet log file location$white ..."
        skynetlog="$( grep -m1 'file("' $sngd_d/skynet | awk -F\" '{ printf ( $2 ); }'; )"
        sh $skynet settings syslog "$skynetlog" > /dev/null 2>&1
    else
        dlt "$sngd_d/skynet"
        dlt "$lrd_d/skynet"
        if [ ! -e "$sngd_d/firewall" ] || [ "$1" = "ALL" ]
        then
            printf "$white installing %s firewall filter ..." "$sng"
            cp -p "$sng_share/examples/firewall" "$sngd_d"
            printf "$white installing firewall log rotation ..."
            cp -p "$lr_share/examples/firewall" "$lrd_d"
        fi
    fi
    finished
}

##----------------------------------------##
## Modified by Martinski W. [2025-Jun-09] ##
##----------------------------------------##
readonly uiscribeVerRegExp="v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})"
Install_uiScribe()
{
    uiscribeVer="$(curl -fsL --retry 4 --retry-delay 5 "$uiscribeRepo" | grep "SCRIPT_VERSION=" | grep -m1 -oE "$uiscribeVerRegExp")"
    printf "\n$white Would you like to install$cyan %s %s$white, a script by Jack Yaz\n" "$uiscribeName" "$uiscribeVer"
    printf " that modifies the webui$yellow System Log$white page to show the various logs\n"
    printf " generated by %s in individual drop-down windows [y|n]? " "$sng"
    if yes_no
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
    if "$uiscribeInstalled"
    then
        printf "$white uiScribe add-on is detected, uninstalling ...\n\n"
        $uiscribePath uninstall
    fi
}

pre_install()
{
    # check for required components
    okay=true

    # check if Entware & ASUSWRT-Merlin are installed and Merlin version number
    if [ ! -x "/opt/bin/opkg" ] || [ "$fwname" != "$merlin" ] || [ "$( ver_num "$fwvers" )" -lt "$( ver_num "$fwreqd" )" ]
    then
        printf "\n\n$red %s version %s or later with Entware is required! $std\n" "$merlin" "$fwreqd"
        okay=false
    fi

    # check if diversion is installed and version number
    if [ -x "$divers" ]
    then
        printf "\n\n$white Diversion detected, checking version ..."
        div_ver="$( grep -m1 "VERSION" $divers | grep -oE '[0-9]{1,2}([.][0-9]{1,2})' )"
        printf " version %s detected ..." "$div_ver"
        if [ "$( ver_num "$div_ver" )" -lt "$( ver_num "$div_req" )" ]
        then
            printf "$red update required!\n"
            printf " Diversion %s or later is required! $std\n" "$div_req"
            okay=false
        else
            printf "$green okay! $std\n"
        fi
    fi

    # check if Skynet is installed and version number
    if $skynet_inst 
    then
        printf "\n\n$white Skynet detected, checking version ..."
        sky_ver="$( grep -m1 -oE 'v[0-9]{1,2}([.][0-9]{1,2})([.][0-9]{1,2})' "$skynet" )"
        printf " version %s detected ..." "$sky_ver"
        if [ "$( ver_num "$sky_ver" )" -lt "$( ver_num "$sky_req" )" ]
        then
            printf "$red update required!\n"
            printf " Skynet %s or later is required! $std\n" "$sky_req"
            okay=false
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
        if $okay
        then
            printf " Do you want to continue installation of %s [y|n]? $std" "$script_name"
            if ! yes_no
            then
                okay=false
            fi
        fi
    fi

    # exit if requirements not met #
    if ! $okay
    then
        printf "\n\n$magenta exiting %s installation. $std\n\n" "$script_name"
        dlt "$script_loc"
        exit 1
    fi
}

menu_install()
{
        if [ ! -e $sng_loc ]
        then
            install "$sng"
        elif force_install "$sng"
        then
            $S01sng_init stop
            install "$sng" "FORCE"
        fi
        echo
        $S01sng_init start

        if [ ! -e $lr_loc ]
        then
            install "$lr"
        elif force_install "$lr"
        then
            install "$lr" "FORCE"
        fi
        run_logrotate

        if ! $is_inst
        then
            setup_Scribe "ALL"
        elif force_install "$script_name script"
        then
            setup_Scribe "ALL"
        fi

        rld_sngconf
        printf "\n$white %s setup complete!\n\n" "$script_name"
        enter_to "continue"
        if ! "$uiscribeInstalled" ; then Install_uiScribe ; fi
}

menu_restart()
{
    if sng_rng
    then
        printf "\n$yellow Restarting %s... $std\n" "$sng"
        $S01sng_init restart
    else
        printf "\n$white %s$red NOT$white running! $yellow Starting %s ... $std\n" "$sng"
        $S01sng_init start
    fi
    Hup_uiScribe
}

stop_sng()
{
    printf "$white stopping %s ..." "$sng"
    $S01sng_init stop
    # remove any syslog links
    clear_loglocs
    mv "$optmsg" "$syslog_loc"
    ln -s "$syslog_loc" "$optmsg"
    printf "$white starting system klogd and syslogd ..."
    start_syslogd
    if ! $banner; then return; fi
    printf "\n$white %s will be started at next reboot; you\n" "$sng"
    printf " may type '%s restart' at shell prompt, or\n" "$script_name"
    printf " select rs from %s menu to restart %s $std\n\n" "$script_name" "$sng"
}

stop_lr(){ if cru l | grep -q $lr; then cru d $lr; fi; }

menu_stop(){
    stop_sng
    stop_lr
}

uninstall()
{
    printf "\n\n"
    banner=false  # suppress certain messages #
    if [ -e "$sng_loc" ]
    then
        if sng_rng; then stop_sng; fi
        sed -i "/$script_name stop/d" "$unMount"
        sed -i "/$script_name service_event/d" "$srvcEvent"
        dlt "$S01sng_init"
        dlt "$rcfunc_loc"
        printf "\n$cyan"
        /opt/bin/opkg remove "$sng"
        dlt "$sng_conf"
        dlt "$sngd_d"
        dlt "$sng_share"

        if $skynet_inst && ! $reinst
        then
            printf "$white restoring Skynet logging to %s ..." "$syslog_loc"
            sh $skynet settings syslog "$syslog_loc" > /dev/null 2>&1
        fi
    else
        not_installed "$sng"
    fi

    if [ -e "$lr_loc" ]
    then
        stop_lr
        sed -i "/cru a $lr/d" "$postMount"
        printf "\n$cyan"
        /opt/bin/opkg remove "$lr"
        dlt "$lr_conf"
        dlt "$lrd_d"
        dlt "$lr_share"
        dlt "$lr_daily"
    else
        not_installed "$lr"
    fi

    dlt "$script_zip_file"
    dlt "$TMP/${script_name}-$script_branch"
    dlt "/opt/bin/$script_name"
    dlt "$script_loc"
    is_inst=false
    if ! $reinst
    then
        printf "\n$white %s, %s, and %s have been removed from the system.\n" "$sng" "$lr" "$script_name"
        printf " It is recommended to reboot the router at this time.  If you do not\n"
        printf " wish to reboot the router, press ${blue}<Ctrl-C>${std} now to exit.\n\n"
        enter_to "reboot"
        service reboot; exit 0
    fi
}

menu_uninstall()
{
    andre="remove"
    uni="UN"
    if $reinst
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
            if ! $reinst; then Uninstall_uiScribe; fi
            uninstall
            ;;
        *)
            do_inst=false
            printf "\n\n$white *** %sINSTALL ABORTED! ***$std\n\n" "$uni"
            ;;
    esac
}

menu_filters()
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
    if yes_no
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
                if [ -e "$comp_file" ] && ! same_same "$upd_file" "$comp_file"
                then
                    processed=false
                    printf "\n$white Update available for$yellow %s$white.\n" "$upd_file"
                    while ! $processed
                    do
                        printf "    (a)ccept, (r)eject, or (v)iew diff for this file? "
                        read -r dispo
                        case "$dispo" in
                            a)
                                update_file "$comp_file" "$upd_file"
                                printf "\n$green %s updated!$std\n" "$upd_file"
                                processed=true
                                ;;
                            r)
                                printf "\n$magenta %s not updated!$std\n" "$upd_file"
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
        printf "\n$white %s and %s example files updated!$std\n" "$sng" "$lr"
        rld_sngconf
    else
        printf "\n$white %s and %s example files$red not$white updated!$std\n" "$sng" "$lr"
    fi
}

menu_update()
{
    if [ "$new_vers" = "major" ] || [ "$new_vers" = "minor" ]
    then
        [ "$new_vers" = "major" ] && printf "\n$green    New version" || printf "$cyan    Minor update"
        printf "$white available!\n"
        printf "    Do you wish to upgrade? [y|n] $std"
    else
        printf "\n$white    No new version available. (GitHub version"
        [ "$new_vers" = "none" ] && printf " equal to " || printf "$red LESS THAN $white"
        printf "local version)\n"
        printf "    Do you wish to force re-installation of %s script? [y|n] $std" "$script_name"
    fi
    if yes_no
    then
        Get_ZIP_File
        setup_Scribe "NEWER"
        copy_rcfunc
        printf "\n$white %s updated!$std\n" "$script_name"
        sh "$script_loc" filters gotzip nologo
        sh "$script_loc" status nologo
        run_scribe=true
    else
        printf "\n$white        *** %s$red not$white updated! *** $std\n\n" "$script_name"
    fi
}

menu_forgrnd()
{
    restrt=false
    if sng_rng
    then
        warning_sign
        printf " %s is currently running; starting the debugging\n" "$sng"
        printf " mode is usually not necessary if %s is running.\n" "$sng"
        printf " Debugging mode is intended for troubleshooting when\n"
        printf " %s will not start.\n\n" "$sng"
        printf " Are you certain you wish to start debugging mode [y|n]? $std"
        if ! yes_no; then return; fi
        restrt=true
    fi
    printf "\n$yellow NOTE: If there are no errors, debugging mode will\n"
    printf "       continue indefinitely. If this happens, type\n"
    printf "       <Ctrl-C> to halt debugging mode output.\n\n"
    enter_to "start"
    if $restrt; then $S01sng_init stop; printf "\n"; fi
    trap '' 2
    $sng_loc -Fevd
    trap - 2
    if $restrt; then printf "\n"; $S01sng_init start; fi
    printf "\n"
}

gather_debug()
{
    dlt "$script_debug"
    printf "\n$white gathering debugging information ..."
    get_vers

    # everything between { } goes to $script_debug
    {
        printf "%s\n" "$debug_sep"
        printf "### %s Version: %s\n" "$script_name" "$script_long"
        printf "###  Local %s md5: %s\n" "$script_name" "$script_md5"
        printf "### GitHub Version: %s\n" "$github_long"
        printf "### GitHub %s md5: %s\n" "$script_name" "$github_md5"
        printf "### Router: %s (%s)\n" "$model" "$arch"
        printf "### Firmware Version: %s %s\n" "$fwname" "$fwvers"
        printf "\n%s\n### check running log processes:\n" "$debug_sep"
        ps | grep "log"
        printf "\n%s\n### check crontab:\n" "$debug_sep"
        cru l | grep $lr
        printf "\n%s\n### directory check:\n" "$debug_sep"
        ls -ld /tmp/syslog*
        ls -ld /jffs/syslog*
        ls -ld $optmsg
        ls -ld "$script_conf"
        printf "\n%s\n### top output:\n" "$debug_sep"
        top -b -n1 | head
        printf "\n%s\n### *log references in top:\n" "$debug_sep"
        top -b -n1 | grep log
        printf "\n%s\n### init.d directory:\n" "$debug_sep"
        ls -l /opt/etc/init.d
        printf "\n%s\n### contents of S01syslog-ng\n" "$debug_sep"
        cat /opt/etc/init.d/S01syslog-ng
        printf "\n%s\n### /opt/var/log directory:\n" "$debug_sep"
        ls -l /opt/var/log
        printf "\n%s\n### installed packages:\n" "$debug_sep"
        /opt/bin/opkg list-installed
        printf "\n%s\n### %s running configuration:\n" "$debug_sep" "$sng"
    } >> "$script_debug"
    if sng_rng
    then
        $sngctl_loc config --preprocessed >> "$script_debug"
    else
        printf "#### %s not running! ####\n%s\n" "$sng" "$debug_sep"
    fi
    printf "\n%s\n### %s on-disk syntax check:\n" "$debug_sep" "$sng" >> "$script_debug"
    dlt "$sngconf_merged"
    dlt "$sngconf_error"
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
    $lr_loc -d "$lr_conf" >> "$script_debug" 2>&1
    printf "\n%s\n### Skynet log locations:\n" "$debug_sep"
    if $skynet_inst
    then
        skynetloc="$( grep -ow "skynetloc=.* # Skynet" $fire_start 2>/dev/null | grep -vE "^#" | awk '{print $1}' | cut -c 11- )"
        skynetcfg="${skynetloc}/skynet.cfg"
        grep "syslog" "$skynetcfg" >> "$script_debug"
    else
        printf "#### Skynet not installed! ####\n%s\n" "$debug_sep" >> "$script_debug"
    fi
    printf "\n%s\n### end of output ###\n" "$debug_sep" >> "$script_debug"

    printf " redacting username and USB drive names ..."
    redact="$( echo "$USER" | awk  '{ print substr($0, 1, 8); }' )"
    sed -i "s/$redact/redacted/g" "$script_debug"
    mntnum=0
    for usbmnt in /tmp/mnt/*
    do
        usbdrv="$( echo "$usbmnt" | awk -F/ '{ printf( $4 ); }' )"
        # note that if the usb drive name has a comma in it, then sed will fail
        if [ "X$( echo "$usbmnt" | grep ',' )" = "X" ]
        then
            sed -i "s,$usbdrv,usb#$mntnum,g" "$script_debug"
        else
            printf "\n\n    USB drive $cyan%s$white has a comma in the drive name,$red unable to redact!$white\n\n" "$usbdrv"
        fi
        mntnum=$(( mntnum + 1 ))
    done

    printf " taring the output ..."
    tar -zcvf "$script_debug.tar.gz" -C "$TMP" "$script_debug_name" > /dev/null 2>&1
    finished
    printf "\n$std Debug output stored in $cyan%s$std, please review this file\n" "$script_debug"
    printf " to ensure you understand what information is being disclosed.\n\n"
    printf " Tarball of debug output is $cyan%s.tar.gz $std\n" "$script_debug"
}

menu_backup(){
    printf "\n$white Backing up %s and %s Configurations ... \n" "$sng" "$lr"
    date_stamp "$script_bakname"
    tar -zcvf "$script_bakname" "$sng_conf" "$sngd_d" "$lr_conf" "$lrd_d" "$conf_d"
    printf "\n$std Backup data is stored in $cyan%s$std.\n\n" "$script_bakname"
}

menu_restore(){
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
                dlt "$sngd_d"
                dlt "$lrd_d"
                tar -zxvf "$script_bakname" -C /
                chmod 600 "$sngd_d"/*
                chmod 600 "$lrd_d"/*
                printf "\n$std Backup data has been restored from $cyan%s$std.\n" "$script_bakname"
                menu_restart
                menu_status
                ;;
            *)
                printf "\n\n$white *** RESTORE ABORTED! ***$std\n\n"
                ;;
        esac
    fi
}

menu_about()
{
    cat <<EOF
About
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
    printf "$std\n"
}

menu_help()
{
    cat <<EOF
Available commands:
  $script_name about                explains functionality
  $script_name install              installs script
  $script_name remove / uninstall   uninstalls script
  $script_name update               checks for updates
  $script_name [show-]config        checks on-disk syslog-ng configuration
  $script_name status               displays current scribe status    
  $script_name reload               reload syslog-ng configuration file
  $script_name restart / start      restarts (or starts if not running) syslog-ng
  $script_name debug                creates debug file
  $script_name help                 displays this help
EOF
    printf "$std\n"
}

ut_menu()
{
    printf "$magenta           %s Utilities ${std}\n\n" "$script_name"
    printf "     bu.   Backup configuration files\n"
    printf "     rt.   Restore configuration files\n\n"
    printf "     d.    Generate debug file\n"
    printf "     rd.   Re-detect syslog.log location\n"
    printf "     c.    Check on-disk %s config\n" "$sng"
    if sng_rng
    then
        printf "     lc.   Show loaded %s config\n" "$sng"
    fi
    printf "     sd.   Run %s debugging mode\n" "$sng"
    printf "     ld.   Show %s debug info\n\n" "$lr"
    printf "     ui.   "
    if "$uiscribeInstalled"
    then printf "Run"
    else printf "Install"
    fi
    printf " %s\n" "$uiscribeName"
    printf "     e.    Exit to Main Menu\n"
}

main_menu()
{
    and_lr=" & $lr cron\n"
    if sng_rng
    then
        res="Res"
        ins="Rei"
    else
        res="S"
        ins="I"
    fi
    if $is_inst
    then
        printf "     s.    Show %s status\n" "$script_name"
        if sng_rng
        then
            printf "     rl.   Reload %s.conf\n" "$sng"
        fi
        printf "     lr.   Run logrotate now\n"
        printf "     rs.   %start %s" "$res" "$sng"
        if ! sng_rng
        then
            printf "$and_lr"
        else
            printf "\n     st.   Stop %s$and_lr" "$sng"
        fi
        if sng_rng
        then
            printf "\n     u.    Update scribe\n"
            printf "     uf.   Update filters\n"
        fi
        printf "     su.   %s utilities\n" "$script_name"
    fi
    printf "     e.    Exit %s\n\n" "$script_name"
    printf "     is.   %snstall %s\n" "$ins" "$script_name" 
    printf "     zs.   Remove %s\n" "$script_name"
}

##----------------------------------------##
## Modified by Martinski W. [2024-Jun-22] ##
##----------------------------------------##
scribe_menu()
{
	while true
    do
        pause=true
        not_recog=false
        run_scribe=false
        ScriptLogo
        printf "$white $header"
        case "$menu_type" in
            utils)
                ut_menu
                ;;
            *)
                main_menu
                ;;
        esac
        printf "\n$white $header"
        printf "$magenta Please select an option: $std"
        read -r choice
        if $is_inst || [ "$choice" = "e" ] || [ "$choice" = "is" ] || [ "$choice" = "zs" ]
        then
            case "$choice" in
                s)
                    menu_status
                    ;;
                rl)
                    if sng_rng
                    then
                        rld_sngconf
                    else
                        not_recog=true
                    fi
                    ;;
                lr)
                    run_logrotate
                    ;;
                rs)
                    menu_restart
                    menu_status
                    ;;
                st)
                    if sng_rng
                    then
                        menu_stop
                    else
                        not_recog=true
                    fi
                    ;;
                u)
                    if sng_rng
                    then
                        get_vers
                        prt_vers
                        menu_update
                    else
                        not_recog=true
                    fi
                    ;;
                uf)
                    if sng_rng
                    then
                        menu_filters
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
                    gather_debug
                    printf "\n$white Would you like to review the debug data (opens in less)? [y|n] $std"
                    if yes_no; then pause=false; less "$script_debug"; fi
                    ;;
                c)
                    show_config
                    pause=false
                    ;;
                rd)
                    create_conf
                    ;;
                lc)
                    if sng_rng
                    then
                        show_loaded
                        pause=false
                    else
                        not_recog=true
                    fi
                    ;;
                sd)
                    menu_forgrnd
                    ;;
                ld)
                    dlt "$lr_temp"
                    $lr_loc -d $lr_conf >> $lr_temp 2>&1
                    less $lr_temp
                    dlt "$lr_temp"
                    pause=false
                    ;;
                ui)
                    if "$uiscribeInstalled"
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
                    if $is_inst
                    then
                        reinst=true
                        menu_uninstall
                    fi
                    if $do_inst
                    then
                        pre_install
                        Get_ZIP_File
                        menu_install
                        sh "$script_loc" status nologo
                        run_scribe=true
                    fi
                    ;;
                zs)
                    reinst=false
                    menu_uninstall
                    ;;
                *)
                    not_recog=true
                    ;;
            esac
        else
            not_recog=true
        fi
        if $not_recog
        then
            [ -n "$choice" ] && \
            printf "\n${red} INVALID input [$choice]${std}"
            printf "\n${red} Please choose a valid option.${std}\n\n"
        fi
        if "$pause" ; then enter_to "continue" ; fi
        if "$run_scribe" ; then sh "$script_loc" ; exit 0; fi
    done
}

##############
#### MAIN ####
##############

if ! sld_rng && ! sng_rng
then
    printf "\n\n${red} *WARNING*: $white No system logger was running!!\n"
    printf "Starting system loggers ..."
    start_syslogd
fi

# read or create config file #
read_conf

if [ "$action" = "menu" ]
then
    menu_type="main"
    scribe_menu
else
    ScriptLogo
fi

case "$action" in
    about)
        menu_about
        ;;
    help)
        menu_help
        ;;
    install)
        if $is_inst
        then
            printf "\n$white     *** %s already installed! *** \n\n" "$script_name"
            printf " Please use menu command 'is' to reinstall. ${std}\n\n"
            exit 1
        fi
        pre_install
        Get_ZIP_File
        menu_install
        sh "$script_loc" status nologo
        exit 0
        ;;

    #uninstall scribe#
    uninstall | remove)
        reinst=false
        menu_uninstall
        ;;

    #update scribe#
    update)
        if sng_rng
        then
            get_vers
            prt_vers
            menu_update
        fi
        ;;

    #show total combined config#
    show-config | config)
        if $is_inst
        then
            if show_config; then sng_syntax; fi
        fi
        ;;

    #verify syslog-ng is running and logrotate is listed in 'cru l'#
    status)
        if $is_inst; then menu_status; fi
        ;;

    #reload syslog-ng configuration#
    reload)
        if sng_rng; then rld_sngconf; fi
        ;;

    #restart (or start if not running) syslog-ng#
    restart | start)
        if $is_inst
        then
            menu_restart
            menu_status
        fi
        ;;

    #stop syslog-ng & logrotate cron job#
    stop)
        if sng_rng; then menu_stop; fi
        ;;

    #generate debug tarball#
    debug)
        if $is_inst; then gather_debug; fi
        ;;

    #update syslog-ng and logrotate filters - only used in update process#
    filters)
        if sng_rng; then menu_filters; fi
        ;;

    #kill syslogd & klogd - only available via cli#
    service_event)
        if ! sng_rng || [ "$2" = "stop" ]; then exit 0; fi
        #################################################################
        # load kill_logger() function to reset system path links/hacks
        # keep shellcheck from barfing on sourcing $rcfunc_loc
        # shellcheck disable=SC1090
        # shellcheck source=/opt/etc/init.d/rc.func.syslog-ng
        #################################################################
        currTimeSecs="$(date +'%s')"
        lastTimeSecs="$(_ServiceEventTime_ check)"
        thisTimeDiff="$(echo "$currTimeSecs $lastTimeSecs" | awk -F ' ' '{printf("%s", $1 - $2);}')"
        if [ "$thisTimeDiff" -ge 120 ]  ##Only once every 2 minutes at most##
        then
            _ServiceEventTime_ update "$currTimeSecs"
            . $rcfunc_loc
            kill_logger
            sync_conf
            _ServiceEventTime_ update "$(date +'%s')"
        else
            exit 1
        fi
        ;;

    #unrecognized command#
    *)
        printf "\n$white Usage: $script_name ( about | uninstall | update | config | status | reload | restart | debug )\n"
        printf " For a brief description of commands, run: $script_name help $std\n\n"
        exit 1
        ;;
esac

if ! $is_inst
then
    printf "\n$yellow %s $white not installed, command \"%s\" not valid!$std\n\n" "$script_name" "$action"
elif ! sng_rng && [ "$action" != "stop" ]
then
    printf "\n$yellow %s $white not running, command \"%s\" not valid!$std\n\n" "$sng" "$action"
else
    printf "\n"
fi

#EOF#
