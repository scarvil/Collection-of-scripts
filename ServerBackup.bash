#!/bin/bash
# Author : scarvil
# Date   : 10/08/2010
# Purpose: To backup filesystems/directories/files on linux servers to the lms server
# Revisions: Initial
#
# Variables
#
# Set PATH
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin

# Samba user access
BKUSER="backupweb01"
BKPASSWD="Welcome1"

DATE=`date`
RDATE=`date +%F`
DOMAIN=company.com 
SEND=/usr/bin/sendmail 
MUTT=/usr/bin/mutt
FROM="labadmin@${DOMAIN}"
MAIL="scarvil@${DOMAIN}"
export HOST=`hostname -s` 
LOG="/tmp/${HOST}.backup.log" 
BKLOG="/tmp/${HOST}.${RDATE}_backup.txt"
DBBKUP=mysqlbackup 
SERVER=lms.${DOMAIN}
ID=`id -u`
export BACKUPDIR=/mnt/backup
LOCK=/tmp/.lockfile
SCRIPT=`basename $0` 
PIDFILE="/tmp/$SCRIPT.pid"
TESTFILE=".donotremovethisfile"
export RETAIN=2
#MD5Source=`md5sum locking | awk '{print $1}'`

# Directories to be backed up
# edit, if needed
DIRS="
/home
/etc
/usr/local/liferay
/var/spool/cron
"

# Functions
#
# Keep the last 2 backups
rotate() {
find ${BACKUPDIR}/${HOST} -type f -mtime +$RETAIN -exec rm -rfv '{}' \; -print
}

mailit() {
# Mail to user via sendmail
{
echo "To: $MAIL"
echo "From: ${FROM}"
echo "X-MSMail-Priority: Normal"
echo "Subject: Backup completed for ${HOST} on ${DATE}"
echo "
Greetings,

The backup for ${HOST} on ${DATE} has completed.
The following directories were backed up:
`echo $DIRS`

Regards,
Corp IT
"
} |$SEND -t $MAIL
}

mailmutt() {
# Mail to user via mutt
$MUTT $MAIL -a $BKLOG -s "Backup completed for ${HOST} on ${DATE}" -e "my_hdr X-Priority: 23" -x <<-EOF

Greetings!

The backup for ${HOST} on ${DATE} has completed.
The following directories were backed up:
`echo $DIRS`

For more information see attached.


Regards,
Corp IT
EOF
}

# Mail user on failure
mailfail() {
{
echo "To: $MAIL"
echo "From: ${FROM}"
echo "X-MSMail-Priority: Normal"
echo "Subject: Backup failed for ${HOST} on ${DATE}"
echo "
Greetings,

The backup for ${HOST} on ${DATE} has failed.
Review the $BKLOG for more information.
`cat $LOG`

Regards,
Corp IT
"
} |$SEND -t $MAIL
}

# End Functions

# MAIN
#

# Is the log file here?
if [ -f $LOG ]; then
   rm -rf $LOG
else
   echo "$HOST backup log" > $LOG
fi

# Am I root?
if [ $ID != 0 ]; then
   echo "
   You must be root to run this script!
   Exiting....
   " >> $LOG
   mailfail
   exit 1
fi

# Is the destination server up?
ping -c 1 $SERVER > /dev/null 2>&1
echo $?

if [ $? = 0 ]; then
   echo "The destination server is up." >> $LOG
else
   echo "
   The destination server is down.
   I cannot continue...
   " >> $LOG
   mailfail
   exit 1
fi

# Does the backup directory exist?
stat $BACKUPDIR
echo $?

if [ -d $BACKUPDIR ]; then
   echo "The backup directory is present." >> $LOG
else
   echo "
   The backup directory is NOT present.
   Creating the mount point...
   " >> $LOG
   mkdir $BACKUPDIR
fi

# Is the backup directory mounted?
stat $BACKUPDIR/$TESTFILE
echo $?

if [ -f $BACKUPDIR/$TESTFILE ]; then
   echo "The cifs share is already mounted." >> $LOG
else
  mount -o rw,username="$BKUSER",password="$BKPASSWD" //$SERVER/backups $BACKUPDIR 
  stat $BACKUPDIR/$TESTFILE
  if [ -f $BACKUPDIR/$TESTFILE ]; then
     echo "The cifs share is mounted." >> $LOG
  else
     echo "
     The cifs share cannot be mounted.
     Exiting...
     " >> $LOG 
     mailfail
     exit 1
  fi
fi

# Does the backup folder exist on the backup server?
stat $BACKUPDIR/$HOST
echo $?

if [ -d $BACKUPDIR/$HOST ]; then
   echo "Backup folder for $HOST exists." >> $LOG
else
   echo "
   Backup folder for $HOST does not exist.
   Creating one...
   " >> $LOG
   mkdir $BACKUPDIR/$HOST 
   if [ -d $BACKUPDIR/$HOST ]; then
      echo "Backup folder for $HOST has been created." >> $LOG
   else
      echo "
      Backup folder for $HOST cannot be created.
      Exiting...
      " >> $LOG
      mailfail
      exit 1
   fi
fi

# If liferay or web01, backup mysql
if [[ $HOST = liferaystage || $HOST = liferaydev ]] ; then
   mysqldump --all-databases -u root > $BACKUPDIR/$HOST/${HOST}.$RDATE.db.sql
   if [ $? != 0 ];then
      echo "Mysqldump backup failed on $HOST" >> $LOG
      mailfail
   else
      echo "Compressing the db.sql backup with gzip" >> $LOG
      gzip -f -9 $BACKUPDIR/$HOST/${HOST}.$RDATE.db.sql
      if [ $? != 0 ];then
         echo "There was an error encountered while runnning gzip" >> $LOG
      fi
   fi
fi

# Backup the files
if [ -x /bin/tar ]; then
   echo "Begin tar backup on $HOST on $DATE" >> $LOG
   tar cvjf $BACKUPDIR/$HOST/${HOST}.$RDATE.tbz2 $DIRS > $BKLOG
   if [ $? = 0 ]; then
      DATE=`date`
      echo "End tar backup on $HOST on $DATE." >> $LOG
      echo "Backup succeeded on $HOST on $DATE." >> $LOG
      # Keep the last 2 backups
      find ${BACKUPDIR}/${HOST} -type f -mtime +$RETAIN -exec rm -rfv '{}' \; -print
      # Unmount the backup directory
      if [ -f $BACKUPDIR/$TESTFILE ]; then
         umount $BACKUPDIR
         if [ -f $BACKUPDIR/$TESTFILE ]; then
            echo "Cannot unmount $BACKUPDIR" >> $LOG
         fi
      fi
   else
      mailfail
   fi
else
   echo "Tar command not found or not executable." >> $LOG
   # Unmount the backup directory
   if [ -f $BACKUPDIR/$TESTFILE ]; then
      umount $BACKUPDIR
      if [ -f $BACKUPDIR/$TESTFILE ]; then
         echo "Cannot unmount $BACKUPDIR" >> $LOG
	 mailfail
      fi
   fi
fi
