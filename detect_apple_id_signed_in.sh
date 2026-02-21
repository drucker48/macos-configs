
#!/usr/bin/env zsh
#Jamf Extension Attribute for detecting in an Apple ID is signed in 

loggedInUser="$( /bin/echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/Name :/&&!/loginwindow/{print $3}' )"
loggedInUserHomeFolder="$(/usr/bin/dscl . -read /users/$loggedInUser NFSHomeDirectory | cut -d " " -f 2)"
plist="$loggedInUserHomeFolder/Library/Preferences/MobileMeAccounts.plist"

if [[ -f "$plist" ]]; then
	echo "<result>True</result>"
else
	echo "<result>False</result>"
fi
