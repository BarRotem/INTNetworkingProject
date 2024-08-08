#!/bin/bash

#Script objectives :
#-------------------
#Implement a bash script in bastion_connect.sh that connects to the private instance using the public instance.
#Your script should expect an environment variable called KEY_PATH, which is a path to the .pem ssh key file.
#If the variable doesn't exist, it prints an error message and exits with code 5.

#Define static private key file path in bastion server
CURRENT_KEY_PATH="/home/ubuntu/.ssh/barrotem-private-instance-key"
#Define variables to be aliased to the passed in arguments. All variables are optional
bastion_ip=${1}
private_server_ip=${2}
command_to_run=${3}

#Escape bad scenarios.
if [[ -z ${KEY_PATH} ]]
then
  #KEY_PATH env var doesn't exist
  echo "Error : KEY_PATH env var doesn't exist"
  exit 5
elif [[ -z ${bastion_ip} ]]
then
  echo "Error : Please provide bastion IP address"
  exit 5
fi

#Execute operation according to required instructions
#Connect to required hosts based on passed-in arguments
if [[ -z ${private_server_ip} ]]
then
  ssh -i ${KEY_PATH} -t ubuntu@${bastion_ip}
  else
    ssh -i ${KEY_PATH} -t ubuntu@${bastion_ip} "ssh -i ${CURRENT_KEY_PATH} -t ubuntu@${private_server_ip} ${command_to_run}"
fi