
#!/bin/zsh
# Author: D Rucker | IT Endpoints Engineer 
# Installs xcode command line tools on endpoints 
# Adapted from:
# https://developer.apple.com/forums/thread/698954?answerId=723615022#723615022
# https://github.com/Homebrew/install/blob/master/install.sh#L812
# https://github.com/rtrouton/rtrouton_scripts/blob/main/rtrouton_scripts/install_xcode_command_line_tools/install_xcode_command_line_tools.sh

function info_log() {
  local level="$1"; shift
  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] [$level] $*" >&2
}

# This temporary file prompts the 'softwareupdate' utility to list the Command Line Tools
CMD_LINE_TOOLS_TEMP_FILE="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"

xcode-select -p &> /dev/null
if [[ $? -ne 0 ]]; then
    info_log "Installing XCode CLI tools ------------"
    /usr/bin/touch "$CMD_LINE_TOOLS_TEMP_FILE"
    CMD_LINE_TOOLS_VERSION=$(/usr/sbin/softwareupdate -l | /usr/bin/grep "\*.*Command Line" | /usr/bin/tail -n 1 | /usr/bin/sed 's/^[^C]* //')
	/usr/sbin/softwareupdate -i "$CMD_LINE_TOOLS_VERSION" --verbose;
    /bin/rm -f "$CMD_LINE_TOOLS_TEMP_FILE"
    info_log "Temp file removed successfully."
else
    info_log "XCode CLI tools is already installed ------------"
fi
