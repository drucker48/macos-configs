
#!/bin/bash

# Author: D Rucker 
##  Description: This script will attempt to configure the sudo timeout config to 1 minute for macOS endpoints.
## To be deployed via Jamf. 

## Exit on error
#set -euo pipefail 

###################  VARIABLES  ###################

sudoers_file="/private/etc/sudoers.d/mscp"
backup_sudoers_file="/private/etc/sudoers.d/mscp.bak"

local_user=$(scutil <<< "show State:/Users/ConsoleUser" \
				| awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}')

perm_logger="/Users/$local_user/endpoint_config/logs/config_sudo_timeout.log"

# Create logger file for success logs
temp_logger="/tmp/config_sudo_timeout.log"
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

################### END HELPER FUNCTIONS  ###################


###################  SCRIPT CHECKS  ###################
run_script_checks() {
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

    ## Confirm sudoers.d file exists
    if [[ ! -f "$sudoers_file" ]]; then
         error_log "Sudoers mscp file not found. Exiting."
    elif [[ -f "$sudoers_file" ]]; then
        success_log "INFO: Creating backup of sudoers file."
        # Backup the current sudoers file
        cp "$sudoers_file" "$backup_sudoers_file"
        success_log "SUCCESS: Backup of sudoers file created."
        chmod 0440 /private/etc/sudoers.d/mscp
        success_log "SUCCESS: Permissions changed for /private/etc/sudoers.d/mscp"
    else
        error_log "ERROR: /private/etc/sudoers.d/mscp not found. Skipping permission change."
    fi
}
###################  END SCRIPT CHECKS  ###################


###################  CONFIGURE SUDO TIMEOUT  ###################        
config_sudo_timeout() {
    # Add or update the Defaults timestamp_timeout line
    if grep -q "^Defaults.*timestamp_timeout" "$sudoers_file"; then
        # Update the existing line
        sed -i.bak 's/^Defaults.*timestamp_timeout.*/Defaults timestamp_timeout=1.0/' "$sudoers_file"
    else
        # Add the line
        echo "Defaults timestamp_timeout=1.0" >> "$sudoers_file"
    fi
}

validate_sudoers() {
    # Validate the sudoers file
    visudo -c -f "$sudoers_file"
    if [[ $? -ne 0 ]]; then
        error_log "ERROR: There is a syntax error in the sudoers file. Restoring the backup."
        cp "$backup_sudoers_file" "$sudoers_file"
    else
        success_log "SUCCESS: Sudoers file validated."
    fi
}

confirm_sudo_timeout() {
    check_sudo_timeout=$(/usr/bin/sudo /usr/bin/sudo -V | /usr/bin/grep -c "Authentication timestamp timeout: 1.0 minutes")
    if [[ $check_sudo_timeout -eq 1 ]]; then
        success_log "SUCCESS: Sudoers timeout has been set to 1 minute."
    else
        error_log "ERROR: Sudoers timeout has not been set to 1 minute. Exiting."
    fi
}
###################  END CONFIGURE SUDO TIMEOUT  ###################

###################  DELETE LOG DIRECTORY  ###################

# If no errors recorded delete log file
delete_error_logs() {
    if ! grep -q "ERROR:" "$perm_logger"; then
        rm -f "$perm_logger"
    fi
}
###################  END DELETE LOG DIRECTORY  ###################

main() {
    run_script_checks
    config_sudo_timeout
    validate_sudoers
    confirm_sudo_timeout
    delete_error_logs
}
main
