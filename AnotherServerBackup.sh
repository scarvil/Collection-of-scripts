#!/bin/bash
# Vars
USER=perforce
P4ROOT=/data/company1
LOG=/tmp/`basename $0`.$(date +%m%d%Y).log
srcdir=/data/company1/depot/
destHOST=testperf01.company.com:/opt/company1
###/opt/perforce/backups/company1_perforce_journal/
destdir=/mnt/company1_depot/
RSYNC=/usr/bin/rsync
SEND=/usr/sbin/sendmail
HOST=`hostname -s`
MAIL="scarville@company.com"
P4D=/usr/local/bin/p4d

# functions
#mountdst() {
#mount -t cifs //drobo1/Software -o username=root,password=W1nterg@mes /mnt/drobo
#}
mountdst() {
mount -t nfs $destHOST $destdir
}

statfile() {
stat $destdir/.donotdeletethisfile.txt
}

# Mail when complete
mailcomplete () {
{
echo "To: $MAIL"
echo "From: $HOST"
echo "X-MSMail-Priority: High"
echo "Subject: The company1 backup has completed on ${HOST}"
echo "
Hello!

The company1 backup on ${HOST} backing up files in ${srcdir} has completed.
For more information see below.

`cat ${LOG}`

Thanks,
CorpIT
"
} |$SEND -t $MAIL
}

# mail if fail
mailfail() {
{
echo "To: $MAIL"
echo "From: $HOST"
echo "X-MSMail-Priority: High"
echo "Subject: The company1 backup failed on ${HOST}"
echo "
Hello!

The company1 backup on ${HOST} backing up files in ${srcdir} failed.
For more information see below.

`cat ${LOG}`

Thanks,
Labadmin
"
} |$SEND -t $MAIL
}

# MAIN
# Does the backup folder exist on the backup server?
statfile
echo $?
if [ -f $destdir/.donotdeletethisfile.txt ]; then
   echo "The nfs share is already mounted." > $LOG
else
  mountdst
  statfile
  if [ -f $destdir/.donotdeletethisfile.txt ]; then
     echo "The nfs share is mounted." >> $LOG
  else
     echo "
     The nfs share cannot be mounted.
     Exiting...
     " >> $LOG
     mailfail
     exit 1
  fi
fi

#Create Checkpoint and purge the journal file
#$P4D -r $P4ROOT -J /usr/$USER/$USER -z -jc /usr/$USER/$USER
JOURNAL=/opt/perforce/backups/company1_perforce_journal/journal
#BACKUPDIR=/usr/$USER
BACKUPDIR=/opt/perforce/backups/company1_perforce_journal
JNL=`su - root -c "p4 -p hqperf:1766 counter journal"`
NEW_JNL=`expr $JNL + 1`
NEWJOURNAL=`ls $BACKUPDIR/*ckp*.gz | tail -1`
#TSTAMP=`date '+%Y%m%d%H%M%S'`
echo "company1 Checkpoint has started on $(date)." >> $LOG
mailx -s "The company1 checkpoint on ${HOST} has started on $(date)." $MAIL
#$P4D -r $P4ROOT -J $JOURNAL -z -jc $BACKUPDIR/$TSTAMP.ckp.$NEW_JNL.gz
$P4D -r $P4ROOT -J $JOURNAL -z -jc $JOURNAL >> $LOG
echo "company1 Checkpoint has ended on $(date)." >> $LOG
mailx -s "The company1 checkpoint on ${HOST} has finished on $(date)." $MAIL
echo "company1 journal is located here: $JOURNAL" >> $LOG
#echo "backup is located here: $BACKUPDIR/$TSTAMP.ckp.$NEW_JNL.gz" >> $LOG
echo "company1 backup is located here: $NEWJOURNAL" >> $LOG
# Run verify to make sure there are no changelist issues:
VLIST="
//depot/splat/main/...
//depot/tools/...
//depot/splat/v12_1/...
"
for i in $VLIST; do
	echo "Starting verify for: $i on $(date)" >> $LOG
	/usr/local/bin/p4 -p $HOST:1766 verify -qz $i >> $LOG
	echo "Finished verify for: $i on $(date)" >> $LOG
	echo "" >> $LOG
done

DIR=/opt/company1/depot/qa/scripts/ps/scripts
FILE=/tmp/list1
FIND=`which find`
PERL=`which perl`
$FIND /opt/company1/depot/qa/scripts/ps/scripts/ -type f > $FILE
$PERL -p -i -e 's/\/opt\/company1/\//g' $FILE
LIST=`cat $FILE`
echo "Starting verify for: //depot/qa/scripts/ps/scripts/... on $(date)" >> $LOG
for a in $LIST ; do
        /usr/local/bin/p4 -p $HOST:1766 verify -qz $a >> $LOG
done
echo "Finished verify for: //depot/qa/scripts/ps/scripts/... on $(date)" >> $LOG

# mail the jnl
mailjnl() {
{
echo "To: $MAIL"
echo "From: $HOST"
echo "X-MSMail-Priority: Normal"
echo "Subject: The company1 checkpoint completed on ${HOST}"
echo "
The company1 checkpoint on ${HOST} has completed.
The company1 journal is located here: ${JOURNAL}
The company1 checkpoint is located here: $BACKUPDIR/journal.ckp.$NEW_JNL.gz

For more information see below.

`cat ${LOG}`

"
	} |$SEND -t $MAIL
}

mailjnl

# rsync files
file=/tmp/`basename $0`.rsync.out
echo "company1 rsync started on $(date)" >> $LOG
echo "company1 rsync started on $(date)" > ${file}
#$RSYNC -avz --progress --stats --exclude-from '/usr/local/cron/exclude.txt' --log-file=${file} $srcdir $destdir
$RSYNC -avz --progress --stats --exclude-from '/usr/local/cron/exclude.txt' --log-file=${file}.txt /data/company1/depot/ /mnt/company1_depot/depot
#FILE=`ls $BACKUPDIR/NEWJOURNAL`
JNL=`su - root -c 'p4 -p hqperf:1766 counter journal'`
FILE=`ls $BACKUPDIR/*${JNL}*`
cp -rp $FILE /mnt/testperf01_ckp/backups/company1_perforce_journal/
echo "company1 rsync finished on $(date)" >> $LOG
echo "company1 rsync finished on $(date)" >> ${file}
echo "The company1 rsync logfile is here: $file" >> $LOG
# 
#mail the results
mailcomplete
