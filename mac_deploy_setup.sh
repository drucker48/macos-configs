#!/bin/bash
#set -x

#########################################################################################
# Author: D Rucker
## This script will configure apps on the dock for macOS
## Credit to Haertel, a Professional Troublemaker and Systems Wizard. (barryhaertel.com) for sharing a few ideas. 
#########################################################################################


log="/var/log/dockUtil.log"

# start logging
exec 1>> $log 2>&1

/usr/bin/curl -sSL -o /tmp/dockutil.pkg  "https://github.com/kcrawford/dockutil/releases/download/3.0.2/dockutil-3.0.2.pkg" || exit 1
installer -pkg /tmp/dockutil.pkg -target / || exit 2
rm -f  /tmp/dockutil.pkg || exit 3

# This section waits until the apps we provision are fully installed before updating the dock
until [[ -a "/Applications/Workspace ONE Intelligent Hub.app" && -a "/Applications/Google Chrome.app" && -a "/Applications/Slack.app" && -a "/Applications/GlobalProtect.app" ]]; do
	delay=$(( $RANDOM % 50 + 10 ))
    echo "$(date) |  +  Required apps not installed, waiting [$delay] seconds"
    sleep $delay
done
echo "$(date) | Confirmed apps are downloaded. Moving on. . ."


CURRENTUSER=$(/bin/ls -l /dev/console | /usr/bin/awk '{print $3}')
echo "$(date) | Current user is $CURRENTUSER"

# This section loops around until the "remove all " function is successful by checking the dock plist for an app that is being removed. In this case, I used Messages.app.
until ! sudo -u "$CURRENTUSER" grep -q "Messages.app" "/Users/$CURRENTUSER/Library/Preferences/com.apple.dock.plist"; do
	sudo -u "$CURRENTUSER" /usr/local/bin/dockutil --remove all --no-restart "/Users/$CURRENTUSER/Library/Preferences/com.apple.dock.plist"
	sleep 7
    killall cfprefsd Dock
	sleep 7
done
echo "$(date) | Dock Reset"

killall cfprefsd Dock
echo "$(date) | Pausing for 10s"
sleep 10
echo "$(date) | Complete"

# Workaround for Ventura (macOS Ver 13.x) System Settings.app name change
if [[ -e "/System/Applications/System Settings.app" ]]; then settingsApp="System Settings.app"; else settingsApp="System Preferences.app"; fi

sudo -u "$CURRENTUSER" /usr/local/bin/dockutil --add "/System/Applications/Launchpad.app" --section apps --no-restart /Users/$CURRENTUSER
sudo -u "$CURRENTUSER" /usr/local/bin/dockutil --add "/Applications/Workspace ONE Intelligent Hub.app" --section apps --no-restart /Users/$CURRENTUSER 
sudo -u "$CURRENTUSER" /usr/local/bin/dockutil --add "/Applications/Google Chrome.app" --section apps --no-restart /Users/$CURRENTUSER
sudo -u "$CURRENTUSER" /usr/local/bin/dockutil --add "/Applications/Slack.app" --section apps --no-restart /Users/$CURRENTUSER
# Check to see if vscode is installed and add it to the dock 
if [[ -e "/Applications/Visual Studio Code.app" ]]; then sudo -u "$CURRENTUSER" /usr/local/bin/dockutil --add "/Applications/Visual Studio Code.app" --section apps --no-restart /Users/$CURRENTUSER; else echo "vscode is not installed"; fi
sudo -u "$CURRENTUSER" /usr/local/bin/dockutil --add "/Applications/GlobalProtect.app" --section apps --no-restart /Users/$CURRENTUSER 
sudo -u "$CURRENTUSER" /usr/local/bin/dockutil --add "/System/Applications/$settingsApp" --section apps --no-restart /Users/$CURRENTUSER
sudo -u "$CURRENTUSER" /usr/local/bin/dockutil --add "/Users/$CURRENTUSER/Downloads/" --view auto --display stack --sort dateadded --section others --no-restart /Users/$CURRENTUSER
sleep 10

killall cfprefsd Dock

# Set Desktop background 
wget -q https://storage.googleapis.com/ai-images/company_desk.png -O /Users/Shared/company_desk.png

sudo -u "$CURRENTUSER" osascript -e 'tell application "Finder" to set desktop picture to POSIX file "/Users/Shared/company_desk.png"'


exit 0
