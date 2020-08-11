#!/bin/bash

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 [minutes] [num_nodes]"
    exit 1;
fi

echo ""
echo "Run jr_deploy2 every $1 min, expect $2 images"

sec=$[$1*60]
sec=$[$sec-30]
num=$2
run_count=1

sleep 5

while [ 1 ]
do
    date
    echo "running jr_deploy2 -s (#$run_count) (and wait for $sec sec)"
    ./jr_deploy2 -s -e $num &

    sleep $sec

    # kill the application
    # make sure that you are not kill this script!!!
    echo "stopping jr_deploy2 -s (#$run_count)"
    pkill -SIGINT jr_deploy2
    
    sleep 29
    run_count=`expr $run_count + 1`;
done

