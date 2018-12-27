#!/bin/bash

AWS_REGION1='us-east-1'
AWS_REGION2='us-east-2'
TABLE_NAME='Users'
CFG_FILE='dynamodb.cfg'

# Creates table in $AWS_REGION1
TABLE_ID[1]=$(aws dynamodb create-table --table-name ${TABLE_NAME} --attribute-definitions AttributeName=name,AttributeType=S \
	--key-schema AttributeName=name,KeyType=HASH --provisioned-throughput ReadCapacityUnits=10,WriteCapacityUnits=5 \
	--stream-specification StreamEnabled=true,StreamViewType=NEW_AND_OLD_IMAGES --query 'TableDescription.{TableId:TableId}' \
	--output text --region ${AWS_REGION1})
echo "  DynamoDB table '$TABLE_NAME' id '${TABLE_ID[1]}' CREATED in Region '$AWS_REGION1'."

# Creates an identical table in $AWS_REGION2
TABLE_ID[2]=$(aws dynamodb create-table --table-name ${TABLE_NAME} --attribute-definitions AttributeName=name,AttributeType=S \
	--key-schema AttributeName=name,KeyType=HASH --provisioned-throughput ReadCapacityUnits=10,WriteCapacityUnits=5 \
	--stream-specification StreamEnabled=true,StreamViewType=NEW_AND_OLD_IMAGES --query 'TableDescription.{TableId:TableId}' \
	--output text --region ${AWS_REGION2})
echo "  DynamoDB table '$TABLE_NAME' id '${TABLE_ID[2]}' CREATED in Region '$AWS_REGION2'."

# Sets the table global between the two AWS Regions
GLOBAL_ARN=$(aws dynamodb create-global-table --global-table-name=${TABLE_NAME} --replication-group RegionName=${AWS_REGION1} RegionName=${AWS_REGION2} \
	--query 'GlobalTableDescription.{GlobalTableArn:GlobalTableArn}' --output text --region ${AWS_REGION1})
echo "  DynamoDB global table '$TABLE_NAME' arn '$GLOBAL_ARN' CREATED in Regions '$AWS_REGION1','$AWS_REGION2'."

> $CFG_FILE

echo "TABLE_NAME=\"${TABLE_NAME}\"" >> $CFG_FILE
echo "TABLE_ID[1]=\"${TABLE_ID[1]}\"" >> $CFG_FILE
echo "AWS_REGION[1]=\"${AWS_REGION1}\"" >> $CFG_FILE
echo "TABLE_ID[2]=\"${TABLE_ID[2]}\"" >> $CFG_FILE
echo "AWS_REGION[2]=\"${AWS_REGION2}\"" >> $CFG_FILE
echo "GLOBAL_ARN=\"${GLOBAL_ARN}\"" >> $CFG_FILE
