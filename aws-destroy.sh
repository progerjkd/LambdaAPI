#!/bin/bash

CFG_FILE='aws.cfg'

if [ -f ./$CFG_FILE ]; then
	. $CFG_FILE
else
	echo 'error: $CFG_FILE file not found!'
	exit 1
fi

COUNT=1

while [ $COUNT -le ${#REGION[@]} ] ; do
    echo -e "Using Region: \e[1m\e[32m${REGION[${COUNT}]}\e[0m"

    # Delete NAT Gateway
    aws ec2 delete-nat-gateway --nat-gateway-id ${NAT_GW_ID[${COUNT}]} --output text --region ${REGION[${COUNT}]}
    FORMATTED_MSG="Deleting NAT Gateway ID '${NAT_GW_ID[${COUNT}]}' and waiting for it to "
    FORMATTED_MSG+="become deleted.\n    Please BE PATIENT as this can take some "
    FORMATTED_MSG+="time to complete.\n    ......\n"
    printf "  $FORMATTED_MSG"
    FORMATTED_MSG="STATUS: %s  -  %02dh:%02dm:%02ds elapsed while waiting for NAT "
    FORMATTED_MSG+="Gateway to become deleted..."
    SECONDS=0
    LAST_CHECK=0
    STATE='PENDING'
    until [[ $STATE == 'DELETED' || $STATE == '' ]]; do
        INTERVAL=$SECONDS-$LAST_CHECK
        if [[ $INTERVAL -ge $CHECK_FREQUENCY ]]; then
         STATE=$(aws ec2 describe-nat-gateways \
           --nat-gateway-ids ${NAT_GW_ID[${COUNT}]} \
           --query 'NatGateways[*].{State:State}' \
           --output text \
           --region ${REGION[${COUNT}]})
         STATE=$(echo $STATE | tr '[:lower:]' '[:upper:]')
         LAST_CHECK=$SECONDS
        fi
        SECS=$SECONDS
        STATUS_MSG=$(printf "$FORMATTED_MSG" \
         $STATE $(($SECS/3600)) $(($SECS%3600/60)) $(($SECS%60)))
        printf "    $STATUS_MSG\033[0K\r"
        sleep 1
    done
    printf "\n    ......\n  NAT Gateway ID '${NAT_GW_ID[${COUNT}]}' is now DELETED.\n"

    # Release EIP
    aws ec2 release-address --allocation-id ${EIP_ALLOC_ID[${COUNT}]} --region ${REGION[${COUNT}]}
    echo "  Elastic IP address ID '${EIP_ALLOC_ID[$COUNT]}' RELEASED."

    INTERFACE_ID=$(aws ec2 describe-network-interfaces --query 'NetworkInterfaces[*].NetworkInterfaceId' --filters Name=group-id,Values=${SG_ID[$COUNT]} --output text --region ${REGION[${COUNT}]})
    INTERFACE_ATTACHMENT_ID=$(aws ec2 describe-network-interfaces --query 'NetworkInterfaces[0].Attachment.AttachmentId' --filters Name=group-id,Values=${SG_ID[$COUNT]} --output text --region ${REGION[${COUNT}]})

    aws ec2 detach-network-interface --attachment-id ${INTERFACE_ATTACHMENT_ID} --region ${REGION[${COUNT}]}

    FORMATTED_MSG="Detaching Network Interface '${INTERFACE_ID}' from AWS Lambda Security Group '${SG_ID[$COUNT]}'"
    FORMATTED_MSG+="\n    Please BE PATIENT as this can take some "
    FORMATTED_MSG+="time to complete.\n    ......\n"
    printf "  $FORMATTED_MSG"
    FORMATTED_MSG="STATUS: %s  -  %02dh:%02dm:%02ds elapsed while waiting for Detaching "
    FORMATTED_MSG+="to become completed..."
    SECONDS=0
    LAST_CHECK=0
    STATE='PENDING'
    until [[ $STATE == 'NONE' ]]; do
        INTERVAL=$SECONDS-$LAST_CHECK
        if [[ $INTERVAL -ge $CHECK_FREQUENCY ]]; then
         STATE=$(aws ec2 describe-network-interfaces \
             --query 'NetworkInterfaces[0].Attachment.Status' \
             --filters Name=group-id,Values=${SG_ID[$COUNT]} \
             --output text --region ${REGION[${COUNT}]})
         STATE=$(echo $STATE | tr '[:lower:]' '[:upper:]')
         LAST_CHECK=$SECONDS
        fi
        SECS=$SECONDS
        STATUS_MSG=$(printf "$FORMATTED_MSG" \
         $STATE $(($SECS/3600)) $(($SECS%3600/60)) $(($SECS%60)))
        printf "    $STATUS_MSG\033[0K\r"
        sleep 1
    done
    printf "\n    ......\n  Interface attachment ID '${INTERFACE_ATTACHMENT_ID}' is now DELETED.\n"

    # Delete ENI
    aws ec2 delete-network-interface --network-interface-id ${INTERFACE_ID} --region ${REGION[${COUNT}]}
    echo "  Interface ID '${INTERFACE_ID}' DELETED."

    # Delete private subnets
    SUBNET=0
    while [ $SUBNET -lt  $(echo "${#SUBNET_PRIVATE_ID[@]} / ${#REGION[@]}" | bc) ] ; do
        aws ec2 delete-subnet --subnet-id ${SUBNET_PRIVATE_ID[$(echo "$(echo ${COUNT} - 1 | bc),${SUBNET}")]} --region ${REGION[${COUNT}]}
        echo "  Subnet ID '${SUBNET_PRIVATE_ID[$(echo "$(echo ${COUNT} - 1 | bc),${SUBNET}")]}' DELETED in '${SUBNET_PRIVATE_AZ[$(echo "$(echo ${COUNT} - 1 | bc),${SUBNET}")]}'" \
                       "Availability Zone."
       SUBNET=$(echo $SUBNET + 1 | bc)
    done

    # Delete public subnet
    aws ec2 delete-subnet --subnet-id ${SUBNET_PUBLIC_ID[${COUNT}]} --region ${REGION[${COUNT}]}
    echo "  Subnet ID '${SUBNET_PUBLIC_ID[$COUNT]}' DELETED in '${SUBNET_PUBLIC_AZ[$COUNT]}'" \
               "Availability Zone."

    aws ec2 delete-route \
        --route-table-id ${MAIN_ROUTE_TABLE_ID[${COUNT}]} \
        --destination-cidr-block 0.0.0.0/0 \
        --region ${REGION[${COUNT}]}

    echo "  Route to '0.0.0.0/0' via NAT Gateway with ID '${NAT_GW_ID[${COUNT}]}' DELETED to" \
        "Route Table ID '${MAIN_ROUTE_TABLE_ID[${COUNT}]}'."

    aws ec2 detach-internet-gateway --vpc-id ${VPC_ID[${COUNT}]} --internet-gateway-id ${IGW_ID[${COUNT}]} --region ${REGION[${COUNT}]}
    echo "  Internet Gateway ID '${IGW_ID[$COUNT]}' DETACHED to VPC ID '${VPC_ID[$COUNT]}'."

    # Delete IGW
    aws ec2 delete-internet-gateway --internet-gateway-id ${IGW_ID[${COUNT}]} --region ${REGION[${COUNT}]}
    echo "  Internet Gateway ID '${IGW_ID[$COUNT]}' DELETED."

    # Delete SG
    aws ec2 delete-security-group --group-id ${SG_ID[${COUNT}]} --region ${REGION[${COUNT}]}
    echo "  Security Group ID '${SG_ID[$COUNT]}' DELETED in VPC '${VPC_ID[$COUNT]}' in '${REGION[${COUNT}]}' region."

    # Delete route table
    aws ec2 delete-route-table --route-table-id ${ROUTE_TABLE_ID[${COUNT}]} --region ${REGION[${COUNT}]}
    echo "  Route Table ID '${ROUTE_TABLE_ID[$COUNT]}' DELETED."

    # Delete VPC
    aws ec2 delete-vpc --vpc-id ${VPC_ID[${COUNT}]} --region ${REGION[${COUNT}]}
    echo "  VPC ID '${VPC_ID[$COUNT]}' DELETED in '${REGION[${COUNT}]}' region."

    COUNT=$(echo $COUNT + 1 | bc)
done
