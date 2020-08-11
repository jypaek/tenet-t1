#!/usr/bin/perl -s
#
#generate files for gnuplot
#usage thisScriptFileName int
#

$baseName="generateGraphics";

$fileName="$baseName.p";

$i = 0;

open(INFO, ">$fileName");

#print "$fileName\n";
#print "plot processed$i.dat\n";
print INFO "set xlabel \"Time(s)\"\n";
print INFO "set ylabel \"Packet sequence number\"\n";
#print INFO "set title \"Receiver $i\"\n";
print INFO "set term png\n";
print INFO "set output \"plot_trr.png\"\n";
print INFO "plot ";

$i = 2;
while ($i <= 55)
{
    print INFO "\"trr_$i.out\" u 2:1 w l t '', ";
    $i = $i + 1;
}
print INFO "\"trr_$i.out\" u 2:1 w l t ''";
print INFO "\n";
print INFO "quit\n";
close(INFO);
system("gnuplot $fileName");
#system("rm $fileName");
