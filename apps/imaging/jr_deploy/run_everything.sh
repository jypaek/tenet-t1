#!/bin/bash

echo ""
echo "######### Run Tenet/Cyclops JR Deployment Applications #########"
echo ""
date

echo "[RUN_ALL] Running SCP & MV (run_scp_n_mv.sh) "
gnome-terminal -x ./run_scp_n_mv.sh -s &

echo "[RUN_ALL] Running HTML update (run_update_htm.sh) "
gnome-terminal -x ./run_update_htm.sh -p data/ &

sleep 5
echo "[RUN_ALL] Running Tenet application (jr_deploy1) "
./jr_deploy1 > log_jr_deploy1.txt 2>&1 &

tail -f -n 50 log_jr_deploy1.txt


echo "[RUN_ALL] KILL ALL "
pkill run_scp_n_mv
pkill run_update_htm
pkill -SIGINT jr_deploy1
date

