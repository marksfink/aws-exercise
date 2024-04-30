#!/bin/bash
source /home/bitnami/.mongodb/mongo_backups

MONGO_CONNECTION_STRING="mongodb://$MONGO_USER:$MONGO_PASS@localhost:27017"

DATE=$(date "+%Y-%m-%d")
mkdir -p $BACKUP_ROOT_FOLDER/$DATE

mongodump --uri=$MONGO_CONNECTION_STRING --out $BACKUP_ROOT_FOLDER/$DATE

aws s3 sync $BACKUP_ROOT_FOLDER s3://$S3_BUCKET

find $BACKUP_ROOT_FOLDER -type d -mtime +30 -exec rm -rf {} \;
