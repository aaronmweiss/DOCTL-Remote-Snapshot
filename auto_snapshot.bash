#!/bin/bash

#Enable Debug
#set -xv

### Capture logs
if [ -d "/var/log/doctl-remote-snapshot" ]
	then 
		:
	else	
		sudo mkdir /var/log/doctl-remote-snapshot
fi
logdate=$(date +%Y%b%d@%H:%M)
exec > >(tee -i /var/log/doctl-remote-snapshot/auto_snapshot_$logdate.log)

### Check for root or sudo execution
#if [ "$EUID" -ne 0 ]
#  then echo "Please run as root using sudo bash dev-config.bash"
#  exit 1
#fi

### Spinner
# http://fitnr.com/showing-a-bash-spinner.html
spinner()
{
    local pid=$1
    local delay=0.3
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}
#& spinner $!

### Call dodroplet.config
scriptdir=$(dirname "$0")
source $scriptdir/dodroplet.config

### Constants
date=$(date '+%a-%b-%d-%Y@%H:%M-%Z')"$snap_name_append"
dropletname=$(doctl compute droplet list | grep -e $dropletid | awk '{print$2}')
name=$dropletname"_"$date
host=$(hostname)
ipadd=$(hostname -I | awk '{print $1}')
today=$(date '+%A, %B %d %Y at %I:%M%p %Z')
snap_ip=$(sudo /snap/bin/doctl compute droplet list | grep $dropletid | awk '{print$3}')

### Create email template
tmpdir=tmp
email_notification=$tmpdir/email_notification.txt

mkdir $tmpdir
touch $email_notification
echo "To: $recipient_email"$'\r' >> $email_notification
echo "From: $host <$host@$ipadd>"$'\r' >> $email_notification
echo "Subject: Snapshot on "$dropletname" Completed"$'\r' >> $email_notification
echo $'\r' >> $email_notification
echo $'\r' >> $email_notification
echo $'\r' >> $email_notification

echo "Starting script"
sleep 3

### Shutdown droplet
echo "Shutting down droplet"
sudo /snap/bin/doctl compute droplet-action shutdown $dropletid --wait

### Create new snapshot using $name
echo "Creating snapshot titled \"$name\""
echo "Please wait this may take awhile. About 1 minute per GB."
sudo /snap/bin/doctl compute droplet-action snapshot --snapshot-name "$name" $dropletid --wait
new_snap=$(sudo /snap/bin/doctl compute snapshot list | grep $dropletid | tail -n 1 | awk '{print$2}')

### Reboot droplet. While loop to test if server IP is reachable by ping, if not, powers on until live.
echo "Powering on droplet. Please wait."
sudo /snap/bin/doctl compute droplet-action power-on $dropletid --wait
sleep 5
while ! ping -c 1 "$snap_ip" &> /dev/null
	do
		echo "Droplet and Server are NOT Live. Waiting 10 seconds to test again"
		sleep 10
		if ping -c 1 "$snap_ip" &> /dev/null
			then
				echo "Droplet and Server is Live"
				break
			else 
				echo "Still not live. Attempting to power on again"
				sudo /snap/bin/doctl compute droplet-action power-on $dropletid --wait  				
		fi
done

# List snapshots and get oldest snapshots after $numretain
snapshots=$(sudo /snap/bin/doctl compute image list-user --format "ID,Type" --no-header | grep snapshot | wc -l)
a=$(($snapshots - $numretain))
echo "Deleting the last "$a" snapshot(s)"

# Deleting all snapshots beyond $numretain
while [[ "$snapshots" -gt "$numretain" ]]
	do 
		oldest=$(sudo /snap/bin/doctl compute image list-user --format "ID,Type" --no-header | grep -e '$dropletid\|snapshot' | awk '{print$1}' | head -n 1)
		oldest_name=$(sudo /snap/bin/doctl compute snapshot list --format "ID,Name,ResourceId" | grep $dropletid | awk '{print$2}' | head -n 1)
		echo "Deleted "$oldest_name""$'\r' >> $email_notification
		echo "Deleting "$oldest_name""$'\r'
		sudo /snap/bin/doctl compute image delete $oldest --force
		snapshots=$(sudo /snap/bin/doctl compute image list-user --format "ID,Type" --no-header | grep snapshot | wc -l)
done
sleep 1

#Send email end program
echo "Sending completion email to "$recipient_email""
echo >> $email_notification
echo "Snapshot of "$dropletname" titled "$new_snap" Created $today"$'\r' >> $email_notification
echo "Server was confirmed to be UP"$'\r' >> $email_notification
sudo sendmail -f "$recipient_email" $recipient_email < $email_notification

# Clean up work
sudo rm -r $email_notification $tmpdir

echo "Snapshot Process Completed"
exit 0
