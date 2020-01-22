

# Digital Ocean Droplet Remote Snapshot

This script uses Digital Ocean's [DOCTL](https://github.com/digitalocean/doctl) command line interface to connect to a specific Droplet to take a snapshot. The script shuts the droplet down beforehand to prevent data corruption as recommended by Digital Ocean. Once complete, the droplet is returned to a powered on state. Once booted, it will retain a specified number of snapshots (excluding backups) associated with the Droplet's ID as indicated in the configuration file.

Learn about how I can came up with this idea: https://aaronweiss.me/automated-digital-ocean-droplet-snapshots-with-doctl

## Requirements
- [doctl](https://github.com/digitalocean/doctl#installing-doctl)

## Optional
- 'sendmail' SMTP configured to send email notifications

## Installation
```git clone https://github.com/aaronmweiss/DOCTL-Remote-Snapshot.git```

## Usage

### Configuration
Please add the following information to your do_droplet.config file
```
DROPLETID=
DROPLETNAME=

# Enter the number of snapshots to keep
NUMRETAIN=

#Have a notification send to an email
RECIPIENTEMAIL=your@email.account

#Optional
#Append an additional note at end of snapshot name. Currently, it's set to "_cron_snapshot"
SNAPNAMEAPPEND="_cron_snapshot"
```

DROPLETID is your Droplet's ID. If you do not know your Droplet's ID, log into your [Digital Ocean account ](https://cloud.digitalocean.com/droplets), click on the droplet, and the URL of your droplet will contain your Droplet's ID after the /droplets/ directory, like so: https://cloud.digitalocean.com/droplets/**XXXXXXXXX**/graphs?i=78109b&period=hour

NUMRETAIN is the amount of snapshots you'd like to keep. 

### Execution
`sudo bash auto_snapshot.bash`

### Cron
Consider adding this script to your crontab. Below is an example to run this script every Wednesday at 1 AM
```
0 1 * * 3 /bin/bash /usr/local/bin/auto_snapshot.bash
```
## Notice
As of 12/16/2019, Digital Ocean charges [$0.05/GB per month](https://www.digitalocean.com/docs/images/snapshots/). Contributors to this script are not liable for costs associated with running or maintaining a Digital Ocean account.  

## Roadmap

 1. ~~Have the option to only delete snapshots within the $DROPLETID.
    Currently, this script will delete any image within the user's
    account~~ (COMPLETED)
 2. Find an elegant solution to allow for multiple droplets to be used separately.
 3. Optionally create a screenshot of a website to show that the server/site is live after the script completed.

## Thank yous
This is my first open source contribution and much of this script has relied on the work of others before me. Among these are some snippets found [here](https://github.com/digitalocean/doctl/issues/309) and [here](https://askubuntu.com/questions/743493/best-way-to-read-a-config-file-in-bash). 

## Resources
https://github.com/digitalocean/doctl#authenticating-with-digitalocean
https://www.digitalocean.com/community/tutorials/how-to-use-doctl-the-official-digitalocean-command-line-client
https://github.com/digitalocean/doctl/issues/309

## Change log

### January 22nd, 2020
- Added snapshot name display for command line use
- Improved config file sourcing
- Improved snapshot listing to exclude backups from retention
- Removed sudo execution requirement until further testing completed

### January 8th, 2020
- Ability to delete snapshots associated with the specific Droplet ID up to the amount assigned in the RETAIN variable assigned in dodroplet.config
- Require sudo execution
- Changed the user to $USER