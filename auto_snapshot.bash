#!/bin/bash
#https://github.com/digitalocean/doctl/issues/309
exec > >(tee -i do_snapshot.log)

# Call dodroplet.config
. dodroplet.config

#DROPLETID=145251618
#DROPLETNAME=wpawme
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
/snap/bin/doctl compute droplet-action shutdown $DROPLETID --wait

# Create new snapshot using $NAME
echo "Creating snapshot titled \"$NAME\" value"
echo "Please wait this may take awhile"
/snap/bin/doctl compute droplet-action snapshot --snapshot-name "$NAME" $DROPLETID --wait

# Reboot droplet
echo "Powering on droplet"
/snap/bin/doctl compute droplet-action power-on $DROPLETID --wait
echo "We're live baby!"

# List snapshots and get oldest snapshots after $NUMRETAIN
echo "Deleting the last $NUMRETAIN snapshots"

# List snapshots, get oldest snapshots after 10
SNAPSHOTS=$(/snap/bin/doctl compute image list-user --format "ID" --no-header | wc -l)

if [ "$SNAPSHOTS" -gt 9 ]; then
	mapfile -t IDLIST < <(/snap/bin/doctl compute image list-user --format "ID" --no-header)

	OLDEST=${IDLIST[0]}

	/snap/bin/doctl compute image delete "$OLDEST" -f
fi
sleep 1


#Send email end program
echo "Sending completion email to $RECIPIENTEMAIL"
echo "Snapshot of $HOST Created $TODAY"$'\r' >> $email_notification
sendmail -f "$RECIPIENTEMAIL" $RECIPIENTEMAIL < $email_notification

# Clean up work
rm -r $email_notification $tmpdir

echo "Snapshot Process Completed"
exit 0
