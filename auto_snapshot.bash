#!/bin/bash
#exec > >(tee -i do_snapshot.log)
#set -xv   # this line will enable debug

# Check for root or sudo execution
#if [ "$EUID" -ne 0 ]
#  then echo "Please run as root using sudo bash dev-config.bash"
#  exit 1
#fi

# Spinner
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

# Call dodroplet.config
scriptdir=$(dirname "$0")
source $scriptdir/dodroplet.config

# Weekday, Month, date, YEAR, 12-hour:minute timezone
DATE=$(date '+%a-%b-%d-%Y@%H:%M-%Z')"$SNAPNAMEAPPEND"
NAME=$DROPLETNAME"_"$DATE
HOST=$(hostname)
IPADD=$(hostname -I | awk '{print $1}')
TODAY=$(date '+%A, %B %d %Y at %I:%M%p %Z')

# Create email template
tmpdir=tmp
email_notification=$tmpdir/email_notification.txt

mkdir $tmpdir
touch $email_notification
echo "To: $RECIPIENTEMAIL"$'\r' >> $email_notification
echo "From: $HOST <$HOST@$IPADD>"$'\r' >> $email_notification
echo "Subject: $HOST Snapshot on $DROPLETID Completed"$'\r' >> $email_notification
echo $'\r' >> $email_notification
echo $'\r' >> $email_notification
echo $'\r' >> $email_notification

echo "Starting script"
sleep 3

# Shutdown droplet
echo "Shutting down droplet"
sudo /snap/bin/doctl compute droplet-action shutdown $DROPLETID --wait

# Create new snapshot using $NAME
echo "Creating snapshot titled \"$NAME\""
echo "Please wait this may take awhile. About 1 minute per GB."
sudo /snap/bin/doctl compute droplet-action snapshot --snapshot-name "$NAME" $DROPLETID --wait

# Reboot droplet
echo "Powering on droplet."
sudo /snap/bin/doctl compute droplet-action power-on $DROPLETID --wait
echo "Droplet is now powered-on."
sleep 2

# List snapshots and get oldest snapshots after $NUMRETAIN
SNAPSHOTS=$(sudo /snap/bin/doctl compute image list-user --format "ID,Type" --no-header | grep snapshot | wc -l)
a=$(($SNAPSHOTS - $NUMRETAIN))
echo "Deleting the last $a snapshots"

# Deleting all snapshots beyond $NUMRETAIN
while [[ "$SNAPSHOTS" -gt "$NUMRETAIN" ]]
	do 
		OLDEST=$(sudo /snap/bin/doctl compute image list-user --format "ID,Type" --no-header | grep -e '$DROPLETID\|snapshot' | awk '{print$1}' | head -n 1)
		OLDESTNAME=$(sudo /snap/bin/doctl compute snapshot list --format "ID,Name,ResourceId" | grep $DROPLETID | awk '{print$2}' | head -n 1)
		echo "Deleting "$OLDESTNAME""
		sudo /snap/bin/doctl compute image delete $OLDEST --force
		SNAPSHOTS=$(sudo /snap/bin/doctl compute image list-user --format "ID,Type" --no-header | grep snapshot | wc -l)
done
sleep 1

#Send email end program
echo "Sending completion email to $RECIPIENTEMAIL"
echo "Snapshot of $HOST Created $TODAY"$'\r' >> $email_notification
sudo sendmail -f "$RECIPIENTEMAIL" $RECIPIENTEMAIL < $email_notification

# Clean up work
sudo rm -r $email_notification $tmpdir

echo "Snapshot Process Completed"
exit 0
