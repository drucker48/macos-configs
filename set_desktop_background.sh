
#!/bin/zsh

# Author: D Rucker 
##  Description: Set desktop background to custom company image on macOS during initial provisioning & when triggered by Self Service


## Exit on error
set -euo pipefail 

###################  VARIABLES  ###################
DESKTOP_PNG="/Library/Screen Savers/company_desktop.png"

USER_DIR="/Users/Shared/"

local_user=$(scutil <<< "show State:/Users/ConsoleUser" \
				| awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}')
              
uid=$(id -u "$local_user")

perm_logger="/Users/$local_user/endpoint_config/logs/cp_background_post-install.log"

# Create logger file for success logs
temp_logger="/tmp/bckgrndpkg-post-install.log"
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

# convenience function to run a command as the current user
# usage:
#   runAsUser command arguments...
runAsUser() {  
  if [ "$local_user" != "loginwindow" ]; then
    launchctl asuser "$uid" sudo -u "$local_user" "$@"
  else
    error_log "ERROR: No user logged in. Cannot run command as user."
  fi
}
################### END HELPER FUNCTIONS  ###################


###################  SCRIPT CHECKS  ###################
confirm_running_as_root() {
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

config_desktop_background() {
    ## Confirm desktop png file exists
    if [[ ! -f "$DESKTOP_PNG" ]]; then
         error_log "Desktop PNG file not found. Exiting."
    elif [[ -f "$DESKTOP_PNG" ]]; then
        success_log "INFO: Moving PNG file to Shared Users dir."
        # Move desktop png to Shared Users dir
        cp "$DESKTOP_PNG" "$USER_DIR"
        success_log "SUCCESS: PNG file moved to Shared Users dir."
    else
        error_log "ERROR: Failed to move PNG file to Shared Users dir."
    fi
    # Set Desktop background 
    if [[ -f "/usr/local/bin/desktoppr"  ]]; then
        success_log "INFO: desktoppr command found. Setting desktop background."
        # Set desktop background using desktoppr
        runAsUser /usr/local/bin/desktoppr "$USER_DIR/company_desktop.png"
    else
        error_log "ERROR: desktoppr command not found. Please install desktoppr to set the desktop background."
    fi
    success_log "SUCCESS: Desktop background configured."
}
main() {
    confirm_running_as_root
    config_desktop_background
    exit
}
main
