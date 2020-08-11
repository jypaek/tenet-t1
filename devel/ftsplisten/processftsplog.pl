#!/usr/bin/perl
#
# Extract useful info from 'ftsplisten' output log file.
#
# Usage: ./processftsplog.pl logfile
#
# Jeongyeup Paek

use Getopt::Long;

$gfilename = "gplot.g";
$figname1   = "imageerrorplot.png";
$figname2   = "imagetimeplot.png";
$croot = undef;

GetOptions(
            'a=i' => \$croot,
            'f=s'=> \$figname1,
            );
$logfile = shift || '.';

open(INFO, $logfile) or die "Can't open $logfile";          # Open the file for input

# read the whole log file, parse it, and put it into an array with 'msgId' at first column.
while ($line = <INFO>)
{
    $_ = $line;
    if (/\[(\d+)\]\s+node\s+(\d+)\s+gtime\s+(\d+)\s+\(\s*(\d+)\) sync (\d) root\s+(\d+) skew\s+([-+]?[0-9]*\.?[0-9]+)\s+seqNo\s+(\d+)/gi) {
        # read each line in the log file
        ($msgId, $nodeid, $gtime, $ltime, $sync, $root, $skew, $seqno) = ($1, $2, $3, $4, $5, $6, $7, $8);
        $line =~ /(\d+):(\d+):(\d+)/gi;
        ($hour, $min, $sec) = ($1, $2, $3);
        if ($ltime != 0) {
            push (@data1, "$msgId $nodeid $gtime $sync $root $skew $seqno $hour:$min:$sec ");
        }
    }
}
close(INFO);


# sort data1 by 'msgId' so that we can do some calculation
@data1 = sort{$a <=> $b}(@data1);     # {$a <=> $b} performs sorting by numerical value


# process the data that has been sorted by msgId

open(TFILE, ">__outx.tmp") or die "Can't open __outx.tmp";
$first_msgId = 0;   # first reference broadcast id
$prev_msgId = 0;    # last reference broadcast id
$ref_time = 0;      # last g-time of the first response to a ref.bcast
$totcnt = 0; $toterrsum = 0; $toterrmax = 0;   # stats to all data (totcnt excludes first reply per msgId)
$subcnt = 0; $suberrsum = 0; $suberrmax = 0;   # stats within a ref.bcast id
$poscnt = 0; $poserrsum = 0; $poserrmax = 0;   # stats of positive error
$negcnt = 0; $negerrsum = 0; $negerrmax = 0;   # stats of negative error
$totcnt2 = 0;       # total number of replies, including the ones from root
$prev_nodeid = 0;

for $line (@data1) {                # read the array
    ($msgId, $nodeid, $gtime, $sync, $root, $skew, $seqno, $pctime) = split(/ +/, $line, 8);

    if ($first_msgId == 0) {        # rememeber the first msgId in the log file
        $first_msgId = $msgId - 1;  # make sure that we don't start with 0
    }
    $msgId -= $first_msgId;         # let's subtract first Id so that plot x-axis starts at 0

    if ($msgId != $prev_msgId) {    # end of last msgId
        if ($prev_msgId != 0) {     # end of last msgId (not beginning of loop)
            if ($subcnt != 0) {
                $subavg = $suberrsum/$subcnt;
                print TFILE ("$pctime $prev_msgId $subavg $suberrmax \n");
            }
        }
        $prev_nodeid = 0;
        $err = 0;                   # err==0 since this is the reference
        $prev_msgId = $msgId;       # start of new msgId
        $ref_time = $gtime;         # this is the reference time to calculate err
        $subcnt = 0; $suberrsum = 0; $suberrmax = 0;
    } else {
        if ($prev_nodeid == $nodeid) {  # duplicate line suppresion
            next;
        }
        $prev_nodeid = $nodeid;
        $err = $gtime - $ref_time;
        $abserr = abs($err);
        $toterrsum += $abserr; $totcnt++;
        $suberrsum += $abserr; $subcnt++; 
        if ($abserr > $toterrmax) { $toterrmax = $abserr; }
        if ($abserr > $suberrmax) { $suberrmax = $abserr; }
        if ($err > 0) {
            $poserrsum += $err; $poscnt++;
            if ($err > $poserrmax) { $poserrmax = $err; }
        } else {
            $negerrsum += $err; $negcnt++;
            if ($err < $negerrmax) { $negerrmax = $err; }
        }
    }
    push (@data2, "$nodeid $msgId $gtime $err $sync $root $skew $seqno $pctime ");
    $totcnt2++;
}
if ($subcnt != 0) {
    $subavg = $suberrsum/$subcnt;
    print TFILE ("$pctime $prev_msgId $subavg $suberrmax\n");
}
close(TFILE);


### sort data by 'nodeId' so that we can plot per node
@data2 = sort{$a <=> $b}(@data2);    # {$a <=> $b} performs sorting by numerical value
#@data2 = sort(@data2);              # without that, sorting is by string comparison of ASCII


$nodecnt = 0;       # how many nodes? (how many output files?)
$lastnode = 0;
$nodemsgcnt = 0; $nodeerrsum = 0; $nodeerrmax = 0;   # stats within a node

for $line (@data2) {                # read the array
    ($nodeid, $msgId, $gtime, $err, $sync, $root, $skew, $seqno, $pctime) = split(/ +/, $line, 9);
    if ($nodeid != $lastnode) {     # start or end of a node
        if ($lastnode != 0) {       # end of a node, assuming there is no nodeid 0
            close(NFILE);           # close outfile for a node
            printf("node %2d msgcnt %3d avgerr %5.2f maxerr %3d\n", 
                    $lastnode, $nodemsgcnt, $nodeerrsum/$nodemsgcnt, $nodeerrmax);
        }                           # now, starting a new node
        $lastnode = $nodeid;        # starting a outfile for a new node
        $nodemsgcnt = 1;            # start counting num msg's for this node
        $nodeerrsum = abs($err);    # sum of errors
        $nodeerrmax = abs($err);    # max error
        $nodecnt++;                     # number of nodes, number of outfiles
        $outfile  = "__out$nodecnt.tmp";    # per-node outfile
        open(NFILE, ">$outfile") or die "Can't open $outfile";
        push (@idlist, $nodeid);
    } else {                        # update stats for this node
        $nodemsgcnt++;
        $nodeerrsum += abs($err);
        if (abs($err) > $nodeerrmax) { $nodeerrmax = abs($err); } 
    }
    print NFILE ("$pctime $msgId $nodeid $gtime $err $sync $skew\n");
}
close(NFILE);
printf("node %2d msgcnt %3d avgerr %5.2f maxerr %3d\n", 
        $lastnode, $nodemsgcnt, $nodeerrsum/$nodemsgcnt, $nodeerrmax);

if ($poscnt == 0) { $poscnt = 1; }
if ($negcnt == 0) { $negcnt = 1; }
printf("============================================================================\n");
printf("TOTAL: nodes %3d  pkts %4d  avgerr %.2f  maxerr %2d  (%.1f/%.1f) (%2d/%2d)\n\n", 
            $nodecnt, $totcnt2, $toterrsum/$totcnt, $toterrmax,
            $poserrsum/$poscnt, $negerrsum/$negcnt, $poserrmax, $negerrmax);


#########################################
# generate time vs. timesync-error plot
#########################################
open(GPTR, ">$gfilename");
#print GPTR "set xlabel \"reference broadcast id (every 10sec)\" \n";
print GPTR "set ylabel \"timesync error (1/32768 sec)\"\n";
print GPTR "set title \"Timesync error vs. time plot\"\n";
print GPTR "set term postscript enhanced color lw 3 \"Times-Roman\" 16\n";
print GPTR "set output \"$figname1.eps\"\n";
print GPTR "set pointsize 1\n";
print GPTR "set grid\n";
#print GPTR "set key off\n";
print GPTR "set size 1.0,1.0\n";
print GPTR "set yrange [-$toterrmax-3:$toterrmax+3]\n";
print GPTR "set timefmt \"%H:%M:%S\"\n";
print GPTR "set xdata time\n";
print GPTR "set format x \"%H:%M\"\n";
print GPTR "plot ";
print GPTR "'__outx.tmp' u 1:4 w l lw 2 title 'max err', ";     # MAX
print GPTR "'__outx.tmp' u 1:3 w l lw 2 title 'avg err', ";     # AVG
print GPTR "'__out1.tmp' u 1:5 w l lw 3 notitle, ";             # root (first responder)

# We start from 2 ==> not plot the root!
for ($i = 2; $i <= $nodecnt; $i++) {
    #print GPTR "'__out$i.tmp' u 1:5 w lp pt 2 title 'node $idlist[$i-1]'";
    print GPTR "'__out$i.tmp' u 1:5 w lp pt 2 title ''";
    if ($i < $nodecnt) {
        print GPTR ", ";
    }
}
close(GPTR);

# Do the plot
system("gnuplot $gfilename");
system("convert -rotate 90 $figname1.eps $figname1");
system("rm $figname1.eps");
system("rm $gfilename");


###############################################
# generate msgId vs. (pkt reception)nodeid plot
###############################################
open(GPTR, ">$gfilename");
#print GPTR "set xlabel \"reference broadcast id (every 10sec)\" \n";
print GPTR "set ylabel \"nodeid\"\n";
print GPTR "set title \"time vs. pkt reception nodeid\"\n";
print GPTR "set term postscript enhanced color lw 3 \"Times-Roman\" 16\n";
print GPTR "set output \"$figname2.eps\"\n";
print GPTR "set pointsize 1\n";
print GPTR "set size 1.0,1.0\n";
print GPTR "set timefmt \"%H:%M:%S\"\n";
print GPTR "set xdata time\n";
print GPTR "set format x \"%H:%M\"\n";
print GPTR "plot \'$logfile\' u 1:4\n";
##print GPTR "plot ";
##for ($i = 1; $i <= $nodecnt; $i++) {
##    print GPTR "'__out$i.tmp' u 1:3 w lp pt 2 notitle ";
##    if ($i < $nodecnt) {
##        print GPTR ", ";
#3    }
##}
close(GPTR);

# Do the plot
system("gnuplot $gfilename");
system("convert -rotate 90 $figname2.eps $figname2");
system("rm $figname2.eps");
system("rm $gfilename");


# delete all temporary files
system("rm __out*.tmp");

