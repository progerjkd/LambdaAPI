#!/bin/bash

CFG_FILE='dynamodb.cfg'

if [ -f ./$CFG_FILE ]; then
	. $CFG_FILE
else
	echo 'error: $CFG_FILE file not found!'
	exit 1
fi

COUNT=1

while [ $COUNT -le  ${#AWS_REGION[@]} ] ; do

    aws dynamodb delete-table --table-name ${TABLE_NAME} --region ${AWS_REGION[$COUNT]} --query 'TableDescription.{TableId:TableId}' --output text
    FORMATTED_MSG="Deleting DynamoDB table '${TABLE_NAME}' in Region '${AWS_REGION[$COUNT]}' and waiting for it to "
    FORMATTED_MSG+="become deleted.\n    Please BE PATIENT as this can take some "
    FORMATTED_MSG+="time to complete.\n    ......\n"
    printf "  $FORMATTED_MSG"
    FORMATTED_MSG="STATUS: %s  -  %02dh:%02dm:%02ds elapsed while waiting for table "
    FORMATTED_MSG+="become deleted..."
    SECONDS=0
    LAST_CHECK=0
    STATE='PENDING'
    until [[ $STATE == '' ]]; do
        INTERVAL=$SECONDS-$LAST_CHECK
        if [[ $INTERVAL -ge $CHECK_FREQUENCY ]]; then
		STATE=$(aws dynamodb describe-table --table-name ${TABLE_NAME} --region ${AWS_REGION[$COUNT]} \
			--query 'Table.TableStatus' --output text 2>/dev/null)
         STATE=$(echo $STATE | tr '[:lower:]' '[:upper:]')
         LAST_CHECK=$SECONDS
        fi
        SECS=$SECONDS
        STATUS_MSG=$(printf "$FORMATTED_MSG" \
         $STATE $(($SECS/3600)) $(($SECS%3600/60)) $(($SECS%60)))
        printf "    $STATUS_MSG\033[0K\r"
        sleep 1
    done
    printf "\n    ......\n  DynamoDB table '${TABLE_NAME} in Region '${AWS_REGION[$COUNT]}' is now DELETED.\n"
COUNT=$(echo $COUNT + 1 | bc)
done
