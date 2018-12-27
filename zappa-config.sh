#!/bin/bash

if [ -f ./aws.cfg ]; then
	. aws.cfg
else
	echo 'error: aws.cfg file not found!'
	exit 1
fi

CFG_FILE='code/zappa_settings.json'
RANDOM_STR1=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 9 | head -n 1)
RANDOM_STR2=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 9 | head -n 1)

echo "{
    \"production\": {
        \"app_function\": \"main.app\",
        \"aws_region\": \"${REGION[1]}\",
        \"profile_name\": \"default\",
        \"project_name\": \"flaskapi\",
        \"runtime\": \"python3.6\",
        \"s3_bucket\": \"zappa-${RANDOM_STR1}\",
        \"extra_permissions\": [{
            \"Effect\": \"Allow\",
            \"Action\": [\"dynamodb:*\"],
            \"Resource\": \"*\"
        }],
        \"vpc_config\": {
            \"SubnetIds\": [ \"${SUBNET_PRIVATE_ID[0,0]}\", \"${SUBNET_PRIVATE_ID[0,1]}\" ],
            \"SecurityGroupIds\": [ \"${SG_ID[1]}\" ]
        }
    },
    \"production_$(echo ${REGION[2]} | sed s/-/_/g )\": {
        \"aws_region\": \"${REGION[2]}\",
        \"s3_bucket\": \"zappa-${RANDOM_STR2}\",
        \"vpc_config\": {
            \"SubnetIds\": [ \"${SUBNET_PRIVATE_ID[1,0]}\", \"${SUBNET_PRIVATE_ID[1,1]}\" ],
            \"SecurityGroupIds\": [ \"${SG_ID[2]}\" ]
        },
        \"extends\": \"production\"
    }
}" > $CFG_FILE
