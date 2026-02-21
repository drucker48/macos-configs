
#!/bin/zsh
# Script to fully uninstall Nudge including user preference files. Script will be deployed to
# all Macs via MDM and run as root.
# Credits to @BigMacAdmin from MacAdmins Slack for the original script
# Edits by D Rucker | IT Engineer, Endpoints 
#set -x

###################  VARIABLES  ###################

# Current console user information
console_user=$(/usr/bin/stat -f "%Su" /dev/console)

console_user_uid=$(/usr/bin/id -u "$console_user")


perm_logger="/Users/$console_user/endpoint_config/logs/uninstall_nudge-errors.log"

# Create logger file for success logs
temp_logger="/tmp/uninstall_nudge.log"
touch "$temp_logger"
################### END VARIABLES  ###################


################### HELPER FUNCTIONS  ###################
function info_log() {
  local level="$1"; shift
  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] [$level] $*" >&2
}

function error_log() {
    echo >&2 -e "[$(date +"%Y-%m-%d %H:%M:%S")] ${1-}" >> "$perm_logger"
    echo >&2 -e "[$(date +"%Y-%m-%d %H:%M:%S")] ${1-}"
    exit 1
}

function success_log() {
    echo >&2 -e "[$(date +"%Y-%m-%d %H:%M:%S")] ${1-}" >> "$temp_logger"
    echo >&2 -e "[$(date +"%Y-%m-%d %H:%M:%S")] ${1-}"
}

function rm_if_exists(){
    if [ -e "${1}" ]; then
        rm -rf "${1}"
        success_log "Removed ${1}"
        info_log "INFO" "Removed ${1}"
    fi
}

function forget_pkg(){
    pkgutil --forget "${1}" / > /dev/null 2>&1
    success_log "Forgot package ${1}"
    info_log "INFO" "Forgot package ${1}"
}

################### END HELPER FUNCTIONS  ###################


confirm_running_as_root(){
  # check we are running as root
  if [[ $(id -u) -ne 0 ]]; then
    error_log "ERROR: This script must be run as root **EXITING**"
  fi
}

confirm_logged_in_user(){
  # Only unload the LaunchAgent if there is a user logged in, otherwise
    if [[ -z "$console_user" ]]; then
    info_log "INFO" "Did not detect user"
    elif [[ "$console_user" == "loginwindow" ]]; then
    info_log "INFO" "Detected Loginwindow Environment"
    elif [[ "$console_user" == "_mbsetupuser" ]]; then
    info_log "INFO" "Detect SetupAssistant Environment"
    elif [[ "$console_user" == "root" ]]; then
    info_log "INFO" "Detect root as currently logged-in user"
    else
    # Unload the agent so it can be triggered on re-install
    /bin/launchctl asuser "${console_user_uid}" /bin/launchctl unload -w /Library/LaunchAgents/com.github.macadmins.Nudge.plist  > /dev/null 2>&1
    # Kill Nudge just in case (say someone manually opens it and not launched via launchagent
    /usr/bin/killall Nudge  > /dev/null 2>&1
    fi
}

completely_uninstall_nudge(){
    # Unload the Nudge Logger launchdaemon (if its running)
    if launchctl list | grep -q "/Library/LaunchDaemons/com.github.macadmins.Nudge.logger"; then
        launchctl unload "/Library/LaunchDaemons/com.github.macadmins.Nudge.logger.plist"
    fi

    # Delete the Nudge app bundle
    rm_if_exists "/Applications/Utilities/Nudge.app"

    # Delete the Nudge LaunchAgent
    rm_if_exists "/Library/LaunchAgents/com.github.macadmins.Nudge.plist"

    # Delete the Nudge Logger LaunchDaemon
    rm_if_exists "/Library/LaunchDaemons/com.github.macadmins.Nudge.logger.plist"

    forget_pkg com.github.macadmins.Nudge.Suite
    forget_pkg com.github.macadmins.Nudge.Essentials
    forget_pkg com.github.macadmins.Nudge
    forget_pkg com.github.macadmins.Nudge.LaunchAgent
    forget_pkg com.github.macadmins.Nudge.Logger

    # Cycle through user home folders and delete deferral plists
    users=($(dscl . list /Users UniqueID | awk '$2 >= 501 {print $1}'))

    for user in "${users[@]}"
    do	
        user_id=$(id -u "${user}")
        user_home=$(dscl . -read /Users/"${user}" NFSHomeDirectory | awk {'print$NF'})
        nudge_user_plist="${user_home}/Library/Preferences/com.github.macadmins.Nudge.plist" 
        rm_if_exists "${nudge_user_plist}"	
    done
}

main(){
    confirm_running_as_root
    confirm_logged_in_user
    completely_uninstall_nudge
    success_log "Nudge has been fully uninstalled"
    info_log "INFO" "Nudge has been fully uninstalled"
}
main
