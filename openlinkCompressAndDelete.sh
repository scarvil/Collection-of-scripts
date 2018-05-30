#!/bin/bash
# To compress and delete openlink files over 3 years old
# scarvill
# initial
#
# VARs
ROOT=/mnt/openlink
DAYS=1095
FILE=/tmp/DeletedOpenLinkFiles.txt
MUTT=/usr/bin/mutt
HOST=`hostname --short`
FROM_DOM=`hostname`
TO_DOM="company.com"
TO="scarville@${TO_DOM}"
DATE=`date +%m.%d.%y`

# MAIN
cd $ROOT
export LIST=`ls`
for dir in  $LIST ; do
        echo -n "Size for $dir before compression and deletion of files:  " >> $FILE && du -sk $dir >> $FILE
        echo "The following files over ${DAYS} days old in $dir" >> $FILE
        echo "have been compressed in tar.bz2 format and deleted" >> $FILE
        echo "_________________________________________" >> $FILE
        find $dir -type f -mtime +${DAYS} -print >>  $FILE
        find $dir -type f -mtime +${DAYS} -print0 | xargs -0t tar --no-recursion -PScjf $ROOT/$dir/${dir}FilesOlderThan1095days.tbz2
        find $dir -type f -mtime +${DAYS} -exec rm -f '{}' \;
        echo -n "Size for $dir after compression and deletion of files: " >> $FILE && du -sk $dir >> $FILE
        echo "" >> $FILE
done

# MAIL
$MUTT $TO -a $FILE -s "Files deleted on ${HOST} at ${DATE}" -x <<-EOF

Greetings!

Files on ${HOST}:${ROOT} were compresed in their respective directories and then deleted.
For more information see attached.


Regards,
Ops
EOF

# Cleanup
rm ${FILE}

