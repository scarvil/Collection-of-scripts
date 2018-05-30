#!/bin/bash
MAIL=user@company.com
HOST=`hostname -s`
LDATE=`date +%F`
LOG=/tmp/upgradeLog${LDATE}.txt
RSYNC=/usr/local/bin/rsync
destdir=/mnt/testperf01
src=/data/P4ROOT
P4PORT=192.168.2.2:1666
JOURNAL=/opt/perforce/backups/perforce_journal/journal
P4ROOT=/data/P4ROOT
P4D_DAEMON=/usr/local/bin/p4d
P4=/usr/local/bin/p4

P4D_ROOT=/opt/P4ROOT
P4D_DAEMON=/usr/local/bin/p4d
P4D_LOG=/opt/perforce/log/p4d.log
P4D_AUDIT=/opt/perforce/log/p4audit.log
P4D_JOURNALS=/opt/perforce/backups/perforce_journal/journal
P4D_USER=pforce
P4D_SERVER=192.168.2.2
P4D_PORT=1666
LIST=$(cd /data/P4ROOT ;find -L -maxdepth 1 -name '*' ! -name '.*' -not -iname 'db.*' -not -iname 'license' -printf '%f\n' | column)
MLIST=$(cd /data/bogus ;find -L -maxdepth 1 -name '*' ! -name '.*' -not -iname 'db.*' -not -iname 'license' -printf '%f\n' | column)
DT=Company
M=Company1

#1. Run a verify on Company depot and Company1 depots
# verify on Company
echo "Start verify on $DT depot before upgrade on $HOST on $(date)" | mail -s "Start verify before upgrade on $HOST on $DT depot on $(date)" $MAIL
su - p4dti -c "$P4 -p $P4D_SERVER:$P4PORT verify -q //... >> /tmp/verify.errors.before.upgrade.on.$DT.depot.txt"
echo "End verify on $DT depot before upgrade on $HOST on $(date)" | mail -s "End verify before upgrade on $HOST on $DT depot on $(date)" $MAIL
echo "See attached file of errors on $DT depot" | mutt -a /tmp/verify.errors.before.upgrade.on.$DT.txt -s "Verify errors on $HOST on $DT depot on $(date)" -x $MAIL
echo "See attached file of errors on $DT depot" | mutt -a /tmp/$DT.verify.errors.before.upgrade.txt -s "Verify errors on $HOST on $DT depot on $(date)" -x $MAIL
# verify on Company1
echo "Start verify on $M depot before upgrade on $HOST on $(date)" | mail -s "Start verify before upgrade on $HOST on $M depot on $(date)" $MAIL
$P4 -p $P4D_SERVER:1766 verify -q //depot/... >> /tmp/bogus.verify.errors.before.upgrade.txt
echo "End verify on $M depot before upgrade on $HOST on $(date)" | mail -s "End verify before upgrade on $HOST on $M depot on $(date)" $MAIL
echo "See attached file of errors on $M depot" | mutt -a /tmp/verify.errors.before.upgrade.on$M..txt -s "Verify errors on $HOST on $M depot on $(date)" -x $MAIL
echo "See attached file of errors on $M depot" | mutt -a /tmp/$M.verify.errors.before.upgrade.txt -s "Verify errors on $HOST on $M depot on $(date)" -x $MAIL

#2. Stop p4d
echo "Stopping perforce on $HOST for both $DT and $M" | mail -s "Stopping perforce on $HOST on $(date)" $MAIL
su - p4dti -c "/usr/local/bin/p4 -p $P4D_SERVER:$P4D_PORT admin stop"
/etc/init.d/p4webctl stop
/etc/init.d/bogusperforce stop
/etc/init.d/bogusp4webctl stop

sleep 5

#3. Run checkpoint
#DT
echo "Starting checkpoint for $DT" | mail -s "Starting checkpoint for $DT" $MAIL
bash -xv /usr/local/cron/CreateCheckPoint.sh
if [ $? = 0 ]; then
	echo "$DT: finished checkpoint" | mail -s "$DT: finished checkpoint" $MAIL
	echo "$DT: Starting backup" | mail -s "$DT: Starting backup for $DT" $MAIL
	bash -xv /usr/local/cron/CopyVersionedFiles.sh
	if [ $? = 0 ]; then
		echo "$DT: finished backup" | mail -s "$DT: finished backup for $DT" $MAIL
	else
		echo "$DT: BACUKP FAILED!" | mail -s "$DT: BACUKP FAILED!" $MAIL	
		exit 1
	fi
else
	echo "$DT: CHECKPOINT FAILED!" | mail -s "$DT: CHECKPOINT FAILED!" $MAIL
	exit 1
fi
	
#MFACTOR 
echo "Starting checkpoint for $M" | mail -s "Starting checkpoint for $M" $MAIL
bash -xv /usr/local/cron/bogusbackup.bash
if [ $? = 0 ]; then
        echo "$M: finished checkpoint" | mail -s "$M: finished checkpoint" $MAIL        
else
        echo "$M: CHECKPOINT FAILED!" | mail -s "$M: CHECKPOINT FAILED!" $MAIL
        exit 1
fi

#4. Copy the new binaries.
echo "Copy binaries to /usr/local/bin on $HOST on $(date)" | mail -s "Copy binaries to /usr/local/bin on $HOST on $(date)"
mkdir /usr/local/bin/p4binarybackups2010.2
mv /usr/local/bin/p{4,4d,4web} /usr/local/bin/p4binarybackups2010.2
cp -rp /home/user/2011.1_p4_binaries_64-bit/p{4,4d,4web,4broker} /usr/local/bin

#5. Run the update.
# Company
echo "$DT: Start perforce update on $HOST on $(date)" | mail -s "$DT: Start perforce update on $HOST on $(date)" $MAIL
/usr/local/bin/p4d -r /data/P4ROOT -J /opt/perforce/backups/perforce_journal/journal -p $P4D_SERVER:$P4PORT -xu
if [ $? = 0 ]; then
	echo "$DT: Finish perforce update on $HOST on $(date)" | mail -s "$DT: Finish perforce update on $HOST on $(date)" $MAIL
else
	echo "$DT: perforce update FAILED! on $(date)" | mail -s "$DT: perforce update FAILED! on $(date)" $MAIL
fi

# Company1
echo "$M : Start perforce update on $HOST on $(date)" | mail -s "$M: Start perforce update on $HOST on $(date)" $MAIL
/usr/local/bin/p4d -r /data/bogus -J /opt/perforce/backups/bogus_perforce_journal/journal -p $P4D_SERVER:1766 -xu
if [ $? = 0 ]; then
        echo "$M: Finish perforce update on $HOST on $(date)" | mail -s "$M: Finish perforce update on $HOST on $(date)" $MAIL
else
	echo "$M: perforce update FAILED on $(date)" | mail -s "$M: perforce update FAILED on $(date)" $MAIL
fi

#6. Start p4d
echo "Starting perforce on $HOST" | mail -s "Starting perforce on $HOST on $(date)" $MAIL
/etc/init.d/perforce start
/etc/init.d/bogusperforce start
/etc/init.d/p4webctl start
/etc/init.d/bogusp4webctl start

#7. Check the version
echo "checking the version of perforce on $HOST $(date)" | mail -s "Starting perforce on $HOST $(date)" $MAIL
su - p4dti -c "p4 -p $P4D_SERVER:$P4PORT info | egrep -i 'version'" | mail -s "The version of perforce on $HOST" $MAIL

#8.  Run a verify
# verify on Company
echo "Start verify on $DT depot after upgrade on $HOST on $(date)" | mail -s "Start verify after upgrade on $HOST on $DT depot on $(date)" $MAIL
su - p4dti -c "$P4 -p $P4D_SERVER:$P4PORT verify -q //... >> /tmp/verify.errors.after.upgrade.on.$DT.depot.txt"
echo "End verify on $DT depot after upgrade on $HOST on $(date)" | mail -s "End verify after upgrade on $HOST on $DT depot on $(date)" $MAIL
echo "See attached file of errors on $DT depot" | mutt -a /tmp/verify.errors.after.upgrade.on.$DT.txt -s "Verify errors on $HOST on $DT depot on $(date)" -x $MAIL
echo "See attached file of errors on $DT depot" | mutt -a /tmp/$DT.verify.errors.after.upgrade.txt -s "Verify errors on $HOST on $DT depot on $(date)" -x $MAIL
# verify on Company1
echo "Start verify on $M depot after upgrade on $HOST on $(date)" | mail -s "Start verify after upgrade on $HOST on $M depot on $(date)" $MAIL
$P4 -p $P4D_SERVER:1766 verify -q //depot/... >> /tmp/bogus.verify.errors.after.upgrade.txt
echo "End verify on $M depot after upgrade on $HOST on $(date)" | mail -s "End verify after upgrade on $HOST on $M depot on $(date)" $MAIL
echo "See attached file of errors on $M depot" | mutt -a /tmp/verify.errors.after.upgrade.on$M..txt -s "Verify errors on $HOST on $M depot on $(date)" -x $MAIL
echo "See attached file of errors on $M depot" | mutt -a /tmp/$M.verify.errors.after.upgrade.txt -s "Verify errors on $HOST on $M depot on $(date)" -x $MAIL

