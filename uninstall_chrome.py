#!/usr/bin/env python3

# Author: D RUcker | Endpoints Engineer 
# This script should not be run on an endpoint manually. 
# This script has been built into a custom Configuration Policy in JAMF. 
# It will be deployed as an available tool in the macOS Self Service app on macOS endpoints, 
# as a method to troubleshoot issues with Google Chrome performance 
# by uninstalling the app and reinstalling it via Self Service.


import logging.handlers
import os
import shutil
import subprocess
import sys

LOGGER = logging.getLogger("chrome-uninstall")

DIRS_TO_CHECK = [
    "/Applications/Google Chrome.app/",
    "~/Library/Preferences/com.google.Chrome.plist",
    "~/Library/Application Support/Google/Chrome",
    "~/Library/Saved Application State/com.google.Chrome.savedState/",
    "~/Library/Google/GoogleSoftwareUpdate/Actives/com.google.Chrome"
]

def setup_logger():
    logging.basicConfig(
        filename="/var/log/chrome-uninstall.log",
        level=logging.DEBUG,
        filemode="w",
        datefmt="%Y-%m-%d %H:%M:%S",
        format="%(asctime)s - %(levelname)s - %(message)s",
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

def delete_chrome_dirs():
    """
    Look for file paths and delete them. 
    """
    for path in DIRS_TO_CHECK:
        resolved_path = os.path.expanduser(path)  # Resolve ~ to home directory
        if os.path.exists(resolved_path):
            try:
                if os.path.isdir(resolved_path):
                    shutil.rmtree(resolved_path)  # Delete directory and contents
                elif os.path.isfile(resolved_path):
                    os.remove(resolved_path)  # Delete file
                LOGGER.info(f"Deleted: {resolved_path}")
            except (OSError, FileNotFoundError) as e:
                LOGGER.error(f"Failed to delete {resolved_path}. Error: {e}")
        else:
            LOGGER.info(f"Path does not exist: {resolved_path}")

def main():
    setup_logger()
    run_command("/usr/bin/pkill Chrome")
    delete_chrome_dirs()

if __name__ == "__main__":
    sys.exit(main())
