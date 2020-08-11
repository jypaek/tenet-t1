#!/usr/bin/perl -s
#
#generate files for gnuplot
# usage thisScriptFileName int
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
print INFO "set output \"plot_str.png\"\n";
print INFO "plot ";

$i = 57;
while ($i <= 65)
{
    print INFO "\"ll$i.out\" w l t '', ";
    $i = $i + 1;
}
$i = 67;
while ($i <= 91)
{
    print INFO "\"ll$i.out\"w l t '', ";
    $i = $i + 1;
}
print INFO "\"ll1.out\" w l t ''";
print INFO "\n";
print INFO "quit\n";
close(INFO);
system("gnuplot $fileName");
#system("rm $fileName");
