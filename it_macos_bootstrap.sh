#!/bin/bash

# Author: D Rucker
# Created: 08/31/22
# Description: This script will bootstrap IT personnel M1 MacBooks. 
# Modified: 09/20/22 by D Rucker

clear
local_user=$(whoami)
echo Ensure shell is Bash . . .
chsh -s /bin/bash 

# show help file
function usage() {
    cat <<EOF
    usage: $0 options

    Sets up and configures the shell environment and tooling for a user
    workstation.  Accepts optional flags to do partial setup.  With no command
    arguments provided, this will do all of the following

    OPTIONS:
       -h  Show this message

       -b  Configure Bash Profile
       -w  Install Homebrew
       -c  Confirm Shell setup
       -p  Install Python
       -r  Confirm IT Repo is cloned  
       -g  Configure git  
       -m  Install GAM cli tool
       -o  Source ops-tools bash files
       -s  Configure SSH key

EOF
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


# detect platform
function check_which_platform() {
    platform="$(uname)"
    case "${platform}" in
        Darwin)
            echo "Platform detected: OS X"
            return 0
            ;;
        Linux)
            echo "Platform detected: Linux. This script is for M1 Macs"
            exit
            ;;
        *)
            echo "Platform not supported"
            exit 
            ;;
    esac
}

check_hardware_version() {
	HARDWARE_VERSION=$(/usr/sbin/system_profiler SPHardwareDataType |grep "Chip:" |awk 'FNR <= 1' | cut -d : -f 2)
	if [ "$HARDWARE_VERSION" == " Apple M1" ]; then
		echo "Detected Apple M1 CPU. Proceeding. . ."
        sleep 5	
	else
		echo "This is not an M1 MacBook. Ending script" 
		exit
	fi
}


# prompt user if okay to proceed
function confirm() {
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
function get_name_osx() {
    full_name="$(id -F)"
}



# set up user's name and associated info
function parse_name_info() {
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


# parse and display user's name/name-based info
function do_name_stuff() {
    if [[ "${platform}" = "Darwin" ]]; then
        get_name_osx
    fi
    parse_name_info

    echo "Username: ${username}"
    echo "Initials: ${inits}"
    echo "Email: ${email_addy}"
}


# set up standard bash_profile
function std_bash_profile() {

cat <<-EOF
HOMEDIR=~/
# Load .bashrc if it exists
test -f ${HOME}/.bashrc && source ${HOME}/.bashrc

# Load everything from profile.d folder
for file in ${HOME}/.profile.d/*.sh; do
 source ${file};
done

export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced

#Make sure ~/bin is in the path
[[ ! "$PATH" =~ "${HOME}/bin" ]] && export PATH="${HOME}/bin:${PATH}"

#Determine where a shell function is defined / declared
function find_function {
 shopt -s extdebug
 declare -F "$1"
 shopt -u extdebug
}

alias ll='ls -al'
alias ltr='ls -altr'
alias ltrd='ls -altr |tail -10'
alias resource='source ~/.bash_profile'

# Alias for it-ops dir 
alias onboarding='cd /Users/"$local_user"/src/it-ops/onboarding'

# Alias command for timestamp
alias time='echo | echo $(whoami) $(date +"%F %T")'


'eval "$(/opt/homebrew/bin/brew shellenv)"'

EOF

}


# set up more personalized bash_profile
function get_user_bash() {

    cat <<-EOF

############################################################
# Update the following to personalize your bash_profile
# this file will be automatically be sourced via ${HOME}/.bash_profile

## GPG Email
#The email address associated with your GPG key
export CORP_GPGKEY_ADDRESS="${email_addy}"

export INITIALS="${inits}"

#Folder path to where you will be checking out git projects
export CORP_HOME="\${HOME}/src"

#Folder path for shared onboarding docs
export CORP_ONBOARD="${onboard_path}"

export CORP_USERNAME=\${USER}

export KEY_SUFFIX="[DOMAIN]"
export GIT_ORG="[GITORG]"

# Set architecture flags for Ruby RVM to play nice
export ARCHFLAGS="-arch x86_64"

##########################################################

## Feel free to add your own shell customizations here


EOF

}


# sets up bash_profile
function do_bash_profile() {
    print_header "Setting up bash profile"

    if [[ -e "${HOME}/.bash_profile" ]]; then
        backup_file="old_bash_profile_$(date +%F)"
        echo "Backing up existing .bash_profile as: ${backup_file}"
        sleep 1
        mv "${HOME}/.bash_profile" "${HOME}/${backup_file}"
    fi
    echo "Writing new bash profile from template"
    std_bash_profile > "${HOME}/.bash_profile"

    mkdir -p "${HOME}/.profile.d"

    pushd "${HOME}/.profile.d" >/dev/null 2>&1
        if [[ -e "00-${username}.sh" ]]; then
            echo "Personal profile exists as 00-${username}.sh skipping"
        else
            echo "Creating Personal profile 00-${username}.sh"
            onboard_path="/mnt/chromeos/GoogleDrive/MyDrive/"
            if [[ "${platform}" = "Darwin" ]]; then   # opt i
                onboard_path="/Volumes/GoogleDrive/My Drive/"
            fi
            get_user_bash > "00-${username}.sh"
        fi
    popd >/dev/null 2>&1

    #Re-source the bash profile so it is available for the rest of this run
    # SC-NOTE: Disable non-constant source check https://github.com/koalaman/shellcheck/wiki/SC1090
    # SC-NOTE: we know what ~ will eval to even though sc can't
    #shellcheck disable=SC1090
    source ~/.bash_profile
}

function set_zprofile() {

    cat <<-EOF

############################################################

# Source Hombrew bin dir with shell environment  
'eval "$(/opt/homebrew/bin/brew shellenv)"'


# Setting PATH for Python 3.10
# The original version is saved in .zprofile.pysave
PATH="/Library/Frameworks/Python.framework/Versions/3.10/bin:${PATH}"
export PATH

EOF
}

function confirm_zprofile() {
    set_zprofile >  "${HOME}/.zprofile"
    echo Confirming /Users/$local_user/.zprofile is confirgured correctly
    text="eval $(/opt/homebrew/bin/brew shellenv)"
    zprofile="${HOME}/.zprofile"
        if  grep -q "$text" "$zprofile" ; then
            cat /Users/$local_user/.zprofile
            sleep 5
            echo '.zprofile seems to be configured properly. Confirm:' ;
        else
            echo 'Something is not right. Your .zprofile is not configure properly.' ; 
        fi 
}


# installs packages via homebrew for OS X
function do_install_homebrew_pkgs_osx() {
    print_header "Installing HomeBrew"

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
    echo
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/"$local_user"/.zprofile 
    eval "$(/opt/homebrew/bin/brew shellenv)"
    confirm_zprofile
    source $HOME/.bash_profile
    echo
    echo
    echo 'Installing bash with brew.'
    /opt/homebrew/bin/brew install bash
    echo
    echo -e "***** Homebrew install complete! *****"
    echo
    echo -e "***** Installing some additional tools . . . *****"
    brew_packages=(awscli bash-completion cairo gdk-pixbuf gist git jq libffi
                   libxml2 libxslt pango pigz pv python python3 shellcheck
                   terraform wget ykpers figlet toilet fortune moreutils shellcheck gpg)
    /opt/homebrew/brew update
    echo "Installing brew packages"
    for pkg in "${brew_packages[@]}"; do
        yes |/opt/homebrew/brew install "${pkg}"
    done
    source ~/.bash_profile
    echo
    echo
    echo
}


function confirm_shell() {
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
    echo
    echo 'Symlink homebrew/bin to /usr/local/bin'
    sudo ln -s /opt/homebrew/bin /usr/local/bin 
}


# configure SSH key
function do_config_ssh() {
    print_header "Configuring SSH"

    if [[ "$(ssh-keygen -lf "$HOME/.ssh/id_ed25519.pub" |cut -d' ' -f1 )" == "256" ]]; then
        echo "Excellent - you have a SHA256 ssh key created and installed"
    elif [[ "$(ssh-keygen -lf "$HOME/.ssh/id_ed25519.pub" |cut -d' ' -f1 )" == " No such file or directory" ]]; then
        echo "Hmm... You seem to be missing an ssh key. Follow these directions to generate one:"
        echo "https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent"
        exit
    else
        echo "Uh-oh. you have an existing ssh key, but it doesn't appear to be a SHA256 key."
        echo "Contact an adult for help in resolving this."
        exit
    fi
}


# basic git config
function do_configure_git() {
    print_header "Configuring git"

    git config --global user.name "${full_name}"
    git config --global user.email "${email_addy}"
    git config user.name && git config user.email
    git config --global fetch.prune true
    git config --global color.ui true
}

# confirm IT Repo is cloned to /src dir 
function confirm_repo() {
    print_header 'Confirming the IT repo has been cloned.' |pv -qL 10
    find /Users/"$local_user"/src/it-ops -mtime -1 -type d -print &> /dev/null
		if [ $? -eq 0 ]
		then
            sleep 5
            echo
            echo 'Confirmed IT repo has been cloned! Confirming proper access to github. . .' |pv -qL 10
            ssh -T git@github.com
            echo
        else
            echo '***** You need to clone the IT Repo to the /src dir before proceeding. See instructions here: https://doc.common.cloud.aurora.tech/doc/codelabs/GitHubAccountSetup.html ***** '
            exit
        fi    
}


# installs Google SDK 
function do_install_sdk_mac() {
    print_header "Installing SDK"
    #gcloud_url="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-402.0.0-darwin-arm.tar.gz"
    #(cd "${HOME}" && curl -O -L "$gcloud_url")
    echo
    #echo 'Unpacking gcloud cli download. . .'
    #tar -xf google-cloud-cli-402.0.0-darwin-arm.tar.gz
	#rm google-cloud-cli-402.0.0-darwin-arm.tar.gz 
    #sleep 5
    #echo 'running gcloud install script . . .'
    #bash "${HOME}"/google-cloud-sdk/install.sh
    #"${HOME}"/google-cloud-sdk/bin/gcloud init
    #"${HOME}"/google-cloud-sdk/bin/gcloud components update
    #"${HOME}"/google-cloud-sdk/bin/gcloud auth application-default login
    /opt/homebrew/bin/brew install --cask google-cloud-sdk
    /opt/homebrew/bin/gcloud init
    /opt/homebrew/bin/gcloud components update
    /opt/homebrew//bin/gcloud auth application-default login
    curl -s https://storage.googleapis.com/ai-encrypt/ascii_keyring | gpg --import
    echo
    echo
}


function check_pip3() {
    if [[ ! $(which pip3) ]]; then
        if [[ ! -e "get-pip.py" ]]; then
            curl "https://bootstrap.pypa.io/get-pip.py" -o get-pip.py
        fi
        sudo python3 get-pip.py
    fi

}

# pip3 install list of modules
function pip3_install() {
    check_pip3
    module_list="$*"
    # SC-NOTE: We want the array expansion below, so not quoting.
    # Disable 2068 - https://github.com/koalaman/shellcheck/wiki/SC2068
    #shellcheck disable=SC2068
    for module in ${module_list[@]}; do
        sudo pip3 install --quiet --upgrade "${module}"
    done
}


# install pip modules to system python
function do_sys_pip_modules() {
    print_header "Installing pip modules"
    pip3_modules=(pep8 flake8 boto3 passlib python-gnupg jinja2 weasyprint code128 cairocffi slacker pylint)
    pip3_install "${pip3_modules[*]}"
}

#GAM Related Consts
GAM_OS="$(uname -s)"
GAM_GLIBC_VER="2.27"
GAM_MACOS_VER="10.15.4"
GAM_DOWNLOAD_URL="https://github.com/jay0lee/GAM/releases/download"
GAM_LATEST_VERSION=$(curl https://github.com/GAM-team/GAM/releases/latest -s -L -I -o /dev/null -w '%{url_effective}' |cut -f2 -d'"' |rev |cut -f1 -d'/' |rev |tr -d v)
    
# install GAM
function do_install_gam() {
    print_header "Installing GAM ${GAM_LATEST_VERSION}" 
    echo    
    bash <(curl -s -S -L https://gam-shortn.appspot.com/gam-install)
    echo 
    echo "Cloning GAM wiki to /src dir" |pv -qL 10
    cd /Users/"${local_user}"/src 
    git clone https://github.com/GAM-team/GAM.wiki.git 
    echo "Congratulations, GAM ${GAM_LATEST_VERSION} has been installed"
    echo "Please get a copy of oauth2service.json and client_secrets.json"
    echo "from a team member and copy them to ~/bin/gam"
}

# Confirm .json & gam ability files setup 
confirm_json() {
    echo "Have you already copied your 2 .json files to your ~/bin/gam dir? (y/n)"
    read -r ynu
    echo
	if [ "$ynu" == y ]
	then
    echo "Be sure to run the following comands after ensuring that you"
    echo "have the appropiate Admin access to the project(s):"
    echo 
    echo "gpg client_secrets.json.gpg" 
    echo "gpg oauth2service.json.gpg"
    sleep 5 
    gam ${EMAIL_ADDY} check serviceaccount
    elif [ "$ynu" == n ]
    then 
    echo "You need to transfer your .json files to the ~/bin/gam dir upon finishing GAM setup."
    echo "See an adult for help!"
    sleep 5
    echo
    echo
    fi
}


# source and symlink files for ops-tools
function do_source_ops_bash() {
    print_header "Sourcing it-ops bash"

    ops_bash_path="Users/${local_user}/src/it-ops/bash/corp-profile.d"

    if [[ -d "${ops_bash_path}" ]]; then
        echo "Sourcing files from ${ops_bash_path} and linking to local .profile.d/"

        mkdir -p "${HOME}/.profile.d"
        pushd "${HOME}/.profile.d" >/dev/null 2>&1
            # SC-NOTE: We want the variable expansion below, so not quoting and disable 2046 - https://github.com/koalaman/shellcheck/wiki/SC2046
            #shellcheck disable=SC2046
            for file in ${ops_bash_path}/*.sh; do
                ln -fs "${file}" $(basename "${file}")
            done
        popd >/dev/null 2>&1
    else
        echo "Warning: Failed to locate ${ops_bash_path}.  Make sure you have ops-tools checked out and up to date."
        echo "If this is the first time through you can safely ignore this warning."
    fi
}



# add each option selected by the user to a to-do list
function handle_args() {
    while getopts "bwprkjgmos" OPTION; do
        case "${OPTION}" in
           h)
               usage
               exit 1
               ;;
           b)
               to_do_list+=('do_bash_profile')                      # opt b
               ;;
           d)  
                to_do_list+=('do_install_homebrew_pkgs_osx')         # opt w
               ;;
           p)
               to_do_list+=('do_sys_pip_modules')                   # opt p
               to_do_list+=('do_python_setup')
               ;;
           r)
               to_do_list+=('confirm_repo')                        # opt r
               ;;
           k)
               to_do_list+=('do_install_sdk_mac')                  # opt k
               ;;
           j)
               to_do_list+=('confirm_json')                        # opt j
               ;;
           g)
               to_do_list+=('do_configure_git')                     # opt g
               ;;
           
           
           m)
               to_do_list+=('do_install_gam')                       # opt m
               ;;
           o)
               to_do_list+=('do_source_ops_bash')                   # opt o
               ;;
           s)
               to_do_list+=('do_config_ssh')                        # opt s
               ;;
           ?)
               usage
               exit 2
               ;;
        esac
    done
}


# automatically run all functions for full workstation setup
function run_full_setup() {
    confirm
    do_name_stuff                             # Always need this
    do_bash_profile                           # opt b
    if [[ "${platform}" = "Darwin" ]]; then   # opt w
        do_install_homebrew_pkgs_osx
        confirm_shell                         # opt c
        do_config_ssh                         # opt s
        do_configure_git                      # opt g
        confirm_repo                          # opt r
        do_install_sdk_mac                    # opt k
        do_sys_pip_modules                    # opt p
        do_python_setup                       # opt p
        do_install_gam                        # opt m
        confirm_json                          # opt j
        do_source_ops_bash                    # opt o
    else
        echo "This script is for M1 MacBooks"
        exit
    fi
}


# display finish banner when bootstrap is done running
function show_finished() {
    echo  "Remember to 'source ~/.bash_profile' to load profile changes into your current session."
    sleep 5
    echo
    echo "IT macOS Bootstrap complete!"
    toilet ONE OF US! |pv -qL 50
    echo
    echo
    echo Now share some wisdom today:
    echo
    echo
    fortune
}


main() {

    check_which_platform
    check_hardware_version

    if [[ "$#" -gt 0 ]]; then

        # Do some of the things based on user cli flags
        to_do_list=('do_name_stuff')

        handle_args "$@"

        for task in "${to_do_list[@]}"; do
            echo "Starting task: ${task}"
            ${task}
        done

    else
        print_header "Full Workstation Setup"
        run_full_setup
    fi

    show_finished
}

main "$@"
