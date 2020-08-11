#!/bin/bash

Help() {
    echo
    echo "Usage: $0 [options]"
    echo "options> "
    echo "  -t <sec>  : set time interval in seconds"
    echo "  -p <path> : set path to move the image files to (default: ./data)"
    echo "  -s        : set path to the image files"
    echo
    exit 1
}

if [ $# -gt 6 ]
then
    Help
    exit 1
fi

# Variables
sec=10
path="./data"
scp_enable=0

while getopts t:p:sh opt
do
    case "$opt" in

        t) sec="$OPTARG";
           ;;
        p) path="$OPTARG";
           ;;
        s) scp_enable=1;
           ;;
        h) Help;;
        \?) Help;;
    esac
done

echo ""
if [ $scp_enable -eq 1 ]; then
    echo "scp (to enl) and move (to $path) bmp files every $sec sec"
else
    echo "move (to $path) bmp files every $sec sec"
fi
sleep 5

while [ 1 ]
do
    #num=`ls -t1 mote*.bmp | wc -l`
    num=`ls -t1 | grep mote[0123456789] | grep bmp | wc -l`
    if [ "$num" != "0" ]; then
    	sleep $sec
        date
        if [ $scp_enable -eq 1 ]; then
            scp -p mote*.bmp jpaek@enl.usc.edu:~/public_html/data/cyclops/images/
        fi
        mv mote*.bmp $path
    else
    	sleep $sec
    fi
    sleep $sec

done

