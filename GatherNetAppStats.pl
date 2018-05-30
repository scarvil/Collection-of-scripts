#!/usr/bin/perl -w

use NetApp::Filer;
use NetApp::Aggregate;
use NetApp::Volume;


$ENV{PATH} = "/usr/bin:/usr/sbin:/bin:/sbin";

### Edit the following line to include your netapp hostnames ###

my @hosts = ("hqflr01","hqflr02");

# Set login my 
$user = "root";

# For each host in the host list
foreach $hosts (@hosts) {
   # check aggreagete status
   my @lines = `/usr/bin/ssh -a $user\@$hosts 'aggr status'`;
   # Print host name
   print "Filer: $hosts\n\n";
   # Print aggregates on host
   print "Aggregates on $hosts\n";
   print "----------------------------------\n";
   # Print aggregate status
   print "@lines\n";
   # check vol status
   my @vol = `/usr/bin/ssh -a $user\@$hosts 'vol status'`;
   # Print vol status
   print "Volumes on $hosts\n";
   print "@vol\n";
   # Set host login
   my $filer       = NetApp::Filer->new({
   hostname        => $hosts,
   username        => "$user",
   });
   # Get aggregate names
   my @aggregate_names = $filer->get_aggregate_names;
   #print "@aggregate_names\n";
   # Go through each aggregate name and set the variable
   foreach my $aggregate (@aggregate_names){
       # ssh into the host and print aggregate space for each
       $_ = `/usr/bin/ssh -a $user\@$hosts 'aggr show_space $aggregate'`;
       print "$_\n";
   };
   # Get volume names
   my @volume_names  = $filer->get_volume_names;
   #print "@volume_names\n";
   # Print header
   print "Volume sizes:\n";
   print "----------------------------------\n";
   # Go through each volume and print sizes
   foreach my $volume (@volume_names) {
       # ssh into the host and print vol size for each volume
       $_ = `/usr/bin/ssh -a $user\@$hosts 'vol size $volume'`;
       print "$_\n";
   };
   # Print sysconfigs
   print "Sysconfigs :\n";
   print "----------------------------------\n";
   my @sysconfigrv = `/usr/bin/ssh -a $user\@$hosts 'sysconfig -r ; sysconfig -v'`;
   print "@sysconfigrv\n";

   # Print iscsi stats
   print "Iscsi Stats :\n";
   print "----------------------------------\n";
   my @iscsistats = `/usr/bin/ssh -a $user\@$hosts 'iscsi stats'`;
   print "@iscsistats\n";
};

