#!/usr/bin/env zsh

loggedInUser="$( /bin/echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/Name :/&&!/loginwindow/{print $3}' )"
loggedInUserHomeFolder="$(/usr/bin/dscl . -read /users/$loggedInUser NFSHomeDirectory | cut -d " " -f 2)"
plist="$loggedInUserHomeFolder/Library/Preferences/MobileMeAccounts.plist"
plistKey='Accounts:0:isManagedAppleID'
RESULT='false'

if [[ -n "${plistKey}" && -n "${plist}" ]]; then
    if value="$(/usr/libexec/PlistBuddy -c "Print :${plistKey}" "${plist}")"; then
        RESULT="${value}"
    fi
fi

/bin/echo "<result>${RESULT}</result>"

exit 0
