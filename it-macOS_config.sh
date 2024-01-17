#!/bin/bash

# Author: D Rucker
# Created: 08/31/22
# Description: This script will bootstrap IT personnel M1 MacBooks. 
# Modified: 08/30/22 by D Rucker

clear
local_user=$(whoami)
HOME=$(/Users/"$local_user"/)
HOMEDIR=$(~/)
echo Ensure shell is Bash . . .
chsh -s /bin/bash 

# detect platform
function check_which_platform() {
    platform="$(uname)"
    case "$platform" in
        Darwin)
            echo "Platform detected: OS X"
            return 0
            ;;
        Linux)
            echo "Platform detected: Linux"
            return 1
            ;;
        *)
            echo "Platform not supported"
            exit 1
            ;;
    esac
}


check_hardware_version() {
	HARDWARE_VERSION=$(/usr/sbin/system_profiler SPHardwareDataType |grep "Chip:" |awk 'FNR <= 1' | cut -d : -f 2)
	if [ "$HARDWARE_VERSION" == " Apple M1" ]; then
		echo "Detected Apple M1 CPU. Proceeding. . ."	
	else
		echo "This is not an M1 MacBook. Ending script" 
        echo
		exit
	fi
}

# formatting for headers
function print_header() {
    section="${1}"
    pad_length=$(((100 - ${#section}) / 2))
    padding=""
    for ((x=1; x <= pad_length; x++)); do
        padding+="="
    done
    echo "${padding} ${section} ${padding}"
}

# prompt user if okay to proceed
confirm_continue() {
    local action="${1}"
    local response
    echo "${action}"
    echo "OK to proceed? [y/N]: "
    # SC-NOTE: We don't care about backslash mangling by read - disable check 2162 https://github.com/koalaman/shellcheck/wiki/SC2162
    # shellcheck disable=SC2162
    read -sn1 response
    case "${response}" in
        [yY])
            return 0
        ;;
        *)
            return 1
        ;;
    esac

}


# get name from system whoami
get_name_osx() {
    full_name="$(id -F)"
}


# set up user's name and associated info
parse_name_info() {
    local names=(${full_name})
    email_domain="aurora.tech"

    echo "Welcome ${names[0]}"

    # Add test to see if initials are already set in the environment, otherwise prompt
    # SC-NOTE: We don't care about backslash mangling on read - disable check 2162 https://github.com/koalaman/shellcheck/wiki/SC2162
    # shellcheck disable=SC2162
    if [[ -z ${INITIALS+x} ]]; then
        read -rp "What is your middle initial? " middle_i
    else
        middle_i="${INITIALS:1:1}"
    fi

    inits="${names[0]:0:1}${middle_i}${names[1]:0:1}"
    inits="$(tr '[:lower:]' '[:upper:]' <<< "${inits}")"

    if [[ -n ${CORP_USERNAME} ]]; then
        username="${CORP_USERNAME}"
    else

        username="${names[0]:0:1}${names[1]}"
        username="$(tr '[:upper:]' '[:lower:]' <<< "${username}")"
    fi

    if [[ -n ${CORP_GPGKEY_ADDRESS} ]]; then
        email_addy="${CORP_GPGKEY_ADDRESS}"
    else
        email_addy="${username}@${email_domain}"
    fi
}


install_homebrew() {
    if ping -q -c 1 -W 1 8.8.8.8 >/dev/null
        then
	    echo "Internet is available"
    fi
    echo "Installing Homebrew"
    cd /Users/"$local_user"/ && { curl -O https://raw.githubusercontent.com/Homebrew/install/master/install.sh ; cd -; } 
    echo
    echo
    echo Running install.sh script . . .
    echo
    echo
    source /Users/"$local_user"/install.sh
    echo
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/$local_user/.profile 
    eval "$(/opt/homebrew/bin/brew shellenv)"
    echo
    echo 'Turning off brew analytics.'
    /opt/homebrew/bin/brew analytics off
    echo
    echo 'Installing bash with brew.'
    /opt/homebrew/bin/brew install bash
    echo
    echo -e "***** Homebrew install complete! *****"
    echo
    echo -e "***** Installing some additional tools . . . *****"
    /opt/homebrew/bin/brew install toilet 
    /opt/homebrew/bin/brew install fortune
    /opt/homebrew/bin/brew install pv
    /opt/homebrew/bin/brew install moreutils
    /opt/homebrew/bin/brew install shellcheck 
    /opt/homebrew/bin/brew install python3
    echo
    echo
}

confirm_shell() {
    echo 'Confirming /etc/shell file config. . .' |pv -qL 10
    STRING="/bin/bash"
    FILE="/etc/shells"
        if  grep -q "$STRING" "$FILE" ; then
            echo '/bin/bash is listed in the /etc/shell file' ; 
        else
            echo 'hmmm . . Bash is not in the shell file?' ; 
        fi
    echo
    echo
    chsh -s /opt/homebrew/bin/bash
    echo -e "***** Installing gpg with brew. . . . *****" |pv -qL 10
    /opt/homebrew/bin/brew install gpg
    echo
    echo 'Symlink homebrew/bin to /bin'
    ln -s /opt/homebrew/bin /usr/local/bin 
}


# set up standard bash_profile
std_bash_profile() {

pbcopy <<-EOF
HOME=~/
local_user='$(whoami)'

# Alias for it-ops dir 
alias ops='cd /Users/"$local_user"/src/it-ops

# Alias command for timestamp
alias now='echo | ts && echo $(id -F)'

# Load .bashrc if it exists
test -f ${HOME}/.bashrc && source ${HOME}/.bashrc


export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced

#Make sure ~/bin is in the path
#[[ ! "$PATH" =~ "${HOME}/bin" ]] && export PATH="${HOME}/bin:${PATH}"

EOF

}

# sets up bash_profile
do_bash_profile() {
    print_header "Setting up bash profile"
    cd 
    #if find .bash_profile -type f 
    #then
        #backup_file="old_bash_profile_$(date +%F)"
        #echo "Backing up existing .bash_profile as: $backup_file"
        #sleep 1
        #mv .bash_profile /"$backup_file"
    #else
    echo "Writing new bash profile from template"
    cd "$HOME"
    touch .bash_profile 
    open -a TextEdit.app .bash_profile

    #mkdir -p .profile.d
    #Re-source the bash profile so it is available for the rest of this run
    # SC-NOTE: Disable non-constant source check https://github.com/koalaman/shellcheck/wiki/SC1090
    # SC-NOTE: we know what ~ will eval to even though sc can't
    #shellcheck disable=SC1090
    source .bash_profile
}


confirm_repo() {
    echo 'Confirming the IT repo has been cloned. . .' |pv -qL 10
    find /Users/"$local_user"/src/it-ops -mtime -1 -type d -print &> /dev/null
		if [ $? -eq 0 ]
		then
		    echo 'Confirmed IT repo has been cloned! Confirming proper access to github. . .' |pv -qL 10
            ssh -T git@github.com
            echo
        else
            echo '***** You need to clone the IT Repo to the /src dir before proceeding. See instructions here: https://doc.common.cloud.aurora.tech/doc/codelabs/GitHubAccountSetup.html ***** '
            exit
        fi    
}


gcloud_sdk() {
    echo 'Downloading gcloud SDK package'
    HOME=$(/Users/"$local_user")
    gcloud_file=$(google-cloud-cli-402.0.0-darwin-arm.tar.gz)
    gcloud_url="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-402.0.0-darwin-arm.tar.gz"
    (cd "$HOME" && sudo curl -O -L "$gcloud_url")
    echo
    echo 'Unpacking gcloud cli download. . .'
    /usr/bin/gunzip "${HOME}/${gcloud_file}" -C "$HOME" 
    echo 'running gcloud install script . . .'
    bash "$HOME"/google-cloud-sdk/install.sh
    "$HOME"/google-cloud-sdk/bin/gcloud init
    "$HOME"/google-cloud-sdk/bin/gcloud components update
    "$HOME"/google-cloud-sdk/bin/gcloud auth application-default login
    #print_header 'Downloading gcloud SDK package' |pv -qL 10
    #cd "$HOME"
    #/opt/homebrew/bin/brew install --cask google-cloud-sdk 
    #echo
    #echo
    #echo
    #/opt/homebrew/bin/gcloud init 
    #/opt/homebrew/bin/gcloud components update
    #/opt/homebrew/bin/gcloud auth application-default login
    echo 'Verifying access to the bucket . . .'
    curl -s https://storage.googleapis.com/ai-encrypt/ascii_keyring | gpg --import
}


# install GAM
do_install_gam() {
    #GAM Related Consts
GAM_OS="$(uname -s)"
GAM_GLIBC_VER="2.27"
GAM_MACOS_VER="10.15.4"
GAM_DOWNLOAD_URL="https://github.com/jay0lee/GAM/releases/download"
GAM_LATEST_VERSION=$(curl https://github.com/GAM-team/GAM/releases/latest -s -L -I -o /dev/null -w '%{url_effective}' |cut -f2 -d'"' |rev |cut -f1 -d'/' |rev |tr -d v)
GAM_TARGET_DIR="$HOME/gam/GAM-$GAM_LATEST_VERSION" > /dev/null 2>&1
    
    print_header "Installing GAM ${GAM_LATEST_VERSION}"
    
    #Check OS to get correct binary
    case $GAM_OS in
    [lL]inux)
        gamfile="linux-x86_64-glibc${GAM_GLIBC_VER}.tar.xz"
        ;;
    [Mm]ac[Oo][sS]|[Dd]arwin)
        gamfile="macos-x86_64-MacOS${GAM_MACOS_VER}.tar.xz"
        ;;
    *)
        echo "Error detecting OS.  Looks like you're runnning on ${GAM_OS}? Exiting..."
        exit
        ;;
    esac

    file_name="gam-${GAM_LATEST_VERSION}-${gamfile}"
    file_url="${GAM_DOWNLOAD_URL}/v${GAM_LATEST_VERSION}/${file_name}"

    # Temp dir for archive
    temp_archive_dir=$(mktemp -d 2>/dev/null || mktemp -d -t 'mytmpdir')
    echo "Downloading file: ${file_url} to ${temp_archive_dir}"

    # Save archive to temp dir and extract to target dir
    (cd "${temp_archive_dir}" && curl -O -L "${file_url}")

    rc=$?
    if [[ "${rc}" != 0 ]]; then
    echo "Error downloading, check version number & download URL. Exiting..."
    echo "Download URL was: ${file_url}"
    echo "Error was ${rc}, exiting..."
    exit
    else
    echo "Download successful."
    fi

    mkdir "$GAM_TARGET_DIR"
    echo "Extracting archive to $GAM_TARGET_DIR"
    /usr/bin/gunzip "${temp_archive_dir}/${file_name}" -C "$GAM_TARGET_DIR" --strip 1

    rc=$?
    if [[ "${rc}" != 0 ]]; then
    echo "Error extracting the GAM archive with tar failed with error $rc. Exiting..."
    exit
    else
    echo "Finished extracting GAM archive."
    fi

    # Create version symlinks in gam directory
    pushd "$HOME/gam" 
    ln -fs "${GAM_TARGET_DIR}/gam" "gam_${GAM_LATEST_VERSION//.}.py"
    ln -fs "${GAM_TARGET_DIR}/gam" "gam.py"
    popd

    # Create symlinks in bin directory
    pushd "$HOME/bin"
    ln -fs "$HOME/gam/gam.py" "gam"
    ln -fs "$HOME/gam/gam.py" "gam.py"
    popd

    echo "Congratulations, GAM ${GAM_LATEST_VERSION} has been installed"
    echo "Please get a copy of oauth2service.json and client_secrets.json"
    echo "from a team member and copy them to ~/gam"
}

confirm_json() {
    echo "Have you copied your oauth2service.json and client_secrets.json files to your ~/gam dir? (y/n)"
    read -r ynu
    echo
	if [ "$ynu" == y ]
	then
    echo "We can proceed now!"
    elif [ "$ynu" == n ]
    then 
    echo "Sorry. You need to transfer your .json files to the ~/gam dir before proceeding."
    exit
    fi
}


run_gam_new() {
    echo 'Locating get_new_gam script' |pv -qL 10
    /Users/"$local_user"/src/it-ops/gam/get_new_gam.sh
    source /Users/"$local_user"/.bash_profile
    echo
    echo
}     



# pip3 install list of modules
pip3_install() {
    module_list="$*"
    # SC-NOTE: We want the array expansion below, so not quoting.
    # Disable 2068 - https://github.com/koalaman/shellcheck/wiki/SC2068
    #shellcheck disable=SC2068
    for module in ${module_list[@]}; do
        pip3 install --quiet --upgrade "${module}"
    done
}


# install pip modules to system python
do_sys_pip_modules() {
    print_header "Installing pip modules"
    pip3_modules=(pip pep8 flake8 boto3 passlib python-gnupg jinja2 weasyprint code128 cairocffi slacker pylint)
    pip3_install "${pip3_modules[*]}"
}


# source and symlink files for ops-tools
do_source_ops_bash() {
    print_header "Sourcing it-ops bash"

    ops_bash_path="$HOME"/it-ops/bash/corp-profile.d

    if [[ -d "${ops_bash_path}" ]]; then
        echo "Sourcing files from ${ops_bash_path} and linking to local .profile.d/"

        mkdir -p "$HOME"/.profile.d
        pushd Users/"$local_user"/.profile.d
            # SC-NOTE: We want the variable expansion below, so not quoting and disable 2046 - https://github.com/koalaman/shellcheck/wiki/SC2046
            #shellcheck disable=SC2046
            for file in {"$ops_bash_path"}/*.sh; do
                ln -fs "${file}" $(basename "${file}")
            done
        popd 
    else
        echo "Warning: Failed to locate ${ops_bash_path}.  Make sure you have ops-tools checked out and up to date."
        echo "If this is the first time through you can safely ignore this warning."
    fi
}


 gpg_key() {
        echo "Do you need to generate a new gpg key? (y/n)" |pv -qL 10
        echo
        read -r ynu
        if [ "$ynu" == y ]
            then
            echo 'Initiating key generation . . .' |pv -qL 10
            source /Users/"$local_user"/src/it-ops/onboarding/ai_genkey.sh
            echo
            fi
        if [ "$ynu" == n ]
                then
                echo 'checking to confirm gpg key already exists . . .' |pv -qL 10
                echo
                local keycount
                set +e  #When no keys exist returns non-zero status
                keycount="$(gpg --list-secret-keys | grep -c "^uid")"
                set -e
                if [[ ${keycount} -gt 0 ]]; then
                gpg --list-secret-keys
                echo "You already have secret keys!"
                echo
                echo 'Verifying access to the bucket . . .'
                curl -s https://storage.googleapis.com/ai-encrypt/ascii_keyring | gpg --import
                echo
                echo
                fi
                #gpg_key_setup1=$(gpg --list-secret-keys | grep 'uid' | awk '{print $5}')
                #gpg_key_setup2=$(gpg --list-secret-keys | grep 'uid' | awk '{print $2}')
                #if [ "$gpg_key_setup1" == "<$local_user@aurora.tech>" ] && [ "$gpg_key_setup2" == "<ultimate" ]; then
                #echo 'Looks like your account has a key assigned with trust level ultimate! Follow these instructions to extract private key and import on different machine: https://makandracards.com/makandra-orga/37763-gpg-extract-private-key-and-import-on-different-machine' 
                #echo 
                #echo 'Verifying access to the bucket . . .'
                #curl -s https://storage.googleapis.com/ai-encrypt/ascii_keyring | gpg --import
                #fi
        fi 
 }


main() {
     check_hardware_version
     confirm_continue
     get_name_osx
     parse_name_info
     install_homebrew
     confirm_shell
     std_bash_profile
     do_bash_profile
     confirm_repo
     #gcloud_sdk
     #do_install_gam
     #confirm_json
     #run_gam_new
     #pip3_install
     #do_sys_pip_modules
     #do_source_ops_bash
     #gpg_key
     echo "IT MacOS Bootstrap complete."
     toilet ONE OF US! |pv -qL 50
     echo
     echo Now share some wisdom today:
     fortune
}

main