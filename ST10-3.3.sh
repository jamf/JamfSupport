#!/bin/bash

# THE SOFTWARE IS PROVIDED "AS-IS," WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL
# JAMF SOFTWARE, LLC OR ANY OF ITS AFFILIATES BE LIABLE FOR ANY CLAIM, DAMAGES
# OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT, OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OF OR OTHER DEALINGS IN
# THE SOFTWARE, INCLUDING BUT NOT LIMITED TO DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, CONSEQUENTIAL OR PUNITIVE DAMAGES AND OTHER DAMAGES SUCH AS LOSS OF
# USE, PROFITS, SAVINGS, TIME OR DATA, BUSINESS INTERRUPTION, OR PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES.

########################################################
#                                                      #
#                                                      #
#           Jamf Pro Server Summary Tool 3.3           #
#                   2022 - JSS 10.40.0                 #
#   By Sam Fortuna & Nick Anderson & Tyrone Luedtke    #
#                                                      #
#                                                      #
########################################################

# Check if a file was included on start
file="$1"
# Demand a valid summary
function newsummary {
	read -p "Summary Location: " file
}

while [[ "$file" == "" ]] ; do
	newsummary
done

clear
echo "--- Jamf Summary Parser 3.3 ---"

#Check to see what kind of terminal this is to make sure we use the right echo mode, no idea why some are different in this aspect
echotest=`echo -e "test"`
if [[ "$echotest" == "test" ]] ; then
	echomode="-e"
else
	echomode=""
fi

# Pull top 100 lines of the summary
t100=`head -n 100 "$file"`
# Pull 500 lines after "LDAP Servers"
middle_a=`cat "$file" | grep -A 500 "LDAP Servers"`
# Pull 500 lines after Checkin
middle_b=`cat "$file" | grep -A 500 "Check-In"`
# Pull last 500 for table entries
tables=`tail -n 500 "$file"`
# Set the date
todayepoch=`date +"%s"`


########################################################
# --- Server infrastructure

# Server OS
echo $echomode "Server OS: \t\t\t\t $(echo "$t100" | grep "Operating System" | awk '{for (i=3; i<NF; i++) 'print'f $i " "; 'print' $NF}')"
# JSS Version
echo $echomode "JSS Version: \t\t\t\t $(echo "$t100" | awk '/Installed Version/ {'print' $NF}')"
# Java version
echo $echomode "Java Version: \t\t\t\t $(echo "$t100" | awk '/Java Version/ {'print' $NF}')"

# MySQL Version
echo $echomode "MySQL Version: \t\t\t\t $(echo "$t100" | awk '/version ..................../ {'print' $NF}') $(echo "$t100" | awk '/version_compile_os/ {'print' $NF}')"
# Database driver
echo $echomode "MySQL Driver: \t\t\t\t $(echo "$t100" | awk '/Database Driver .................................../ {'print' $NF}')"
# Database server
echo $echomode "MySQL Server: \t\t\t\t $(echo "$t100" | awk '/Database Server/ {'print' $NF}')"
# Database name
echo $echomode "Database name: \t\t\t\t $(echo "$t100" | awk '/Database Name/ {'print' $NF}')"
# Database size
echo $echomode "Database Size: \t\t\t\t $(echo "$t100" | grep "Database Size" | awk 'NR==1 {'print' $(NF-1),$NF}')"
# Max pool size
echo $echomode "Max Pool Size:  \t\t\t $(echo "$t100" | awk '/Maximum Pool Size/ {'print' $NF}')"
# Max database connections
echo $echomode "Maximum MySQL Connections: \t\t $(echo "$t100" | awk '/max_connections/ {'print' $NF}')"
# Max allowed packet
#echo $echomode "Max Allowed Packet Size: \t\t $(($(echo "$t100" | awk '/max_allowed_packet/ {'print' $NF}')/ 1048576)) MB"
# Binary logging
binlogging=`echo "$t100" | awk '/log_bin ..................../ {'print' $NF}'`
if [ "$binlogging" = "OFF" ] ; then
	echo $echomode "Bin Logging: \t\t\t\t $(echo "$t100" | awk '/log_bin ..................../ {'print' $NF}') \t$(tput setaf 2)✓$(tput sgr0)"
else
	echo $echomode "Bin Logging: \t\t\t\t $(echo "$t100" | awk '/log_bin ..................../ {'print' $NF}') \t$(tput setaf 9)[!]$(tput sgr0)"
fi
# MyISAM tables
echo $echomode "MyISAM Tables:  \t\t\t $(echo "$t100" | awk '/MyISAM Tables/ {'print' $NF}')"
# InnoDB tables
echo $echomode "InnoDB Tables:  \t\t\t $(echo "$t100" | awk '/InnoDB Tables/ {'print' $NF}')"
# Large tables
echo $echomode "Tables over 1 GB in size:"
largeTables=$(echo "$tables" | awk '/GB/ {'print' "\t", $(NF-1), $NF, "    ", $1}')
if [ "$largeTables" != "" ]; then
	echo $echomode "$largeTables"
else
	echo $echomode "\tNone \t$(tput setaf 2)✓$(tput sgr0)"
fi

# Tomcat version
echo $echomode "Tomcat Version: \t\t\t $(echo "$t100" | grep "Tomcat Version" | awk '/Tomcat Version ..................................../ {for (i=4; i<NF; i++) 'print'f $i " "; 'print' $NF}')"
# Webapp location
echo $echomode "Webapp location: \t\t\t $(echo "$t100" | grep "Web App Installed To" | awk '{for (i=5; i<NF; i++) 'print'f $i " "; 'print' $NF}')"
# Http threads
echo $echomode "HTTP Threads: \t\t\t\t $(echo "$middle_a" | awk '/HTTP Connector/ {'print' $NF}')"
# Https threads
echo $echomode "HTTPS Threads: \t\t\t\t $(echo "$middle_a" | awk '/HTTPS Connector/ {'print' $NF}')"
# SSL cert subject
sslsubject=`echo "$middle_a" | awk '/SSL Cert Subject/ {$1=$2=$3="";'print' $0}' | grep "O=JAMF Software"`
if [ "$sslsubject" = "" ] ; then
	echo $echomode "SSL Certificate Subject: \t      $(echo "$middle_a" | awk '/SSL Cert Subject/ {$1=$2=$3="";'print' $0}') \t$(tput setaf 9)[!]$(tput sgr0)"
else
	echo $echomode "SSL Certificate Subject: \t      $(echo "$middle_a" | awk '/SSL Cert Subject/ {$1=$2=$3="";'print' $0}')"
fi
# SSL cert expiration
ssldate=`echo "$middle_a" | awk '/SSL Cert Expires/ {'print' $NF}'`	#get the current ssl expiration date
dateformatssl=`echo $ssldate | sed 's/\/.*//' | wc -m`
if [[ "$ssldate" != "Expires" ]] ; then
	if [ $dateformatssl == 5 ] ; then
		sslepoch=`date -jf "%Y/%m/%d %H:%M" "$ssldate 00:00" +"%s"`
	else
	sslepoch=`date -jf "%m/%d/%y %H:%M" "$ssldate 00:00" +"%s"`			#convert it to unix epoch
	fi
	ssldifference=`expr $sslepoch - $todayepoch`				#subtract ssl epoch from today's epoch
	sslresult=`expr $ssldifference / 86400`					#divide by number of seconds in a day to get remaining days to expiration

#If ssl is expiring in under 60 days, output remaining days in red instead of green
	if (( $sslresult > 60 )) ; then
		echo $echomode "SSL Certificate Expiration: \t\t $(echo "$middle_a" | awk '/SSL Cert Expires/ {'print' $NF}') \t$(tput setaf 2)$sslresult Days$(tput sgr0)"
	else
		echo $echomode "SSL Certificate Expiration: \t\t $(echo "$middle_a" | awk '/SSL Cert Expires/ {'print' $NF}') \t$(tput setaf 9)$sslresult Days$(tput sgr0)"
	fi
else
		echo $echomode "SSL Certificate Expiration: \t\t $(echo "$(tput setaf 9)Unreadable$(tput sgr0)")"

fi

# Remote IP valve
echo $echomode "Remote IP Valve: \t\t\t $(echo "$middle_a" | awk '/Remote IP Valve/ {'print' $NF}')"
# Proxy port, scheme
proxyportcheck=`echo "$middle_a" | awk '/Proxy Port/ {'print' $NF}'`
if [[ "$proxyportcheck" != "................" ]] ; then
	echo $echomode "Proxy Port: \t\t\t\t $(echo "$middle_a" | awk '/Proxy Port/ {'print' $NF}') $(echo "$middle_a" | awk '/Proxy Scheme/ {'print' $NF}')"
else
	echo $echomode "Proxy Port: \t\t\t\t $(echo "Unconfigured")"
fi
# Clustering
cluster=`echo "$middle_a" | awk '/Clustering Enabled/ {'print' $NF}'`
if [[ "$cluster" == "true" ]] ; then
	echo $echomode "Clustering Enabled: \t\t\t $(echo "$middle_a" | awk '/Clustering Enabled/ {'print' $NF}') \t$(tput setaf 9)[!]$(tput sgr0)"
else
	echo $echomode "Clustering Enabled: \t\t\t $(echo "$middle_a" | awk '/Clustering Enabled/ {'print' $NF}')"
fi

# --- Management framework

# Address
echo $echomode "JSS URL: \t\t\t\t $(echo "$middle_a" | awk '/HTTPS URL/ {'print' $NF}')"


# Managed computers
echo $echomode "Managed Computers: \t\t\t $(echo "$t100" | head -n 50 | awk '/Managed Computers/ {'print' $NF}')"
# Managed iOS devices
echo $echomode "Managed Mobile Devices: \t\t $(echo "$t100" | awk '/Managed iOS Devices/ {'print' $NF}')"
# Managed Apple TVs
echo $echomode "Managed Apple TVs 10.2 or later: \t $(echo "$t100" | awk '/Managed Apple TV Devices \(tvOS 10.2 or later\)/ {'print' $NF}')"
echo $echomode "Managed Apple TVs 10.1 or earlier: \t $(echo "$t100" | awk '/Managed Apple TV Devices \(tvOS 10.1 or earlier\)/ {'print' $NF}')"

# APNS expiration
apnsdate=`echo "$middle_a" | grep -A 4 "Push Certificates" | grep Expires | awk '{'print' $2}'`	#get the current apns expiration date
apnsepoch=`date -jf "%Y/%m/%d %H:%M" "$apnsdate 00:00" +"%s"`					#convert it to unix epoch
apnsdifference=`expr $apnsepoch - $todayepoch`				#subtract apns epoch from today's epoch
apnsresult=`expr $apnsdifference / 86400`					#divide by number of seconds in a day to get remaining days to expiration

#If apns is expiring in under 60 days, output remaining days in red instead of green
if (( $apnsresult > 60 )) ; then
	echo $echomode "APNS Expiration: \t\t\t $(echo "$middle_a" | grep -A 4 "Push Certificates" | grep "Expires" | awk '{'print' $2}') \t$(tput setaf 2)$apnsresult Days$(tput sgr0)"
else
	echo $echomode "APNS Expiration: \t\t\t $(echo "$middle_a" | grep -A 4 "Push Certificates" | grep "Expires" | awk '{'print' $2}') \t$(tput setaf 9)$apnsresult Days$(tput sgr0)"
fi
# Push notifications enabled
pushnotifications=`echo "$middle_b" | awk '/Push Notifications Enabled/ {'print' $NF}'`
if [ "$pushnotifications" = "true" ] ; then
	echo $echomode "Push Notifications enabled: \t\t $(echo "$middle_b" | awk '/Push Notifications Enabled/ {'print' $NF}')"
else
	echo $echomode "Push Notifications enabled: \t\t $(echo "$middle_b" | awk '/Push Notifications Enabled/ {'print' $NF}') \t$(tput setaf 9)[!]$(tput sgr0)"
fi
# VPP tokens expiration
vppdate=`cat "$file" | grep -A 100 "VPP Accounts" | awk '/Expiration Date/ {'print' $NF}'`		#get the current vpp expiration date
if [[ -n $vppdate ]] ; then
	for i in $vppdate; do
		vppepoch=`date -jf "%Y/%m/%d %H:%M" "$i 00:00" +"%s"`				#convert it to unix epoch
		vppdifference=`expr $vppepoch - $todayepoch`				#subtract vpp epoch from today's epoch
		vppresult=`expr $vppdifference / 86400`					#divide by number of seconds in a day to get remaining days to expiration

		#If vpp token is expiring in under 60 days, output remaining days in red instead of green
		if (( "$vppresult" > 60 )) ; then
			echo $echomode "VPP Token Expiration: \t\t\t $i \t$(tput setaf 2)$vppresult Days$(tput sgr0)"
		else
			echo $echomode "VPP Token Expiration: \t\t\t $i \t$(tput setaf 9)$vppresult Days$(tput sgr0)"
		fi
	done
fi

########################################################


#Find problematic policies that are ongoing, enabled, update inventory and have a scope defined
list=`cat "$file" | grep -n "Ongoing" | awk -F : '{'print' $1}'`

echo $echomode
echo $echomode "The following policies are Ongoing, Enabled and update inventory:"

for i in $list 
do

	#Check if policy is enabled
	test=`head -n $i "$file" | tail -n 13`
	enabled=`echo $echomode "$test" | awk /'Enabled/ {'print' $NF}'`
	
	#Check if policy has an active trigger
	if [[ "$enabled" == "true" ]]; then
		trigger=`echo $echomode "$test" | grep Triggered | awk '/true/ {'print' $NF}'`
	fi
		
	#Check if the policy updates inventory
	if [[ "$enabled" == "true" ]]; then
		line=$(($i + 40))
		inventory=`head -n $line "$file" | tail -n 15 | awk '/Update Inventory/ {'print' $NF}'`
	fi
		
	#Get the name and scope of the policy
	if [[ "$trigger" == *"true"* && "$inventory" == "true" && "$enabled" == "true" ]]; then
		scope=`head -n $(($i + 5)) "$file" |tail -n 5 | awk '/Scope/ {$1=""; 'print' $0}'`
		name=`echo $echomode "$test" | awk -F '[\.]+[\.]' '/Name/ {'print' $NF}'`
		echo $echomode $(tput setaf 6)"Name: \t $name" $(tput sgr0)
		echo $echomode "Scope: \t $scope"
	fi
done

echo $echomode
echo $echomode "Ongoing at recurring check-in, but do not update inventory:"

for i in $list 
do
	#Check if policy is enabled
	test=`head -n $i "$file" | tail -n 13`
	enabled=`echo $echomode "$test" | awk /'Enabled/ {'print' $NF}'`
	
	#Check if policy is on the recurring trigger
	if [[ "$enabled" == "true" ]]; then
		recurring=`echo $echomode "$test" | awk '/Triggered by Check-in/ {'print' $NF}'`
	fi
		
	#Check if the policy updates inventory
	if [[ "$enabled" == "true" ]]; then
		line=$(($i + 40))
		inventory=`head -n $line "$file" | tail -n 15 | awk '/Update Inventory/ {'print' $NF}'`
	fi
	
	#Get the scope
	scope=`head -n $(($i + 5)) "$file" |tail -n 5 | awk '/Scope/ {$1=""; 'print' $0}'`
		
	#Get the name of the policy
	if [[ "$recurring" == "true" && "$inventory" == "false" && "$enabled" == "true" ]]; then
		name=`echo $echomode "$test" | awk -F '[\.]+[\.]' '/Name/ {'print' $NF}'`
		echo $echomode $(tput setaf 6)"Name: \t $name" $(tput sgr0)
		echo $echomode "Scope: \t $scope"
	fi
done

#Count number of policies that update inventory once per day

list2=`cat "$file" | grep -n "Once every day" | awk -F : '{'print' $1}'`

#Create a counter
inventoryDaily=0

for i in $list2
do

	#Check if policy is enabled
	test=`head -n $i "$file" | tail -n 13`
	enabled=`echo $echomode "$test" | awk /'Enabled/ {'print' $NF}'`
	
	#Check if policy has an active trigger
	if [[ "$enabled" == "true" ]]; then
		trigger=`echo $echomode "$test" | grep Triggered | awk '/true/ {'print' $NF}'`
	fi
		
	#Check if the policy updates inventory
	if [[ "$enabled" == "true" ]]; then
		line=$(($i + 40))
		inventory=`head -n $line "$file" | tail -n 15 | awk '/Update Inventory/ {'print' $NF}'`
	fi
	
	
		
	#Increment count if all above criteria are true
	if [[ "$trigger" == *"true"* && "$inventory" == "true" && "$enabled" == "true" ]]; then
		let inventoryDaily=inventoryDaily+1
	fi
done

echo $echomode
echo $echomode "There are" $inventoryDaily "policies that update inventory daily."

#List smart group names that include 10 or more criteria

while read line
do
#Count current line number
let lineNumber=lineNumber+1

if [[ "${line}" == *"Smart Computer Groups"* ]]; then
	lineNumber=`cat "$file"  | awk '/Smart Computer Groups/{'print' NR; exit}'`
	echo $echomode $line":"
	groups=0
elif [[ "${line}" == *"Smart Mobile Device Groups"* ]]; then
	echo $echomode "$(tput setaf 8)Total number of smart groups: $groups$(tput sgr0)"
	echo $echomode
	echo $echomode $line":"
	groups=0
elif [[ "${line}" == *"User Groups"* ]]; then
	echo $echomode "$(tput setaf 8)Total number of smart groups: $groups$(tput sgr0)"
	echo $echomode
	echo $echomode $line":"
	groups=0
elif [[ "${line}" == *"Device Enrollment Program"* ]]; then
	echo $echomode "$(tput setaf 8)Total number of smart groups: $groups$(tput sgr0)"
fi

	#Start counting number of criteria per group
	if [[ "${line}" == *"Membership Criteria"* ]]; then
		counter=1
		let groups=groups+1
		
		#Check for nested groups
		if [[ "${line}" == *"member of"* ]]; then
			nested=1
		else
			nested=0
		fi
	
	#Increment for each criteria found
	elif [[ "${line}" == *"- and -"* || "${line}" == *"- or -"* ]]; then
		let counter=counter+1
		
		#Check for nested groups
		if [[ "${line}" == *"member of"* ]]; then
			let nested=nested+1
		fi
		
		if [ $nested -eq 4 ]; then
			lineName=$(($lineNumber-$counter-1))
			nestedName=$(head -n $lineName "$file" | tail -n 1 | awk -F '[\.]+[\ ]' '{'print' $NF}')
			if [[ "$nestedName" == *"Site "* ]]; then
				lineName=$(($lineNumber-$counter-2))
				nestedName=$(head -n $lineName "$file" | tail -n 1 | awk -F '[\.]+[\ ]' '{'print' $NF}')
			fi
		fi

		#'print' the group names that have more than 10 criteria
		if [ $counter -eq 10 ]; then
			name=$(($lineNumber-11))
			groupName=$(head -n $name "$file" | tail -n 1 | awk -F '[\.]+[\ ]' '{'print' $NF}')
			if [[ "$groupName" == *"Site "* ]]; then
				name=$(($lineNumber-12))
				groupName=$(head -n $name "$file" | tail -n 1 | awk -F '[\.]+[\ ]' '{'print' $NF}')
			fi
		fi

	elif [[ "${line}" == *"Dependency Count"* ]]; then
		dependencies=$(echo "${line}" | awk '{'print' $NF}')
		if [[ $dependencies == 0 && $counter != 10 && $nested != 4 ]]; then
			depsNameLine=$(($lineNumber-$counter-2))
			dependenciesName=$(head -n $depsNameLine "$file" | tail -n 1 | awk -F '[\.]+[\ ]' '{'print' $NF}')
			if [[ "$dependenciesName" == *"Site "* ]]; then
				depsNameLine=$(($lineNumber-$counter-3))
				dependenciesName=$(head -n $depsNameLine "$file" | tail -n 1 | awk -F '[\.]+[\ ]' '{'print' $NF}')
			fi
		fi



	elif [[ "${line}" == *"==="* && $counter -ge 10 ]]; then
		if [ $nested -gt 3 ]; then
			echo $echomode "$(tput setaf 9)$counter criteria, $nested nested, $dependencies dependant$(tput sgr0) \t\t $(tput setaf 6)$groupName"
			counter=1
			nested=0
		else
			echo $echomode "$(tput setaf 9)$counter criteria,$(tput sgr0) $nested nested, $dependencies dependant \t\t $(tput setaf 6)$groupName"
			counter=1
		fi
	elif [[ "${line}" == *"==="* && $nested -gt 3 && $counter -lt 10 ]]; then
		echo $echomode "$(tput sgr0)$counter criteria, $(tput setaf 9)$nested nested $dependencies dependant$(tput sgr0) \t\t $(tput setaf 6)$nestedName "
		nested=0
	# elif [[ "${line}" == *"==="* && $dependencies == "0" ]]; then
	# 	echo $echomode "$(tput sgr0)$counter criteria, $nested nested, $(tput setaf 9)$dependencies dependant$(tput sgr0) \t\t $(tput setaf 6)$dependenciesName "
	# 	dependencies=1

	fi
done < "$file"

exit 0