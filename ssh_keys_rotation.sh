#!/bin/bash

#Rotates the keys of the private instance
CURRENT_KEY_PATH="/home/ubuntu/.ssh/barrotem-private-instance-key"
ROLLED_KEY_PATH="/home/ubuntu/.ssh/barrotem-private-instance-key-rolled"
private_server_ip=${1}

if [[ -z private_server_ip ]]
then
  echo "Error : Private server ip unspecified."
  exit 1
else
  #Create new keyfile, overriding the previous one, redirecting output to /dev/null
  ssh-keygen -q -f ${ROLLED_KEY_PATH} -N "" -t rsa <<< y > /dev/null
  scp -q -i ${CURRENT_KEY_PATH} "${ROLLED_KEY_PATH}.pub" ubuntu@${private_server_ip}:"${ROLLED_KEY_PATH}.pub" #Copy new public key to private instance
  ssh -i ${CURRENT_KEY_PATH} ubuntu@${private_server_ip} "cat ${ROLLED_KEY_PATH}.pub > ~/.ssh/authorized_keys" #Perform key rotation in public instance. ssh session will be disconnected.
  cp ${ROLLED_KEY_PATH} ${CURRENT_KEY_PATH} #We're back to the public instance. Set current key to the rolled key.
fi