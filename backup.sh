#!/bin/bash
# Vars
USER=p4dti
P4ROOT=/data/P4ROOT
LOG=/tmp/ckp.$(date +%m%d%Y).log
SEND=/usr/sbin/sendmail
HOST=`hostname -s`
MAIL="scarville@company.com"
P4D=/usr/local/bin/p4d
JOURNAL=/opt/perforce/backups/perforce_journal/journal
BACKUPDIR=/opt/perforce/backups/perforce_journal/
JNL=`su - $USER -c 'p4 counter journal'`
JNL2=`expr $JNL - 1`
CKP=`ls ${BACKUPDIR}*${JNL}*`
NOTIFY="scarville@company.com"
# Check if recent ckp file is in the backupdir
FIND_RECENT_CKP=`find $BACKUPDIR -iname "*ckp.${JNL}.gz"`
# Check if 2nd ckp file is in the backupdir
FIND_2ND_CKP=`find $BACKUPDIR -iname "*ckp.${JNL2}.gz"`
# Check the timestamp on the latest checkpoint file
CHK_TIMESTAMP=`stat -c '%y' $FIND_RECENT_CKP`
TIME_OF_LATEST_FILE_DAY=`stat -c '%y' $FIND_RECENT_CKP | awk -F- '{print $3}' | awk '{print $1}'`
TIME_OF_LATEST_FILE_MONTH=`stat -c '%y' $FIND_RECENT_CKP | awk -F- '{print $2}'`
TIME_OF_LATEST_FILE_YEAR=`stat -c '%y' $FIND_RECENT_CKP | awk -F- '{print $1}'`
TIME_OF_CKP2_DAY=`stat -c '%y' $FIND_2ND_CKP |  awk -F- '{print $3}' | awk '{print $1}'`
TIME_OF_CKP2_MONTH=`stat -c '%y' $FIND_2ND_CKP |  awk -F- '{print $2}'`
TIME_OF_CKP2_YEAR=`stat -c '%y' $FIND_2ND_CKP |  awk -F- '{print $1}'`

CURRENT_DAY=$(date +%d)
CURRENT_MONTH=$(date +%m)
YESTERDAY=$(date --date="-1 day" +%d)
DAYS=1

# functions

# mail if fail
mailfail() {
{
echo "To: $MAIL"
echo "From: $HOST"
echo "X-MSMail-Priority: High"
echo "Subject: The checkpoint rotation script failed on ${HOST}"
echo "
Hello!

The checkpoint rotation script on ${HOST} failed.
For more information see below.

`cat ${LOG}`

Have a nice day,
CorpIT
"
} |$SEND -t $MAIL
}

# MAIN
# Is the latest checkpoint there?
if [ -f $FIND_RECENT_CKP ]; then 
   echo "The latest checkpoint is here: $FIND_RECENT_CKP" > $LOG
   echo "The date of the latest checkpoint is: $TIME_OF_LATEST_FILE_MONTH/$TIME_OF_LATEST_FILE_DAY/$TIME_OF_LATEST_FILE_YEAR" >> $LOG
   echo "" >> $LOG
      if [ $TIME_OF_LATEST_FILE_DAY = $CURRENT_DAY ]; then
      echo "The last checkpoint for $FIND_RECENT_CKP is current." >> $LOG
         if [ $TIME_OF_CKP2_DAY = $YESTERDAY ]; then
            echo "" >> $LOG
            echo "The previous checkpoint is here: $FIND_2ND_CKP" >> $LOG
            echo "The previous checkpoint file is from: $TIME_OF_CKP2_MONTH/$TIME_OF_CKP2_DAY/$TIME_OF_CKP2_YEAR" >> $LOG 
            echo "The previous checkpoint for $FIND_2ND_CKP is from yesterday." >> $LOG
            echo "" >> $LOG
            echo "Deleting checkpoint and journal backups older than two days" >> $LOG
            find $BACKUPDIR -atime +${DAYS} \( -iname '*ckp*' -o -iname '*jnl*' \) -exec rm -f '{}' \; -print >> $LOG
         else
            echo "" >> $LOG
            echo "The previous checkpoint for $FIND_2ND_CKP is over two days old." >> $LOG
            echo "We will not delete this file since it is the 2nd most recent checkpoint." >> $LOG
            mailfail
            exit 1
         fi
   else
        echo "" >> $LOG
        echo "The last checkpoint for $FIND_RECENT_CKP is over one day old." >> $LOG
        echo "We will not delete this file since it is the most recent checkpoint." >> $LOG
        mailfail
        exit 1
   fi
else
   echo "" >> $LOG
   echo "Cannot find the  latest checkpoint file." >> $LOG
   echo "Exiting..." >> $LOG
   mailfail
   exit 1
fi

