
#!/bin/zsh

# Author: D Rucker 
##  Description: Set default browser to Google Chrome on macOS during initial provisioning & when triggered by Self Service

## To be deployed via Jamf.

## Exit on error
#set -euo pipefail 

###################  VARIABLES  ###################

local_user=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

uid=$(id -u "$local_user")

perm_logger="/Users/$local_user/endpoint_config/logs/set_default_browser.log"

# Create logger file for success logs
temp_logger="/tmp/set_default_browser-errors.log"
touch "$temp_logger"
################### END VARIABLES  ###################

################### HELPER FUNCTIONS  ###################
function error_log() {
    echo >&2 -e "[$(date +"%Y-%m-%d %H:%M:%S")] ${1-}" >> "$perm_logger"
    exit 1
}

function success_log() {
    echo >&2 -e "[$(date +"%Y-%m-%d %H:%M:%S")] ${1-}" >> "$temp_logger"
}

runAsUser() {  
  if [ "$local_user" != "loginwindow" ]; then
    launchctl asuser "$uid" sudo -u "$local_user" "$@"
  else
    error_log "ERROR: No user logged in. Cannot run command as user."
  fi
}

################### END HELPER FUNCTIONS  ###################


###################  SCRIPT CHECKS  ###################
config_logger() {
    ## Must be run as root
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi 

    ## Configure logger file
    if [[ ! -d "/Users/$local_user/endpoint_config/logs/" ]]; then
        mkdir -p "/Users/$local_user/endpoint_config/logs/"
        # Creat logger file for errors
        touch "$perm_logger"
        success_log "INFO: Logger file configured."
    else
        success_log "INFO: Logger file already configured."
    fi
}
###################  END SCRIPT CHECKS  ###################

confirm_default_browser_tool() {
    ## Confirm default browser is set to Chrome
    if [[ -f "/opt/macadmins/bin/default-browser" ]]; then
        success_log "INFO: default-browser tool installed."
    else
        echo "ERROR: /opt/macadmins/bin/default-browser not found. Please ensure the Headway package is installed."
        error_log "ERROR: /opt/macadmins/bin/default-browser not found. Please ensure the Headway package is installed."
    fi
}

confirm_chrome_installed() {
    core_apps=(
        "/System/Applications/System Settings.app"
        "/Applications/Google Chrome.app"
    )
    for app in "${core_apps[@]}"; do
        max_wait_time=$((10 * 60)) # Maximum wait time in seconds (10 minutes)
        elapsed_time=0
        until [[ -e "$app" ]]; do
            if (( elapsed_time >= max_wait_time )); then
                error_log "ERROR | Timeout reached: $app not installed after $((max_wait_time / 60)) minutes."
                break
            fi
            # $RANDOM generates a random number; here we calculate a delay between 10 and 59 seconds
            delay=$(( $RANDOM % 50 + 10 ))
            success_log "INFO |  +  Required app $app not installed, waiting [$delay] seconds"
            sleep $delay
            elapsed_time=$((elapsed_time + delay))
        done
    done
    success_log "$(date) | Confirmed apps are downloaded. Moving on. . ."
}
###################  END SCRIPT CHECKS  ###################

set_default_browser() {
    ## Set default browser to Google Chrome
    runAsUser /opt/macadmins/bin/default-browser --identifier com.google.chrome
    success_log "INFO: Default browser set to Google Chrome."
}

main() {
    config_logger
    confirm_default_browser_tool
    confirm_chrome_installed
    set_default_browser
    exit
}
main
