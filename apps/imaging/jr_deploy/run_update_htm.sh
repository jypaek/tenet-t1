#!/bin/bash

Help() {
    echo
    echo "Usage: $0 [options]"
    echo "options> "
    echo "  -t : set time interval in seconds"
    echo "  -p : set path to the image files"
    echo
    exit 1
}

if [ $# -gt 5 ]
then
    Help
    exit 1
fi

# Variables
sec=10
path=""

while getopts t:p:h opt
do
    case "$opt" in

        t) sec="$OPTARG";
           ;;
        p) path="-p $OPTARG";
           ;;
        h) Help;;
        \?) Help;;
    esac
done

echo ""
echo "Run updatehtmpage.sh every $sec sec, with path \"$path\""
sleep 5

oldnum=0

while [ 1 ]
do
    #./updatehtmpage.sh
    
    newnum=`ls -t1 $path | grep mote[0123456789] | grep bmp | wc -l`
    if [ "$oldnum" != "$newnum" ]
    then
        date
        ./updatehtmpage.sh "$path"
        oldnum=$newnum
        echo "total number of bmp files = $newnum"
        play /usr/share/sounds/phone.wav > /dev/null 2>&1
    fi

    sleep $sec
done

