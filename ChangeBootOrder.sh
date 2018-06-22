#!/bin/bash
## Begin variables
IP_LIST=$@
USER=root
PASS=password1234
LOG=~/bin/logs/$(basename $0).$(date +%F_%T).log
BOOTLOG=~/bin/bootSequence.log
SSH_ARGS='-oStrictHostKeyChecking=no -oCheckHostIP=no'
## End variables
## Begin Functions
PING() {
   ping -c 3 $ip > /dev/null
}
# Get boot sequence
GETSET() {
GETSETINFO=$(expect -c "
set timeout 20
spawn ssh $SSH_ARGS $USER@$ip
expect *password:
send \"$PASS\r\"
expect admin1->
send \"racadm\r\"
expect racadm>>
send \"get BIOS.BiosBootSettings.bootseq\r\"
expect racadm>>
send \"quit\r\"
expect admin1->
send \"exit\r\"
")
echo "$GETSETINFO" | egrep -v '(Key|admin1|racadm|WARNING|Warning|password|spawn)' >> $BOOTLOG
}
# Set boot sequence 
SETBOOT() {
BOOT=$(expect -c "
set timeout 20
spawn ssh $SSH_ARGS $USER@$ip
expect *password:
send \"$PASS\r\"
expect admin1->
send \"racadm\r\"
expect racadm>>
send \"set BIOS.BiosBootSettings.bootseq $FINAL\r\"
expect racadm>>
send \"quit\r\"
expect admin1->
send \"exit\r\"
")
echo "$BOOT" | egrep -v '(Key|admin1|racadm|WARNING|Warning|password|spawn)' >> $LOG
}
# Set job 
SETJOB() {
JOB=$(expect -c "
set timeout 20
spawn ssh $SSH_ARGS $USER@$ip
expect *password:
send \"$PASS\r\"
expect admin1->
send \"racadm\r\"
expect racadm>>
send \"jobqueue create BIOS.Setup.1-1\r\"
send \"jobqueue view\r\"
expect racadm>>
send \"quit\r\"
expect admin1->
send \"exit\r\"
")
echo "$JOB" | egrep -v '(Key|admin1|racadm|WARNING|Warning|password|spawn)' >> $LOG
}
# Set boot sequence 
SETPOWER() {
POWER=$(expect -c "
set timeout 20
spawn ssh $SSH_ARGS $USER@$ip
expect *password:
send \"$PASS\r\"
expect admin1->
send \"racadm\r\"
expect racadm>>
send \"serveraction powerstatus\r\"
expect racadm>>
send \"quit\r\"
expect admin1->
send \"exit\r\"
")
echo "$POWER" | egrep -v '(Key|admin1|racadm|WARNING|Warning|password|spawn)' >> $LOG
}

RMFILES() {
rm $NEW $NEW1 $NEW2 $NEW3 $NEW4 $NEWORDER $NEWORDER_FINAL $BOOTLOG
}

REORDERBOOTSEQUENCE() {
CSVstring=$(grep '.' ${BOOTLOG}  | sed -e 's/BootSeq=//g')
NEW=new
NEW1=new1
NEW2=new2
NEW3=new3
NEW4=new4
NEWORDER=newOrder
NEWORDER_FINAL=newOrderFinal
IFS=',' V=($CSVstring)
#echo "Elements in array V: ${#V[@]}"
rm $NEW $NEW1 $NEW2 $NEW3 $NEW4 $NEWORDER $NEWORDER_FINAL $FINAL

for((i = 0; i < ${#V[@]}; i++))
do
   printf "v[%d]=%s\n" $i "${V[i]}"
   if [[ "${V[i]}" =~ NIC.Integrated.1-1-1 ]];
   then
      echo "${V[i]}" > $NEW
   fi
   if [[ "${V[i]}" =~ NIC.ChassisSlot.[1|3|5|7]-1-1 ]];
   then
      echo "${V[i]}" >> $NEW1
   fi
   if [[ "${V[i]}" =~ NIC.ChassisSlot.[2|4|6|8]-1-1 ]];
   then
      echo "${V[i]}" >> $NEW
   fi
   if [[ "${V[i]}" =~ HardDisk.List.1-1 ]];
   then
      echo "${V[i]}" >> $NEW1
   fi
   echo "${V[i]}" >> $NEW2
done
egrep NIC.Integrated.1-1-1 $NEW 
if  [ $? = 0 ]; then 
   egrep NIC.Integrated.1-1-1 $NEW > $NEWORDER 
else
   egrep NIC.Integrated.1-1-1 $NEW1 > $NEWORDER
fi
egrep "NIC.ChassisSlot.1|3|5|7-1-1" $NEW
if [ $? = 0 ]; then
   egrep "NIC.ChassisSlot.1|3|5|7-1-1" $NEW >> $NEWORDER
elif [ $? = 1 ]; then
   egrep "NIC.ChassisSlot.1|3|5|7-1-1" $NEW1 >> $NEWORDER
fi
egrep "NIC.ChassisSlot.2|4|6|8-1-1" $NEW
if [ $? = 0 ]; then
   egrep "NIC.ChassisSlot.2|4|6|8-1-1" $NEW >> $NEWORDER
elif [ $? = 1 ]; then
   egrep "NIC.ChassisSlot.2|4|6|8-1-1" $NEW1 >> $NEWORDER
fi
egrep HardDisk.List.1-1 $NEW 
if [ $? = 0 ]; then
   egrep HardDisk.List.1-1 $NEW >> $NEWORDER
else
   egrep HardDisk.List.1-1 $NEW1 >> $NEWORDER
fi
cat $NEWORDER
cat $NEW2 |egrep -v "HardDisk.List.1-1|NIC.ChassisSlot.[1|3|5|7]-1-1|NIC.ChassisSlot.[2|4|6|8]-1-1|NIC.Integrated.1-1-1" >> $NEW3
cat -v $NEW3 | grep -v "\^M" >> $NEW4
cat $NEW4 >> $NEWORDER
paste -d, -s $NEWORDER > $NEWORDER_FINAL
sed -i -e 's/^/\ /g' $NEWORDER_FINAL
FINAL=$(cat $NEWORDER_FINAL)
}

# Start MAIN function
MAIN() {
   RMFILES
   GETSET
   REORDERBOOTSEQUENCE
   SETBOOT
   SETJOB
   SETPOWER
}
# End MAIN function
## End Functions

# Start 
# Is expect present?
if [ ! -f /usr/bin/expect ]; then
   echo "expect not found. We need it to run this script"
   echo "exiting..."
   exit 1
fi
# Arg check
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <ip addresses and/or hostnames separated by space>" >&2
  exit 1
fi
for ip in $IP_LIST ; do
   echo "$ip" >> $LOG
   # Does the ip respond to ping requests?
   PING
   if [ $? = 0 ]; then
      MAIN
   # Are we blocked from issuing ping requests?
   # If so, use nmap to check ssh port status.
   elif [ $? = 1 ]; then
     # Check if nmap is present
     if [ ! -f /usr/bin/nmap ]; then
        echo "nmap is not found" 
        echo "nmap is not found" >> $LOG
        echo "I cannot use nmap to check ssh port state" >> $LOG
     fi
     echo "" >> $LOG
     echo "$ip is not responding to ping requests. Trying nmap." | tee -a $LOG
     echo "" >> $LOG
     STATE=$(nmap $ip -PN -p ssh | egrep 'open|closed|filtered' | awk '{print $2}')
     case "$STATE" in
        "open")
           MAIN
           ;;
        "filtered")
           echo "ssh port is in $STATE state" >> $LOG
           ;;
        "closed")
           echo "ssh port is in $STATE state" >> $LOG
           ;;
        *)
           echo "Unknown ssh port state: $STATE" >> $LOG
     esac
   fi
done
echo "Log file is located here: ${LOG}"
