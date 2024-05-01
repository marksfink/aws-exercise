#!/bin/bash

source /home/bitnami/.mongodb/mongo_backups

#TODO: extract this from /home/bitnami/bitnami_credentials with a regex
read -sp "Root password: " password
echo
mongosh admin --username root --password $password --eval "var username='$MONGO_USER', password='$MONGO_PASS'" --file /usr/local/bin/mongo_config.js
