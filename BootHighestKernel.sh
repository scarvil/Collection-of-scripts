#!/bin/bash
# Assuming there are only 10 entries
# and system is running centos 6.
#
# Check if I am root
ID=$(id -u)

if [ $ID != 0 ]; then
   echo "You need to root to run this script"
   exit 1
fi

# Check redhat release
RELEASE=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release))

if [ $RELEASE != 6 ]; then
   echo "This is not a centos 6 system"
   exit 1
fi

# Check if boot dir exists
DIR=/boot

if [ ! -d $DIR ]; then
   echo "$DIR does not exist"
   exit 1
fi

# Check if grub.conf is present
CFG=/boot/grub/grub.conf

if [ ! -f $CFG ]; then
   echo "$CFG does not exist"
   exit 1
fi

HIGHEST=$(rpm -q --qf="%{BUILDTIME} %{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n" kernel | sort -rn | cut -f2 -d ' ' | sed -e 's/kernel-//' | head -1)

linen=`grep ^title $CFG | wc -l`
FILE=/tmp/file.$$

j=0
while [ $j -lt $linen ]
do
generateOutput() {
    echo -n "$j  "
    let "j=j+1"
    cat $CFG | grep ^title | head -n $j | tail -n1 | cut -d' ' -f2-
} 

generateOutput > $FILE

cat $FILE | while read num KERNEL; do
   FINAL=$(echo $KERNEL | cut -d\( -f2 | cut -d\) -f1)
   if [[ "$HIGHEST" =~ $FINAL ]];
   then
      echo ""
      echo "The highest kernel version: $FINAL"
      OLDDEFAULT=$(egrep default= $CFG | cut -d= -f2)
      echo "Old default value is: $OLDDEFAULT"
      echo "Changing default value to boot kernel version: ${FINAL}"
      sed -r -i -e "s/default=[0-9]/default=$num/" $CFG
      NEWDEFAULT=$(egrep "default=" $CFG | cut -d= -f2)
      echo "New default value is: $NEWDEFAULT"
      echo ""
   fi
   done
done
