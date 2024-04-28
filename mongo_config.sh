#!/bin/bash

source /home/bitnami/.mongodb/mongo_backups

#TODO: extract this from bitnami_credentials with a regex
read -sp "Root password: " password
echo
mongosh admin --username root --password $password --eval "var username='$MONGO_USER', password='$MONGO_PASS'" --file mongo_config.js
