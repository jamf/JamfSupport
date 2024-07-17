#!/bin/bash

#########################################################################################
#																						#
#           Jamf Pro Server Summary Tool 3.2											#
#                   2018 - JSS 10.0.0													#
#            By Sam Fortuna & Nick Anderson												#
#																						#
# 	  Update : Tyrone Luedtke - Mar 16, 2022											#
# 	Removed python and replaced with shell arithmetic									#
#  																						#
#	Jamf Pro Server Summary Tool														#
#  	  Update : 20230211-21	Changed the display output mainly using printf 				#
#  																						#
#	20238080 : Minor tweaks and name change to, SummaryPaserX.sh						#
#  																						#
#	20231011 : Added check if any policies or EA's have a 'jamf recon in them. 			#
#  																						#
#	20231023 : Summary now shows the policy ID and name containing the 'jamf recon'.	#
#			Summary now will run through if there is no database information,			#
#			there will now be a message 'No database information found to report on.	#
#																						#
#	20231215 : Changed how we dispaly whether the 'jamf recon' in a Policy is			#
#			enabled via self service or its onging.										#
#																						#
#	20240202 : Added "Push certificate subject" name									#
#																						#
#	20240218 : Changed collection of smart group criteria, "nested" is highlighted		#
#			red and displayed if over 5 and criteria number is highlighted as red.		#
#																						#
#	20240305 : Made some improvements to the smart group criteria and nested collection #
#																						#
#	20240508 : Check to see if the Activation code has expired and added 				#
#			percentages to the database table sizes,									#
#																						#
#########################################################################################

# Clear the screen, ready for output.   Push certificate subject
clear
version="4.4"
# Colours used by printf.
blu="\e[1m\e[34m"	# Blue
grn="\e[1m\e[32m"	# Green
red="\e[1m\e[91m"	# Red
cyn="\e[1m\e[96m"	# Cyan
off="\e[m"			# Set escape off
bld="\e[1m" 		# Bold

# Usage SummaryPaserX.sh <jamf-pro-summary.txt>
file="$1"

# Demand a valid summary
function new_summary {
	read -p "Summary Location: " file
}

while [[ "${file}" == "" ]] ; do
	new_summary
done

# Check if we have a full summary including database info.
table_sizes=$(awk '/^Table sizes/{print NR}' "${file}")
if [[ -z $table_sizes ]] ; then
	no_database=0
	else
	database_size_info=$(sed -n "$table_sizes,$ p" "${file}")
	no_database=1
fi

# Get remaining days function of certificate date calculations.
function days_remaining () {
	local date=${1}
	file_date_seconds=$(date -jf "%Y/%m/%d %H:%M" "${date} 00:00" +"%s")
	current_date_seconds=$(date +"%s")
	days_difference=$(( (file_date_seconds - current_date_seconds) / 86400 ))
	echo ${days_difference}
}

# Create server_info by sed'n between line 1 and "Activation Code"
summary_start=$(grep -n -m 1  "Jamf Pro Summary" "${file}" | awk -F : '{print $1}')
activation_code=$(grep -nx "Activation Code" "${file}" | awk -F : '{print $1}')
activation_code=$((activation_code + 10))
instance_information=$(sed -n -e "${summary_start},${activation_code} p" "${file}")

# Get summary create date, Built-in CA expiration date and Activation Code expriy date into an array.
jss_dates=($(echo "${instance_information}" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}'))
# Element 0 summary create date, 1 Built-in CA expiration date, 2 Activation Code expriy date

# Get count of managed computers
managed_computers=$(echo "${instance_information}" | awk '/Managed Computers/ { gsub(/[^0-9]/,"",$NF); print $NF; exit }')
managed_computers=${managed_computers:=0}

# Get count of unmanaged computers
unmanaged_computers=$(echo "${instance_information}" | awk '/Unmanaged Computers/ { gsub(/[^0-9]/,"",$NF); print $NF; exit }')
unmanaged_computers=${unmanaged_computers:=0}

# Get count of managed iOS decives
managed_devices=$(echo "${instance_information}" | awk '/Managed iOS Devices/ { gsub(/[^0-9]/,"",$NF); print $NF; exit }')
managed_devices=${managed_devices:=0}

# Get count of unmanaged iOS decives
unmanaged_devices=$(echo "${instance_information}" | awk '/Unmanaged iOS Devices/ { gsub(/[^0-9]/,"",$NF); print $NF; exit }')
unmanaged_devices=${unmanaged_devices:=0}

# Get a count of Apple TV's
apple_tv_102=$(echo "${instance_information}" | awk '/tvOS 10.2 or later/ { gsub(/[^0-9]/,"",$NF); print $NF; exit }')
apple_tv_102=${apple_tv_102:=0}
apple_tv_101=$(echo "${instance_information}" | awk '/tvOS 10.1 or earlier/ { gsub(/[^0-9]/,"",$NF); print $NF; exit }')
apple_tv_101=${apple_tv_101:=0}

# Get a count of Apple TV's
apple_tv_102=$(echo "${instance_information}" | awk '/tvOS 10.2 or later/ {print $NF}')
apple_tv_102=${apple_tv_102:=0}
apple_tv_101=$(echo "${instance_information}" | awk '/tvOS 10.1 or earlier/ {print $NF}')
apple_tv_101=${apple_tv_101:=0}

# Get Details of the server running Jamf Pro Server
server_OS=$(echo "${instance_information}" | sed -n 's/Operating System[ \t]*\(.*\)/\1/p')
jps_version=$(echo "${instance_information}" | awk '/Installed Version/ {print $NF}' | cut -d '-' -f1)
jps_hosted=$(echo "${instance_information}" | awk '/Hosted/ {print $NF}')
java_version=$(echo "${instance_information}" | awk '/Java Version/ {print $NF}')
compiled_os=$(echo "${instance_information}" | awk '/version_compile_os/ {print $NF}')
mysql_version=$(echo "$instance_information" | grep -n -m 1 "version" | awk  '{print $NF}')
mysql_driver=$(echo "${instance_information}" | awk '/Database Driver/ {print $NF}')
mysql_server=$(echo "${instance_information}" | awk '/Database Server/ {print $NF}')
database_name=$(echo "${instance_information}" | awk '/Database Name/ {print $NF}')
database_size=$(echo "$instance_information" | grep "Database Size" | awk 'NR==1 {print $(NF-1),$NF}')
max_pool_size=$(echo "$instance_information" | awk '/Maximum Pool Size/ {print $NF}')
max_mysql_conns=$(echo "${instance_information}" | awk '/max_connections/ {print $NF}')
bin_logging=$(echo "${instance_information}" | awk '/log_bin/ {print $NF}')
innodb_tables=$(echo "${instance_information}" | awk '/InnoDB Tables/ {print $NF}')
myisam_tables=$(echo "${instance_information}" | awk '/MyISAM Tables/ {print $NF}')
tomcat_version=$(echo "${instance_information}" | awk -F '[\.]+[\.]' '/Tomcat Version/ {print $NF; exit}')
webapp_installed=$(echo "${instance_information}" | awk '/Web App Installed To/ {print $NF}')
activation_code=$(echo "${instance_information}" | awk '/Activation Code/ {for(i=NF;i>=3;i--) if($i!=""){print $i; break}}')
institution_name=$(echo "${instance_information}" | awk '/Institution Name /{for (i=4; i<=NF; i++) printf $i " "; printf "\n"}')
jps_url=$(grep "HTTPS URL" "${file}" | awk '{print $3}')
flush_logs_time=$(awk -F "     " '/Time to Flush Logs Each Day/ {print $NF}' "$file")
if [ -z "$flush_logs_time" ]; then
	flush_logs_time="No data collected"
fi
checkin_freq=$(awk '/Check-in Frequency/ {print $NF}' "${file}")
cloud_distribution_point=$(grep -nx "Cloud Distribution Point" "${file}" | awk -F : '{print $1}')
if [ -z $cloud_distribution_point ]; then
	cloud_distribution_point="No data collected"
else
	line_number=$((cloud_distribution_point + 2))
	cloud_distribution_point=$(sed -n "${line_number}s/^[[:space:]]*Type[[:space:]]*//p" "$file")
fi

width=28 # Printf display width
# Display output from gathered variables.
printf "${grn}*** SummaryPaserX ${version} ***${off}\n"
printf "${bld}%-${width}s : ${blu}%s${off}\n" "Date summary created" " ${jss_dates[0]}"
printf "${bld}%-${width}s : %s\n" "Activation Code" " ${activation_code}"

# Check to see if Activation Code has expired
if [[ "${jss_dates[2]}" < $(date +%Y-%m-%d) ]]; then
	printf "${bnk}${bld}%-${width}s : ${red}%s${off}\n" "The Activation Code expired" " ${jss_dates[2]}"
else
	printf "${bld}%-${width}s : ${grn}%s${off}\n" "Activation Code expires" " ${jss_dates[2]}"
fi

printf "${bld}%-${width}s : %s\n" "Institution Name" " ${institution_name}"
printf "${bld}%-${width}s : %s\n" "Built-in CA expiration date" " ${jss_dates[1]}"
printf "${bld}%-${width}s : %s\n" "Server OS" "${server_OS}"
printf "${bld}%-${width}s : \t%s\n" "JPS version" "${jps_version}"
printf "${bld}%-${width}s : \t%s\n" "JPS URL" "${jps_url}"
printf "${bld}%-${width}s : \t%s\n" "Jamf Hosted" "${jps_hosted}"

# If no managed computers, then don't display the output.
if (( managed_computers  > 0 )) ; then
	printf "${bld}%-${width}s : \t%s\n" "Managed computers" "${managed_computers}"
fi

# If no unmanaged computers, then don't display the output, if unmanaged is over 100 then set display to red.
if (( unmanaged_computers > 0 )) ; then
	if (( unmanaged_computers > 99 )) ; then
		printf "${bld}%-${width}s : \t${red}%s${off}\n" "Unmanaged Computers" "${unmanaged_computers}"
	else
		printf "${bld}%-${width}s : \t%s\n" "Unmanaged Computers" "${unmanaged_computers}"
	fi
fi


if (( managed_devices  > 0 )) ; then
	printf "${bld}%-${width}s : \t%s\n" "Managed iOS devices" "${managed_devices}"
fi

# If no unmanaged IOS devices, then don't display the output, if unmanaged is over 100 then set display to red.
if (( unmanaged_devices > 0 )) ; then
	if (( unmanaged_devices > 99 )) ;then
		printf "${bld}%-${width}s : \t${red}%s${off}\n" "Unmanaged iOS devices" "${unmanaged_devices}"
	else
		printf "${bld}%-${width}s : \t%s\n" "Unmanaged iOS devices" "${unmanaged_devices}"
	fi
fi

# If Jamf Pro server is hosted, then there is no need to display the next three values.
if [[ "${jps_hosted}" == "false" ]] ; then
	printf "${bld}%-${width}s : \t%s\n" "Java version" "${java_version}"
	printf "${bld}%-${width}s : \t%s %s\n" "MySQL version" "$mysql_version" "$compiled_os"
	printf "${bld}%-${width}s : \t%s\n" "MySQL driver" "${mysql_driver}"
fi

printf "${bld}%-${width}s : \t%s\n" "MySQL server" "${mysql_server}"
printf "${bld}%-${width}s : \t%s\n" "Database name" "${database_name}"
printf "${bld}%-${width}s : \t%s\n" "Max pool size" "${max_pool_size}"
printf "${bld}%-${width}s : \t%s\n" "Maximum MySQL Connections" "${max_mysql_conns}"

# Check for bin_logging
if [[ "${jps_hosted}" == "false" ]] ; then
	if [ "${bin_logging}" = "ON" ] ; then
		printf "${bld}%-${width}s : ${red}\t%s\n${off}" "Bin Logging" "${bin_logging}"
	fi
fi

printf "${bld}%-${width}s : \t%s\n" "MyISAM Tables" "${myisam_tables}"
printf "${bld}%-${width}s : \t%s\n" "InnoDB Tables" "${innodb_tables}"
printf "${bld}%-${width}s : \t%s\n" "Check-In Frequency" "${checkin_freq}"
printf "${bld}%-${width}s : \t%s\n" "Log flushing time" "${flush_logs_time}"
printf "${bld}%-${width}s : \t%s\n" "Cloud Distribution Point" "${cloud_distribution_point}"

# Are we collecting font information ?
if [[ "${fonts_enabled}" == "true" ]] ; then
	printf "${bld}%-${width}s : ${red}\t%s\n${off}" "Fonts data collection" "${fonts_enabled} [!]"
fi

# Get and sort database tables over 1GB, if we have the database tables.
if [[ "$no_database" != 0 ]] ; then
	table_sizes=$(awk '/^Table sizes/{print NR}' "${file}")
	database_size_info=$(sed -n "$table_sizes,$ p" "${file}")
	printf "\n"
	printf "${bld}%-${width}s : \t%s\n" "Database size" "${database_size}"
	printf "\n"
	
	# Extract the total database size in GB from the variable 'database_size'
	total_size=$(echo "${database_size}" | awk '{print $1}')
	
	# Extract and sort large tables' sizes
	large_tables=$(echo "${database_size_info}" | awk '$NF == "GB" {print $1 " " $(NF-1)}' | sort -k2 -nr )
	
	if [ "$large_tables" != "" ] ; then
		printf "${blu}Tables over 1 GB in size${off}\n" 
		# Print the names, sizes, and percentages of the tables over 1GB
		while read -r name size ; do
			percentage=$(echo "scale=2; (${size} / ${total_size}) * 100" | bc)
			printf "${bld}Name: %-34s Size: %s GB (%.2f%%)\n" "${name}" "${size}" "${percentage}"
		done <<< "${large_tables}"
	else
		printf "${bld}Tables over 1 GB in size none found.\n"
	fi
else
	printf "\n${red}No database information found to report on.\n${off}"
fi


# Create jps_server_info by sed'n between "LDAP Servers" and "User Groups"
jps_server_info=$(sed -n -e '/LDAP Servers/,/User Groups/ p' "${file}")
http_connector=$(echo "${jps_server_info}" | awk '/HTTP Connector/ {print $NF}')
https_connector=$(echo "${jps_server_info}" | awk '/HTTPS Connector/ {print $NF}')
remote_ip_value=$(echo "${jps_server_info}" | awk '/Remote IP Valve/ {print $NF}')
proxy_port=$(echo "${jps_server_info}" | awk '/Proxy Port/ {print $NF}')
proxy_scheme=$(echo "${jps_server_info}" | awk '/Proxy Scheme/ {print $NF}')
proxy_port_check=$(echo "${jps_server_info}" | awk '/Proxy Port/ {print $NF}')
cluster_enabled=$(echo "${jps_server_info}" | awk '/Clustering Enabled/ {print $NF}')

# Create computer_inventory by sed'n between "Computer Inventory Collection" and "Computer Extension Attributes"
computer_inventory=$(sed -n -e '/Cloud Distribution Point/,/Computer Extension Attributes/ p' "${file}")
push_notifications=$(echo "${computer_inventory}" | awk '/Push Notifications Enabled/ {print $NF}')
fonts_enabled=$(echo "${computer_inventory}" | awk '/Fonts/ {print $NF}')

# Get count of Computer Smart Groups
smart_computers_groups_info=$(sed -n -e '/Smart Computer Groups/,/Computer PreStage Enrollments/ p' "${file}")
smart_computer_group_count1=$(echo "${smart_computers_groups_info}" | awk '/Smart Group/ {print $NF}' | wc -l)

# Get count of iOS Smart Groups
smart_iOS_groups_info=$(sed -n -e '/Smart Mobile Device Groups/,/Enrollment Profiles/ p' "${file}")
smart_iOS_group_count=$(echo "${smart_iOS_groups_info}" | awk '/Smart Group/ {print $NF}' | wc -l)

# Get count of Computer Profiles
osx_profile_info=$(sed -n -e '/OS X Configuration Profiles/,/Restricted Software/ p' "${file}")
osx_profile_count=$(echo "${osx_profile_info}" | awk '/ID/ {print $NF}' | wc -l)

# Get count of iOS Profiles
iOS_profile_info=$(sed -n -e '/Mobile Device Configuration Profiles/,/Provisioning Profiles/ p' "${file}")
iOS_profile_count=$(echo "${iOS_profile_info}" | awk '/ID/ {print $NF}' | wc -l)


printf "\n"
if [[ "${jps_hosted}" == "false" || "${jps_hosted}" == "true" ]] ; then
	printf "${bld}%-${width}s : \t%s\n" "Tomcat version" "${tomcat_version}"
	printf "${bld}%-${width}s : \t%s\n" "Webapp location" "${webapp_installed}"
	if [[ $(echo "${jps_server_info}" | awk '/Apache Tomcat Settings/') ]];then
		ssl_date=$(echo "${jps_server_info}" | awk '/SSL Cert Expires/ {'print' $NF}')
		ssl_subject=$(echo "${jps_server_info}" | sed -n 's/SSL Cert Subject *//p')
		
		if [[ "${ssl_date}" != "Expires" ]] ; then
			
			days_remaining=$(days_remaining "${ssl_date}")
			
			# If SSL is expiring in under 60 days, output remaining days in red instead of green
			if (( days_remaining > 60 )) ; then
				colour="${grn}"	# Green
			else
				colour="${red}"	# Red
			fi
			printf "${bld}%${width}s : \tExpire date %s, days remaining ${colour}%s\n${off}" "SSL Certificate Expiration" "${ssl_date}" "${days_remaining}"
		else
			printf "${bld}%-${width}s : \tNo data supplied!\n" "SSL Certificate data"
fi
	fi
fi

# Are we clustered ?
	if [[ "${jps_hosted}" == "false" ]] ; then
		if [[ "${cluster_enabled}" == "true" ]] ; then
			printf "${bld}%-${width}s : \t%s\n" "Clustering Enabled" "${cluster_enabled} [!]"
		else
			printf "${bld}%-${width}s : \t%s\n" "Clustering Enabled" "${cluster_enabled}"
		fi
	fi

	# If no managed ATV2 devices, then don't display the output.
	if (( apple_tv_102 > 0 )) ; then
		printf "${bld}%-${width}s : \t%s\n" "Apple TVs 10.2 or later" "${apple_tv_102}"
	fi

	# If no managed ATV1 devices, then don't display the output.
	if (( apple_tv_101 > 0 )) ; then
		printf "${bld}%-${width}s : \t%s\n" "Apple TVs 10.1 or later" "${apple_tv_101}"
	fi

	# Get Push Certificate token expiration information.
	if [[ $(echo "${jps_server_info}" | awk '/Push Certificates/') ]] ; then
	cert_info=$(sed -n "/Push Certificates/,/PKI Certificates/ p" "${file}")
	apns_date=$(echo "${cert_info}" | awk '/Expires/ {print $NF; exit}')
	
	days_remaining=$(days_remaining ${apns_date})
	
	push_cert_subject=$(echo "${jps_server_info}" | awk '/Push Certificates/,/Port/{if($1=="Subject") print $3}')
	printf "${bld}%-${width}s : \t%s\n" "Push certificate subject" "${push_cert_subject}"

	# If push token is expiring in under 60 days, output remaining days in red instead of green
	if  (( days_remaining > 60 )) ; then
		colour="${grn}"	# Green
	else
		colour="${red}"	# Red
	fi
	printf "${bld}%-${width}s : \tExpire date %s, days remaining ${colour}%s${off}\n" "Push cert expiration date" "${apns_date}" "${days_remaining}"

	if [[ "$push_notifications" == "true" ]] ; then
		printf "${bld}%-${width}s : \t%s\n" "Push Notifications enabled" "$push_notifications"
	else
		printf "${bld}%-${width}s : \t%s\n" "Push Notifications enabled" "$push_notifications [!]"
	fi
	else
		printf "${bld}%-${width}s : \tNo supplied data\n" "Push Certificate data"
	fi

	# Get VPP token expiration information.
	vpp_date=$(echo "${jps_server_info}" | awk '/Expiration Date/ {print $NF}')
	if [[ -n $vpp_date ]] ; then
		for vpp_anitem in $vpp_date; do
			
			days_remaining=$(days_remaining ${vpp_anitem})

			# If vpp token is expiring in under 60 days, output remaining days in red instead of green
			if (( days_remaining > 60 )) ; then
				colour="${grn}"	# Green
			else
				colour="${red}"	# Red
			fi
			printf "${bld}%-${width}s : \tExpire date %s, days remaining ${colour}%s${off}\n" "VPP Token Expiration" "${vpp_anitem}" "${days_remaining}"
		done
	fi

# Find problematic policies that are ongoing, enabled, update inventory and have a scope defined
# Create policy_info by sed'n between "Policies" and "OS X Configuration Profiles"
policies_start=$(grep -n -m 1 "Policies" "${file}" | awk -F : '{print $1}')
osx_configuration_profiles_end=$(grep -n -m 1 "OS X Configuration Profiles" "${file}" | awk -F : '{print $1}')
policy_info=$(sed -n "${policies_start},${osx_configuration_profiles_end} p" "${file}" 2>/dev/null)

policy_info_status=$?

# Check the exit status and act accordingly
if [ $policy_info_status -ne 0 ]; then
	printf "\n${bld}${red}Jamf Pro summary incomplete, information will not be accurate, so exiting! \n${off}"
	exit $?
fi

# Find problematic policies that are ongoing, enabled, update inventory and have a scope defined
scratch_file=$(mktemp /tmp/policy_temp.XXX) && echo "$policy_info" > $scratch_file
numbers=$(echo "$policy_info" | grep -no "ID                                           " | awk -F : '{print $1}')
printf "${bld}\n\n${grn}The following policies are Ongoing, Enabled and update inventory:\n${off}"
printf -- '-%.0s' {1..80}
onging_counter=0
for anitem in $numbers ; do
	ss=$(sed -n "${anitem},/Install Button Text/ p" "$scratch_file")
	policy_enabled=$(echo "$ss" | grep Enable -m1 | awk '/true/ {'print' $NF}')
	policy_trigger=$(echo "$ss" | grep Triggered | awk '/true/ {'print' $NF}')
	execution_frequency=$(echo "$ss" | grep 'Execution Frequency'| awk '/Ongoing/ {'print' $NF}')	
	update_inventory=$(echo "$ss" | awk '/Update Inventory/ {'print' $NF; exit}')
	if [[ "$policy_trigger" == *"true"* && "$update_inventory" == "true" && "$policy_enabled" == "true" && "$execution_frequency" == "Ongoing" ]]; then
		policy_name=$(echo "$ss" | awk -F '[\.]+[\.]' '/Name/ {'print' $NF; exit}')
		policy_scope=$(echo "$ss" |  awk -F '[\.]+[\.]' '/Scope/ {print $NF; exit}')
		policy_id=$(echo "$ss" | grep -oE 'ID\s+([0-9]+)' | awk 'NR==1 {print $2; exit}')
		printf "\n${grn}%s${off} |${bld}%s |${blu}%s${off} \n" "$policy_id" "$policy_name" "$policy_scope"
		printf -- '-%.0s' {1..80}
		((onging_counter++))
	fi
done
printf "${bld}\n${grn}Number of policies${blu} [ %s ]${off}${grn} that are Ongoing, Enabled and update inventory daily.\n${off}" "$onging_counter" 

# Find policies that are Ongoing at recurring check-in, but do not update inventory and have a scope defined.
scratch_file=$(mktemp /tmp/policy_temp.XXX) && echo "$policy_info" > $scratch_file
numbers=$(echo "$policy_info" | grep -no "ID                                           " | awk -F : '{print $1}')
printf "${bld}\n${grn}Ongoing at recurring check-in, but do not update inventory:\n${off}"
printf -- '-%.0s' {1..80}
recurring_counter=0
for anitem in $numbers ; do
	ss=$(sed -n "${anitem},/Install Button Text/ p" "$scratch_file")
	policy_enabled=$(echo "$ss" | grep Enable -m1 | awk '/true/ {'print' $NF}')
	policy_trigger=$(echo "$ss" | grep Triggered | awk '/true/ {'print' $NF}')
	execution_frequency=$(echo "$ss" | grep 'Execution Frequency'| awk '/Ongoing/ {'print' $NF}')
	update_inventory=$(echo "$ss" | grep 'Update Inventory' | awk '/true/ {'print' $NF}')
	if [[ "$policy_enabled" == "true" && "$policy_trigger" == *"true"* && "$execution_frequency" == "Ongoing" && "$update_inventory" != "true" ]]; then
		policy_id=$(echo "$ss" | grep -oE 'ID\s+([0-9]+)' | awk 'NR==1 {print $2; exit}')
		policy_name=$(echo "$ss" | awk -F '[\.]+[\.]' '/Name/ {'print' $NF; exit}')
		policy_scope=$(echo "$ss" |  awk -F '[\.]+[\.]' '/Scope/ {print $NF; exit}')
		printf "\n${grn}%s${off} |${bld}%s |${blu}%s${off} \n" "$policy_id" "$policy_name" "$policy_scope"
		printf -- '-%.0s' {1..80}
		((recurring_counter++))
	fi
done
printf "${bld}\n${grn}Number of policies${blu} [ %s ] ${off}${grn}Ongoing at recurring check-in, but do not update inventory.\n${off}" "${recurring_counter}"


# Count number of policies that update inventory once per day
scratch_file=$(mktemp /tmp/policy_temp.XXX) && echo "$policy_info" > $scratch_file
numbers=$(echo "$policy_info" | grep -no "ID   " | awk -F : '{print $1}')
printf "${bld}\n\n${grn}Policies with an 'Execution Frequency' of 'Once every day' and update inventory:\n${off}"
printf -- '-%.0s' {1..80}
frequency_daily_counter=0
for anitem in $numbers ; do
	ss=$(sed -n "${anitem},/Install Button Text/ p" "$scratch_file")
	policy_enabled=$(echo "$ss" | grep Enable -m1 | awk '/true/ {'print' $NF}')
	
	policy_trigger=$(echo "$ss" | grep Triggered | awk '/true/ {'print' $NF}')
	execution_frequency=$(echo "$ss" | grep 'Execution Frequency'| awk '/Once every day/ {'print' $NF}')
	update_inventory=$(echo "$ss" | grep 'Update Inventory' | awk '/true/ {'print' $NF}')
	
	if [[ "$policy_enabled" == "true" && "$policy_trigger" == *"true"* && "$execution_frequency" == *"day"* && "$update_inventory" == "true" ]]; then
		policy_id=$(echo "$ss" | grep -oE 'ID\s+([0-9]+)' | awk 'NR==1 {print $2; exit}')
		policy_name=$(echo "$ss" | awk -F '[\.]+[\.]' '/Name/ {'print' $NF; exit}')
		policy_scope=$(echo "$ss" |  awk -F '[\.]+[\.]' '/Scope/ {print $NF; exit}')
		printf "\n${grn}%s${off} |${bld}%s |${blu}%s${off} \n" "$policy_id" "$policy_name" "$policy_scope"
		printf -- '-%.0s' {1..80}
		((frequency_daily_counter++))
	fi
done
printf "\n"
printf "${grn}Number of policies${blu} [ %s ]${off} ${grn}with an 'Execution Frequency' of 'Once every day' and update inventory.\n\n\n${off}" ${frequency_daily_counter}

# Check to see if we have any policies that may have a 'jamf recon' in them and display ID and name.
	recon_list=$(echo "$policy_info" |  grep -n 'Run Command.*jamf recon' | awk -F : '{'print' $1}' | sort -n)
	first_number_recon_list=$(echo "$recon_list" | head -n1)
	policy_recon_count=$(echo "$policy_info" | awk -F: '/jamf recon/{print $1}' | wc -l)
	
		if (( policy_recon_count > 0 )) ; then
		printf "${grn}Policies that contain 'jamf recon' that are enabled and ongoing:\n${off}"
		printf -- '-%.0s' {1..80}
		jamf_recon_counter=0
		for end_recon_line in $recon_list ; do
			start_recon_line=$(($end_recon_line - 72))
			if [ $(($end_recon_line - 72)) -lt 0 ]; then
				start_recon_line=$((${end_recon_line} - ${irst_number_recon_list} + 1))
			fi
			policy_enabled=$(echo "${policy_info}" | sed -n "${start_recon_line},${end_recon_line} p" | grep 'Enabled .' | awk '/true/ {'print' $NF}')
			policy_ongoing=$(echo "${policy_info}" | sed -n "${start_recon_line},${end_recon_line} p" | awk '/Execution Frequency/ {'print' $NF}')
		
		if [[ "$policy_enabled" == "true" && "${policy_ongoing}" == "Ongoing" ]]; then
			policy_id=$(echo "${policy_info}" | sed -n "${start_recon_line},${end_recon_line} p" | grep -oE 'ID\s+([0-9]+)' | awk 'NR==1 {print $2; exit}')
			policy_name=$(echo "${policy_info}" | sed -n "${start_recon_line},${end_recon_line} p" | awk -F '[\.]+[\.]' '/Name/ {'print' $NF; exit}')
			policy_scope=$(echo "${policy_info}" | sed -n "${start_recon_line},${end_recon_line} p" | awk -F '[\.]+[\.]' '/Scope/ {print $NF; exit}')
			
			# Is the 'jamf recon' attached to a self service or is it 'Onging' as its 'Ongoing'.
			self_service_enabled=$(echo "${policy_info}" | sed -n "${start_recon_line},${end_recon_line} p" | awk '/Use For Self Service/ {'print' $NF}')
			if [[ "$self_service_enabled" == "true" ]]; then
				self_service_enabled="Self Service"
			else
				self_service_enabled="Ongoing"
			fi
			
			printf "\n${grn}%s${off} |${bld}%s |${blu}%s${off} | ${grn}%s${off} |\n" "$policy_id" "$policy_name" "$policy_scope" "${self_service_enabled}"
			
			printf -- '-%.0s' {1..80}
			((jamf_recon_counter++))
		fi
		done
			printf "\n"
			printf "${grn}Number of policies${blu} [ %s ]${off} ${grn}that contain 'jamf recon' that are Self Service enabled or ongoing.${off}\n" ${jamf_recon_counter}
		fi

# How many Extension Attributes are 'enabled' and 'disabled'
		extension_attributes_start=$(grep -n -m 1 "Computer Extension Attributes" "${file}" | awk -F : '{print $1}')
		self_service_end=$(( $(grep -n -m 1 "Self Service Bookmarks" "${file}" | awk -F : '{print $1}') - 20 ))
		extension_attributes=$(sed -n "${extension_attributes_start},${self_service_end} p" "${file}")
		total_extension_attributes=$(echo "${extension_attributes}" | grep -E "Enabled\s+(true|false)" | wc -l)
		true_extension_attributes=$(echo "${extension_attributes}" | grep -E "Enabled\s+true" | wc -l)
		false_extension_attributes=$(echo "${extension_attributes}" | grep -E "Enabled\s+false" | wc -l)
		
# Check to see if we have any Computer Extension Attributes that may have a 'jamf recon' in them.
		extension_recon_count=$(echo "${extension_attributes}" | awk -F: '/jamf recon/{print $1}' | wc -l)
		if (( extension_recon_count > 0 )) ; then
			printf "\n"
			printf "${grn}There maybe ${blu}%s${off} ${grn}Computer Extension Attributes that may have 'jamf recon' in them.${off}" ${extension_recon_count}
			printf "\n"
		fi

	printf "\n\n${grn}There are${blu} %s ${grn}Extension Attributes ${blu}%s ${grn}are enabled and ${blu}%s ${grn}are disabled.${off}" $total_extension_attributes $true_extension_attributes $false_extension_attributes
	printf "\n\n"

		# How many computer profiles and how many iOS profiles there are.
	printf "${grn}There are ${blu}%s${off} ${grn}OS X Configuration Profiles,${blu} %s ${grn}Mobile Device Configuration Profiles" ${osx_profile_count} ${iOS_profile_count}

	printf "\n\n"

# How many computer smart groups and how many iOS smart groups are there.
	printf "${grn}There are${blu} %s ${grn}Smart Computer Groups,${blu} %s ${grn}Smart Mobile Device Groups${off}\n\n" $smart_computer_group_count1 $smart_iOS_group_count
	
# List smart group names that include 1 or more criteria and that have nests.
	printf "\n${bld}${grn}List smart groups that include 4 or more criteria and have nests.${off}\n"
	printf -- '-%.0s' {1..80}
	printf "\n"

criteria_ids=()
nested_ids=()

numbers=$(echo "$smart_computers_groups_info" | grep -no "ID  " | awk -F : '{print $1}')
for anitem in $numbers; do
	smart_group_info=$(sed -n "${anitem},/Dependency Count/ p" <<< "$smart_computers_groups_info")
	smart_group_criteria_counter=$(echo "${smart_group_info}" | grep -E " - and - | - or - " | wc -l)
	smart_group_nested_counter=$(echo "${smart_group_info}" | grep -E " member of " | wc -l)
	smart_group_name=$(echo "${smart_group_info}" | awk -F '[\.]+[\.]' '/Name/ {print $2; exit}')
	policy_id=$(echo "${smart_group_info}" | grep -oE 'ID\s+([0-9]+)' | awk 'NR==1 {print $2; exit}')
	
	if ((smart_group_criteria_counter + 1 > 4)) || ((smart_group_nested_counter > 1)) ; then
		if ((smart_group_criteria_counter + 1 > 5)) || ((smart_group_nested_counter > 1)) ; then
			criteria_colour=$red
			nested_colour=$red
			name_colour=$red
			#criteria_ids+=("$policy_id") # Add criteria policy_id to the array
			#if ((smart_group_nested_counter > 1)) ; then
			#	nested_ids+=("$policy_id") # Add nested policy_id to the array
			#fi
		else
			criteria_colour=$grn
			nested_colour=$grn
			name_colour=$grn
		fi
		
		printf "${criteria_colour}${bld}%3d${off}${bld} |  criteria ${criteria_colour}%3d${off}${bld}  |  nested ${nested_colour}%3d${off}  |  ${bld}Smart Group Name: ${name_colour}%s${off}\n" \
		"$policy_id" "$((smart_group_criteria_counter + 1))" "$smart_group_nested_counter" "$smart_group_name"
		printf -- '-%.0s' {1..80}
		printf "\n"
	fi
done
#printf "${bld}Policy IDs with criteria count greater than 5 : %s\n${off}" "$(IFS=, ; echo "${criteria_ids[*]}")"
#printf "${bld}Policy IDs with nested count greater than 2 : %s\n${off}" "$(IFS=, ; echo "${nested_ids[*]}")"
