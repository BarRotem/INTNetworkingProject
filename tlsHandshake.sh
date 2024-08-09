#!/bin/bash
#Implement all 6 steps of (simplified) TLS Handshake !
#Avoid bad code invocations   :
server_ip=${1}
if [[ -z ${server_ip} ]]
then
  echo "Error : Unspecified server ip. Cannot start TLS handshake"
  exit 1
fi

#Define constants
LISTENING_PORT=8080

#Step 1 - Client Hello
endpoint="clienthello"
payload='{"version": "1.3","ciphersSuites": ["TLS_AES_128_GCM_SHA256","TLS_CHACHA20_POLY1305_SHA256"], "message": "Client Hello"}'

echo -e "\nStep 1 : Perform Client Hello\n-----------------------------"
#Check status code of Client Hello. Continue TLS Handshake only for code 200.
status_code=$(curl -s -w '%{http_code}' -X POST ${server_ip}:${LISTENING_PORT}/${endpoint} -H "Content-Type: application/json" -d "${payload}" -o server_hello.txt)
if [[ ${status_code} -ne 200 ]]
then
  echo "Client Hello : Failure"
  exit 1
fi

echo "Client Hello : Success"

#Step 2 - Server Hello
echo -e "\nStep 2 : Receive Server Hello\n-----------------------------"
#We are here only if code is 200, meaning client hello succeeded.
#FIX:curl only once to the server.curl -s -X POST ${server_ip}:${LISTENING_PORT}/${endpoint} -H "Content-Type: application/json" -d "${payload}" -o server_hello.txt
cat server_hello.txt
#Extract relevant elements from server_hello.txt to be used later.
SESSION_ID=$(jq '.sessionID' server_hello.txt)
jq '.serverCert' server_hello.txt > cert.pem
#Re-evaluate cert.pem, so it's saved in its pure form.
raw_cert=$(cat cert.pem)
raw_cert=${raw_cert#\"}
raw_cert=${raw_cert%\"}
printf "%b" "${raw_cert}" > cert.pem

echo -e "\n\nServer Hello : Received. Relevant information stored in $(pwd)"

#Step 2 - Server Certificate Verification
echo -e "\nStep 3 : Server Certificate Verification\n----------------------------------------"
wget -q https://exit-zero-academy.github.io/DevOpsTheHardWayAssets/networking_project/cert-ca-aws.pem
openssl verify -CAfile cert-ca-aws.pem cert.pem
if [[ $? -eq 0 ]]
then
  echo "Server Certificate Verification : Server Certificate is VALID !"
else
  echo "Server Certificate Verification : Server Certificate is invalid."
  echo "Eavesdropper might be listening, aborting Handshake."
  exit 5
fi

echo -e "\nStep 4 : Client-Server master-key exchange\n------------------------------------------"
#Generate random 32 Bytes base64 string, to be used as the master key for encrypted communication.
openssl rand --base64 32 > master-key.txt
#Encrypt the master key using the server's certificate (public key).
openssl smime -encrypt -aes-256-cbc -in master-key.txt -outform DER cert.pem | base64 -w 0 > master-key-enc.txt
#Define veriables
master_key=$(cat master-key.txt)
master_key_enc=$(cat master-key-enc.txt)
sample_message="Hi server, please encrypt me and send to client!"

endpoint="keyexchange"
payload="{\"sessionID\": ${SESSION_ID},\"masterKey\": \"${master_key_enc}\",\"sampleMessage\": \"${sample_message}\"}"
#Send the encrypted data to the server
echo -e "Sending the following payload to the server : ${payload}"
status_code=$(curl -s -w '%{http_code}' -X POST ${server_ip}:${LISTENING_PORT}/${endpoint} -H "Content-Type: application/json" -d "${payload}" -o master-key-exchange-response.txt)
#Check master-key exchange status code
if [[ ${status_code} -ne 200 ]]
then
  echo "Master-key exchange failed."
  exit 4
fi

#We are here if master-key exchange has succeeded !
echo "Master-key exchange Succeeded !"
#FIX:curl only once to the server.curl -s -X POST ${server_ip}:${LISTENING_PORT}/${endpoint} -H "Content-Type: application/json" -d "${payload}" -o master-key-exchange-response.txt

echo -e "\nStep 5&6 : Client message verification\n---------------------------------------"
#Master-key exchange succeeded. Or has it?
#The client must now verify that the message responded by the server, is indeed equal to the plaintext message is has encrypted.
#Define variables
master_key_exchange_response=$(cat master-key-exchange-response.txt)
echo -e "Received the following response from the server:\n${master_key_exchange_response}"
#Recollect encoded message
jq '.encryptedSampleMessage' master-key-exchange-response.txt > encrypted-sample-message-encoded.txt
#Base64 decode the message
enc_sample_decoded=$(cat encrypted-sample-message-encoded.txt)
enc_sample_decoded=${enc_sample_decoded#\"}
enc_sample_decoded=${enc_sample_decoded%\"}
echo ${enc_sample_decoded} | base64 -d > encrypted-sample-message-decoded.txt
cat encrypted-sample-message-decoded.txt | openssl enc -d -aes-256-cbc -pbkdf2 -kfile master-key.txt > server-sample-message-decrypted.txt
#Verify message equality
server_sample_message_dec=$(cat server-sample-message-decrypted.txt)
echo "Received the following sampleMessage from server : ${server_sample_message_dec}"
if [[ ${server_sample_message_dec} = ${sample_message} ]]
then
  echo "Client-Server TLS handshake has been completed successfully!"
else
  echo "Server symmetric encryption using the exchanged master-key has failed."
  exit 6
fi