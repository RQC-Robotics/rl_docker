#!/bin/bash

if [[ $1 == "" ]] 
 then
 echo "The first argument should be the name of the archive in Yandex Cloud with demos or skip_demos to skip downloading demos."
 sleep 500
elif [[ $1 == "skip_demos" ]] 
 then
 echo "Skipping downloading demos."
else  
 echo "Downloading demo files: $1."
 wget -c --no-check-certificate https://rl-docker.storage.yandexcloud.net/c2farm/$1 && unzip -o ./$1 -d ./demos && rm ./$1
fi

source activate c2farm-conda
pkill -f Xorg
nohup bash -c 'nohup X &' > /dev/null 2>&1
nohup bash -c 'nohup tensorboard --host 0.0.0.0 --logdir ./ARM/logdir/ &' > /dev/null 2>&1
cd ./ARM
python launch.py method=C2FARM rlbench.task=take_lid_off_saucepan rlbench.demo_path=/home/jupyter/c2farm/demos/myDemoKinect framework.gpu=0
