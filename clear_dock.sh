
# Author: D Rucker 
##  Description: This script will configure the dock for macOS endpoints.
## To be deployed via Jamf.

## Exit on error
set -euo pipefail 

###################  VARIABLES  ###################
currentuser=$(/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }')
uid=$(id -u "$currentuser")
perm_logger="/Users/$currentuser/endpoint_config/logs/config_dock_errors.log"

# Create logger file for success logs
temp_logger="/tmp/config_dock.log"
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
  if [ "$currentuser" != "loginwindow" ]; then
    launchctl asuser "$uid" sudo -u "$currentuser" "$@"
  else
    error_log "ERROR: No user logged in. Cannot run command as user."
  fi
}
################### END HELPER FUNCTIONS  ###################

###################  SCRIPT CHECKS  ###################
run_script_checks() {
    ## Must be run as root
    if [[ $EUID -ne 0 ]]; then
        error_log "This script must be run as root"
    fi 

    ## Configure logger file
    if [[ ! -d "/Users/$currentuser/endpoint_config/logs/" ]]; then
        mkdir -p "/Users/$currentuser/endpoint_config/logs/"
        # Creat logger file for errors
        touch "$perm_logger"
        success_log "INFO: Logger file configured."
    else
        success_log "INFO: Logger file already configured."
    fi

    # This section waits until the apps we provision are fully installed before updating the dock
    core_apps=(
        "/System/Applications/System Settings.app"
        "/Applications/macOS Self Service.app"
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


###################  DOCK SETUP  ###################
install_dockutil() {
    # Installs the latest release of dockutil from Github
 
    APP=dockutil
    
    # Download latest release PKG from Github
    curl -s https://api.github.com/repos/kcrawford/dockutil/releases/latest \
    | grep "https*.*pkg" | cut -d : -f 2,3 | tr -d \" \
    | xargs curl -SL --output /tmp/$APP.pkg
    
    # Install PKG to root volume
    installer -pkg /tmp/$APP.pkg -target /
    success_log "Installed $APP"
    
    # Cleanup
    rm /tmp/$APP.pkg
}

# Check if dockutil is installed
confirm_dockutil_is_installed() {
    if ! command -v dockutil &> /dev/null; then
        success_log "dockutil could not be found. Installing..."
        # Initiate policy in Jamf to install dockutil
        install_dockutil
    fi
}

disable_dock_show_recent_apps() {
    #Change Dock setting to not show recent apps
    /usr/bin/defaults write "/Users/${currentuser}/Library/Preferences/com.apple.dock.plist" show-recents -bool false
    success_log "Disabled recent apps in the dock"

    #Change ownership of the Dock plist file to the current user.
    chown "${currentuser}" "/Users/${currentuser}/Library/Preferences/com.apple.dock.plist"
    success_log "Changed ownership of the Dock plist file to $currentuser"

    killall Dock
}

clear_dock() {
    # Clear the dock
    runAsUser /usr/local/bin/dockutil --remove all --no-restart "/Users/$currentuser/Library/Preferences/com.apple.dock.plist"
    sleep 7
    killall cfprefsd Dock
    sleep 7
    success_log "Dock Reset"
}

confirm_dock_is_cleared() {
    # Check if the dock is cleared in a loop
    max_attempts=5
    attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        dock_items_count=$(runAsUser /usr/local/bin/dockutil --list "/Users/$currentuser/Library/Preferences/com.apple.dock.plist" | wc -l)
        
        if [[ $dock_items_count -eq 0 ]]; then
            success_log "Dock successfully cleared."
            return 0
        else
            success_log "Dock not cleared. Items remaining: $dock_items_count. Attempt $((attempt + 1))/$max_attempts"
            runAsUser /usr/local/bin/dockutil --remove all --no-restart "/Users/$currentuser/Library/Preferences/com.apple.dock.plist"
            sleep 5
            killall cfprefsd Dock
            sleep 5
        fi
        
        ((attempt++))
    done
    
    error_log "ERROR | Failed to clear dock after $max_attempts attempts."
}
###################  END DOCK SETUP  ###################

main() {
    run_script_checks
    confirm_dockutil_is_installed
    disable_dock_show_recent_apps
    clear_dock
    confirm_dock_is_cleared
    exit 0
}
main
