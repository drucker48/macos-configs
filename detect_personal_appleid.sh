
#!/bin/zsh

# Author: D Rucker

# Description: Script to detect if a user is signed into AppleID
# with a personal account and is syncing documents
set -euo pipefail

local_user=$(scutil <<< "show State:/Users/ConsoleUser" \
				| awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}')

# See what account is signed in as the Apple ID 
account_id=$(sudo -u "$local_user" defaults read MobileMeAccounts Accounts | grep AccountID | cut -d '"' -f2)

# If the Mobile Documents directory exist then iCloud Doc syncing is turned on. 
mobile_docs_dir="/Users/$local_user/Library/Mobile Documents/"

# Check if the output is a valid email address and not a @findheadway address
if [[ "$account_id" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] && [[ "$account_id" != *@findheadway.com ]]; then
    # Check if the Mobile Documents directory exists
    if [[ -d "$mobile_docs_dir" ]]; then
        # Create the file in /var/log
        echo "Non-Headway Account Detected: $account_id" > /var/log/Personal_ID_Sync.txt
    else
        echo "Non-Headway account found, but $mobile_docs_dir does not exist."
    fi
else
    echo "No non-Headway account found, or the output is invalid."
fi
