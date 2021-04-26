#!/bin/bash

####################################################################################
#
# Copyright (c) 2021, Jamf.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are met:
#          * Redistributions of source code must retain the above copyright
#            notice, this list of conditions and the following disclaimer.
#          * Redistributions in binary form must reproduce the above copyright
#            notice, this list of conditions and the following disclaimer in the
#            documentation and/or other materials provided with the distribution.
#          * Neither the name of Jamf nor the
#            names of its contributors may be used to endorse or promote products
#            derived from this software without specific prior written permission.
#  THIS SOFTWARE IS PROVIDED BY JAMF "AS IS" AND ANY
#  EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#  DISCLAIMED. IN NO EVENT SHALL JAMF BE LIABLE FOR ANY
#  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
####################################################################################
#
#  v3 - Full rewrite
#
# Script developed by Jamf Support to update the
#  mobile device app catalog of Jamf Pro to the version
#  reflected by the iTunes API
#
####################################################################################
#
# A .csv can be used with the column order of:
#  Jamf App ID,Adam ID,Jamf Version,Apple Version
#
# Only the first and fourth columns need to be populated
#
####################################################################################




file="/tmp/AppReport.csv" # Temporary file used to store and read the app versioning data
jurl="" # Jamf Pro URL in format of https://example.jamfcloud.com
user="" # Jamf Pro API user with permission to read and update mobile device apps
pass="" # Jamf Pro API user's password


# Read the versions in Jamf Pro and compare them to the iTunes API, recording mismatches and ignoring apps no longer in App Store
function collectversions() {

	# Prepare our work file
	if [[ -f "$file" ]]; then
		echo "$file already exists, moving it to $file.old"
		mv "$file" "$file".old
	fi

	touch "$file"

	# Collect a list of App IDs to process
	jamfidlist=$(curl -ksu $user:$pass ${jurl}/JSSResource/mobiledeviceapplications | xmllint --format - | awk -F'>|<' '/<id>/,/<\/id>/{print $3}' | sort -n )

	jamfidarray=()
	for id in $jamfidlist
	do
		jamfidarray+=($id)
	done

	# For each app found, record versions that do not match between Jamf and iTunes, but skip blank iTunes versions
	counter=${#jamfidarray[@]}
	echo "$counter apps found to sort"
	echo -e "Remain\tID\tJamf  Apple"
	while (( $counter > 0 )); do
		(( counter-- ))

		# Collect data from Jamf
		jamfappdata=$(curl -ksu $user:$pass ${jurl}/JSSResource/mobiledeviceapplications/id/${jamfidarray[$counter]})
		externalurl=$(echo "$jamfappdata" | xmllint --xpath '/mobile_device_application/general/external_url/text()' -)

		if [[ ! -z "$externalurl" ]] ; then
			versionjamf=$(echo "$jamfappdata" | xmllint --xpath '/mobile_device_application/general/version/text()' -)
			adamid=$(echo ${externalurl} | tr '/' ' ' | awk '{print $6}' | tr '?' ' ' | awk '{print $1}' | cut -c3-)

			# Collect data from Apple
			appinfo=$(curl -s http://ax.itunes.apple.com/WebObjects/MZStoreServices.woa/wa/wsLookup?id=$adamid)
			versionapple=$(echo "$appinfo" | sed -n 's/^.*\"version\"://p' | tr -d \", | awk '{print $1}')
			echo -e "$counter\t${jamfidarray[$counter]}\t$versionjamf  $versionapple"

			if [[ "$versionjamf" != "$versionapple" && "$versionapple" != "" ]]; then
				echo "${jamfidarray[$counter]},$adamid,$versionjamf,$versionapple" >> $file
			fi
		fi
	done
}

function updateversions() {

	# Read our working file
	updatelist=$(cat $file)
	
	if [[ -z "$updatelist" ]]; then
		echo "No apps found to update"
	fi

	for i in $updatelist
	do
		appid=$(echo ${i} | awk -F',' '{print $1}')
		version=$(echo ${i} | awk -F',' '{print $4}')
		echo "Updating app ID $appid to $version"
		curl -ksu $user:$pass -H "content-type: text/xml" ${jurl}/JSSResource/mobiledeviceapplications/id/$appid -X PUT -d "<mobile_device_application><general><version>$version</version></general></mobile_device_application>"
		echo ""
	done
	echo "- - Complete - -"
}

function jpcredentialsprompt() {
	if [[ -z "$jurl" ]] ; then
		read -p "Jamf Pro URL: " jurl
		read -p "Jamf Pro Username: " user
		read -s -p "Jamf Pro Password: " pass
		echo ""
		collectversions
	else
		echo "Jamf Pro credentials found, check app versions? [Y/n]"
		read -p "> " continue
		case $continue in
		yes | Yes | YES | y | Y)
		collectversions
		;;
		*)
		exit
		;;
	esac
	fi
}

function updateprompt() {
	echo "It is recommended to make a database backup before proceeding."
	echo "Update app catalog to versions in $file? [Y/n]"
	read -p "> " apicompareprompt
	case $apicompareprompt in
		yes | Yes | YES | y | Y)
		updateversions
		;;
		*)
		exit
		;;
	esac
}

# Begin
echo "Jamf App Catalog Comparing Utility"
echo "[1] Generate a new app catalog CSV with Jamf Pro API"
echo "[2] Use an existing CSV"
echo "[3] Exit"
read -p "> " mode

case $mode in
	a | A | 1)
	jpcredentialsprompt
	updateprompt
	;;
	b | B | 2)
	read -p "Path to csv file: " file
	updateprompt
	;;
	c | C | 3 | exit)
	exit
	;;
esac