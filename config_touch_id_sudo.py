
#!/usr/bin/env python3

# Author: D Rucker | Endpoints Engineer 
# This script should not be run on an endpoint manually. 
# This script has been built into a custom Configuration Policy in JAMF. 
# It will be deployed as an available tool in the macOS Self Service app on macOS endpoints,
# to configure TouchID for sudo access in a shell

import logging.handlers
from pathlib import Path
import shutil
import subprocess
import sys


LOGGER_NAME = "touch_id_sudo"
LOGGER = logging.getLogger(LOGGER_NAME)
SUDO_LOCAL_TEMPLATE = '/etc/pam.d/sudo_local.template'
SUDO_FILE_CHECK = Path(SUDO_LOCAL_TEMPLATE)
BACKUP_SUDO_FILE = SUDO_LOCAL_TEMPLATE + ".bak"
NEW_SUDO_FILE_NAME = "/etc/pam.d/sudo_local"

class TouchIDError(Exception):
    pass

def setup_logger():
    """
    Set up the logger for the script.

    This function configures the logging settings for the script, including the log level,
    format, date format, and log file location.

    """
    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        filename="/var/log/touch_id_sudo.log",
    )
    logging.getLogger().addHandler(logging.StreamHandler(stream=sys.stdout))

# Configure shell commands and return output function
def run_command(command, inp=None):
    try:
        result = subprocess.run(
            command,
            shell=True,
            check=True,
            input=inp,
            text=True,
            capture_output=True,
        )
        LOGGER.info(f"Command executed successfuly: {command}")
        return result.stdout
    except subprocess.CalledProcessError as e:
        LOGGER.error(f"Error executing command: {command}\nError message: {e.stderr}")

def confirm_touchid_config():
     
     touchid_setup = run_command("/usr/bin/bioutil -r")
     
     if not "Biometrics for unlock: 1" in touchid_setup:
         raise TouchIDError("TouchID not configured.")
             
def backup_sudo_template():
    """
    Create a backup of the sudo_local_template file
    """
    if SUDO_FILE_CHECK.exists():
         # Create a backup of the sudo_local.template file
        shutil.copy(SUDO_LOCAL_TEMPLATE, BACKUP_SUDO_FILE)

def modify_sudo_local():
        """
        Modify the sudo_local.template file to uncomment pam_tid.so line.
        """
        with open(SUDO_LOCAL_TEMPLATE, 'r') as sudo_file:
            sudo_local_lines = sudo_file.readlines()
        # Iterate through the lines in the file and find the target line
        for i, line in enumerate(sudo_local_lines):
            if line.startswith('#auth'):
                sudo_local_lines[i] = "auth       sufficient     pam_tid.so\n"
                break
    
        with open(SUDO_LOCAL_TEMPLATE, 'w') as sudo_local_file:
            sudo_local_file.writelines(sudo_local_lines)
            LOGGER.info("pam_tid.so line uncommented in sudo_local.template file")

def rename_sudo_local_file():
    """
    Rename sudo_local.template file to sudo_local
    """
    shutil.move(SUDO_LOCAL_TEMPLATE, NEW_SUDO_FILE_NAME)
    
def main():
    """
    Main function to modify the sudo_local.template file and rename it.
    """
    try:
        confirm_touchid_config()
        backup_sudo_template()
        modify_sudo_local()
        rename_sudo_local_file()
    except (
         OSError,
         FileNotFoundError,
         PermissionError,
         TypeError
    ) as e:
         LOGGER.error("Discovered error during run: %s", e)

if __name__ == "__main__":
    sys.exit(main())
