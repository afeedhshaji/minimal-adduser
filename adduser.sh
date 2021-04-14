#!/bin/bash
########################################################################################
# Add user and it's password manually to the /etc/passwd and /etc/shadow file without
# using `adduser` or `useradd` commands. Essentially a low-level implementation of the above
# mentioned commands
#########################################################################################

login_def="/etc/login.defs"
bash_shell="/bin/bash"
salt=$(
	tr -dc A-Za-z0-9 </dev/urandom | head -c 13
	echo ''
)

# Check dependancies
function checkDependancy() {
	if command -v openssl >/dev/null 2>&1; then
		echo "OpenSSL found"
		echo "version: $(openssl version)"
	else
		echo "OpenSSL not found"
	fi
}

# Check if the user is root
function isRoot() {
	if [ $(id -u) -ne 0 ]; then
		echo "Only root may add a user to the system."
		exit 2
	fi
}

# Check if username exists in the passwd file
function checkUserExists() {
	echo "hello"
	egrep "^$1" /etc/passwd >/dev/null
	if [ $? -eq 0 ]; then
		echo "$username already exists in the system!"
		exit 2
	fi
}

# Non-admin normal users can get UID and GID > 1000 and < 60,000
# Non-admin system generated users can get UID and GID between 1 and 999
# We start finding UID/GID from 1000 until we get a non-assigned UID/GID
function getFreeUidAndGid() {

	min_uid=$(grep -i 'UID_MIN' $login_def | head -1 | tr -s [:blank:] | cut -d" " -f2)
	min_gid=$(grep -i 'GID_MIN' $login_def | head -1 | tr -s [:blank:] | cut -d" " -f2)

	uids=$(getent passwd | awk -F: '$3 > '$min_uid' {print $3}')
	gids=$(getent passwd | awk -F: '$4 > '$min_gid' {print $4}')

	new_uid=$((min_uid + 1))
	new_gid=$((min_gid + 1))

	# loop unti next uid and gid are found
	while [[ true ]]; do
		u_find=$(echo $uids | grep -cE '\b'$new_uid'\b')
		g_find=$(echo $gids | grep -cE '\b'$new_gid'\b')

		if [[ $u_find == 0 ]] && [[ $g_find == 0 ]]; then
			break
		fi

		# check if the new_uid exists in the $uids variable
		if [[ $u_find > 0 ]]; then
			new_uid=$((new_uid + 1))
			continue
		fi

		# check if the new_uid exists in the $uids variable
		if [[ $g_find > 0 ]]; then
			new_gid=$((new_gid + 1))
			continue
		fi
	done
}

# Shadow style password hashing
function encryptPassword() {
	encrypted=$(openssl passwd -$1 -salt $3 $2)
}

# To get the configuration information of password to store in passwd file
function getMetaData() {
	max_days=$(grep -i 'PASS_MAX_DAYS' $login_def | tail -1 | tr [:blank:] " " | cut -d" " -f2)
	min_days=$(grep -i 'PASS_MIN_DAYS' $login_def | tail -1 | tr [:blank:] " " | cut -d" " -f2)
	warn_age=$(grep -i 'PASS_WARN_AGE' $login_def | tail -1 | tr [:blank:] " " | cut -d" " -f2)
}

# To create the home directory of the new user
function setupHomeDir() {
	home_dir="/home/$1"
	echo $home_dir

	if [[ -d "$home_dir" ]]; then
		echo "$home_dir exists on your filesystem."
		# rm -rf $home_dir
	else
		echo "Creating home directory : $home_dir"
		mkdir $home_dir
	fi

	# set the home directory permissions and ownership
}

function setPermission() {
	home_dir="/home/$1"

	chown -R $1:$1 $home_dir
	chmod -R 755 $home_dir
}

function addUser() {
	getMetaData

	home_dir="/home/$1"
	passwd=$1:x:$new_uid:$new_gid::$home_dir:$bash_shell
	group=$1:x:$new_gid
	shadow=$1:$encrypted:$(date +%s):$min_days:$max_days:$warn_age:::
	gshadow=$1:!::

	echo $passwd >>/etc/passwd
	echo $group >>/etc/group
	echo $shadow >>/etc/shadow
	echo $gshadow >>/etc/gshadow
}

########################################################################################
#
# Main Function
#
########################################################################################

checkDependancy

isRoot

read -p "Enter username : " username

read -p """1   : MD5
2a  : Blowfish (not in mainline glibc; added in some Linux distributions)
5   : SHA-256 (since glibc 2.7)
6   : SHA-512 (since glibc 2.7)
Hash Algorithm: """ hash_algo

read -s -p "Enter password : " password

echo ""

checkUserExists $username

getFreeUidAndGid

encryptPassword $hash_algo $password $salt

setupHomeDir $username

addUser $username

setPermission $username

[ $? -eq 0 ] && echo "User has been added to system!" || echo "Failed to add the user!"
