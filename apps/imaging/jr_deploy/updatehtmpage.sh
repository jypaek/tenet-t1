#!/bin/bash

Help() {
    echo
    echo "Usage: $0 [options]"
    echo "options> "
    echo "  -p : set path to the image files (ex> ./data)"
    echo "  -f : set output html file name (default: viewer.html)"
    echo
    exit 1
}

# Variables
htmfilename="viewer.html"
path="."

while getopts p:f:h opt
do
    case "$opt" in

        p) path="$OPTARG";
           ;;
        f) htmfilename="$OPTARG";
           ;;
        h) Help;;
        \?) Help;;
    esac
done

motelist="101 102 103 104 105 106 107 108 109 110 111 112 113 114"
nummotes=0
arglist=""

#for i in $motelist
for i in `seq 101 120`
do
    motename=mote$i
    validstr=`ls -l --full-time $path | grep $motename | grep bmp | wc -l`
    for k in $validstr; do
        valid=$k
    done

    if [ $valid -ne 0 ]
    then
        let nummotes=$nummotes+1;

        #filename=`ls -t1 mote*.bmp | head -n 1`
        filename=`ls -ltr --full-time $path | grep $motename | grep bmp | awk '{print $9}' | tail -n 1`

        time1=`ls -ltr --full-time $path | grep $motename | grep bmp | awk '{print $6}' | tail -n 1`

        time2=`ls -ltr --full-time $path | grep $motename | grep bmp | awk '{print $7}' | tail -n 1`

        #arglist="$arglist $motename $path/$filename $time1&$time2"
        arglist="$arglist $motename $filename $time1&$time2"
    fi
    if [ $valid -gt 1 ]
    then
        let nummotes=$nummotes+1;

        #filename=`ls -t1 mote*.bmp | head -n 1`
        filename=`ls -ltr --full-time $path | grep $motename | grep bmp | awk '{print $9}' | tail -n 2 | head -n 1`

        time1=`ls -ltr --full-time $path | grep $motename | grep bmp | awk '{print $6}' | tail -n 2 | head -n 1`

        time2=`ls -ltr --full-time $path | grep $motename | grep bmp | awk '{print $7}' | tail -n 2 | head -n 1`

        #arglist="$arglist $motename $path/$filename $time1&$time2"
        arglist="$arglist $motename $filename $time1&$time2"
    fi
done

echo "./genhtmpage $htmfilename $nummotes $path $arglist > $htmfilename"
chmod 755 genhtmpage
./genhtmpage $htmfilename $nummotes $path $arglist > $htmfilename
echo "$htmfilename created."

