#!/bin/bash

AWS_REGION[1]='us-east-1'
AWS_REGION[2]='us-east-2'
CFG_FILE='aws.cfg'

REGION=1
while [ $REGION -le ${#AWS_REGION[@]} ] ; do

	VPC_NAME="Lambda VPC"
	VPC_CIDR="10.0.0.0/16"

	SUBNET_PUBLIC_CIDR="10.0.1.0/24"
	SUBNET_PUBLIC_AZ="${AWS_REGION[${REGION}]}a"
	SUBNET_PUBLIC_NAME="10.0.1.0 - ${AWS_REGION[${REGION}]}a"

	SUBNET_PRIVATE_CIDR[1]="10.0.2.0/24"
	SUBNET_PRIVATE_AZ[1]="${AWS_REGION[${REGION}]}a"
	SUBNET_PRIVATE_NAME[1]="10.0.2.0 - ${AWS_REGION[${REGION}]}a"

	SUBNET_PRIVATE_CIDR[2]="10.0.3.0/24"
	SUBNET_PRIVATE_AZ[2]="${AWS_REGION[${REGION}]}b"
	SUBNET_PRIVATE_NAME[2]="10.0.3.0 - ${AWS_REGION[${REGION}]}b"
	CHECK_FREQUENCY=5
	#
	#==============================================================================
	#
	echo -e "Using Region: \e[1m\e[32m${AWS_REGION[${REGION}]}\e[0m"

	# Create VPC
	echo "Creating VPC in preferred region..."
	VPC_ID=$(aws ec2 create-vpc \
	  --cidr-block $VPC_CIDR \
	  --query 'Vpc.{VpcId:VpcId}' \
	  --output text \
	  --region ${AWS_REGION[${REGION}]})
	echo "  VPC ID '$VPC_ID' CREATED in '${AWS_REGION[${REGION}]}' region."

	# Add Name tag to VPC
	aws ec2 create-tags \
	  --resources $VPC_ID \
	  --tags "Key=Name,Value=$VPC_NAME" \
	  --region ${AWS_REGION[${REGION}]}
	echo "  VPC ID '$VPC_ID' NAMED as '$VPC_NAME'."

	# Create Public Subnet
	echo "Creating Public Subnet..."
	SUBNET_PUBLIC_ID=$(aws ec2 create-subnet \
	  --vpc-id $VPC_ID \
	  --cidr-block $SUBNET_PUBLIC_CIDR \
	  --availability-zone $SUBNET_PUBLIC_AZ \
	  --query 'Subnet.{SubnetId:SubnetId}' \
	  --output text \
	  --region ${AWS_REGION[${REGION}]})
	echo "  Subnet ID '$SUBNET_PUBLIC_ID' CREATED in '$SUBNET_PUBLIC_AZ'" \
	  "Availability Zone."

	# Add Name tag to Public Subnet
	aws ec2 create-tags \
	  --resources $SUBNET_PUBLIC_ID \
	  --tags "Key=Name,Value=$SUBNET_PUBLIC_NAME" \
	  --region ${AWS_REGION[${REGION}]}
	echo "  Subnet ID '$SUBNET_PUBLIC_ID' NAMED as" \
	  "'$SUBNET_PUBLIC_NAME'."

	COUNT=1
	while [ $COUNT -le  ${#SUBNET_PRIVATE_CIDR[@]} ] ; do


		# Create Private Subnet
		echo "Creating Private Subnet..."
		SUBNET_PRIVATE_ID[${COUNT}]=$(aws ec2 create-subnet \
		  --vpc-id $VPC_ID \
		  --cidr-block ${SUBNET_PRIVATE_CIDR[${COUNT}]} \
		  --availability-zone ${SUBNET_PRIVATE_AZ[${COUNT}]} \
		  --query 'Subnet.{SubnetId:SubnetId}' \
		  --output text \
		  --region ${AWS_REGION[${REGION}]})
		echo "  Subnet ID '${SUBNET_PRIVATE_ID[${COUNT}]}' CREATED in '${SUBNET_PRIVATE_AZ[${COUNT}]}'" \
		  "Availability Zone."

		# Add Name tag to Private Subnet
		aws ec2 create-tags \
		  --resources ${SUBNET_PRIVATE_ID[${COUNT}]} \
		  --tags "Key=Name,Value=${SUBNET_PRIVATE_NAME[${COUNT}]}" \
		  --region ${AWS_REGION[${REGION}]}
		echo "  Subnet ID '${SUBNET_PRIVATE_ID[${COUNT}]}' NAMED as '${SUBNET_PRIVATE_NAME[${COUNT}]}'."


		COUNT=`echo $COUNT + 1 | bc`
	done


	# Create Internet gateway
	echo "Creating Internet Gateway..."
	IGW_ID=$(aws ec2 create-internet-gateway \
	  --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' \
	  --output text \
	  --region ${AWS_REGION[${REGION}]})
	echo "  Internet Gateway ID '$IGW_ID' CREATED."

	# Attach Internet gateway to VPC
	aws ec2 attach-internet-gateway \
	  --vpc-id $VPC_ID \
	  --internet-gateway-id $IGW_ID \
	  --region ${AWS_REGION[${REGION}]}
	echo "  Internet Gateway ID '$IGW_ID' ATTACHED to VPC ID '$VPC_ID'."

	# Create Route Table
	echo "Creating Route Table..."
	ROUTE_TABLE_ID=$(aws ec2 create-route-table \
	  --vpc-id $VPC_ID \
	  --query 'RouteTable.{RouteTableId:RouteTableId}' \
	  --output text \
	  --region ${AWS_REGION[${REGION}]})
	echo "  Route Table ID '$ROUTE_TABLE_ID' CREATED."

	# Create route to Internet Gateway
	RESULT=$(aws ec2 create-route \
	  --route-table-id $ROUTE_TABLE_ID \
	  --destination-cidr-block 0.0.0.0/0 \
	  --gateway-id $IGW_ID \
	  --region ${AWS_REGION[${REGION}]})
	echo "  Route to '0.0.0.0/0' via Internet Gateway ID '$IGW_ID' ADDED to" \
	  "Route Table ID '$ROUTE_TABLE_ID'."

	# Associate Public Subnet with Route Table
	RESULT=$(aws ec2 associate-route-table  \
	  --subnet-id $SUBNET_PUBLIC_ID \
	  --route-table-id $ROUTE_TABLE_ID \
	  --region ${AWS_REGION[${REGION}]})
	echo "  Public Subnet ID '$SUBNET_PUBLIC_ID' ASSOCIATED with Route Table ID" \
	  "'$ROUTE_TABLE_ID'."

	# Enable Auto-assign Public IP on Public Subnet
	aws ec2 modify-subnet-attribute \
	  --subnet-id $SUBNET_PUBLIC_ID \
	  --map-public-ip-on-launch \
	  --region ${AWS_REGION[${REGION}]}
	echo "  'Auto-assign Public IP' ENABLED on Public Subnet ID" \
	  "'$SUBNET_PUBLIC_ID'."

	# Allocate Elastic IP Address for NAT Gateway
	echo "Creating NAT Gateway..."
	EIP_ALLOC_ID=$(aws ec2 allocate-address \
	  --domain vpc \
	  --query '{AllocationId:AllocationId}' \
	  --output text \
	  --region ${AWS_REGION[${REGION}]})
	echo "  Elastic IP address ID '$EIP_ALLOC_ID' ALLOCATED."

	# Create NAT Gateway
	NAT_GW_ID=$(aws ec2 create-nat-gateway \
	  --subnet-id $SUBNET_PUBLIC_ID \
	  --allocation-id $EIP_ALLOC_ID \
	  --query 'NatGateway.{NatGatewayId:NatGatewayId}' \
	  --output text \
	  --region ${AWS_REGION[${REGION}]})
	FORMATTED_MSG="Creating NAT Gateway ID '$NAT_GW_ID' and waiting for it to "
	FORMATTED_MSG+="become available.\n    Please BE PATIENT as this can take some "
	FORMATTED_MSG+="time to complete.\n    ......\n"
	printf "  $FORMATTED_MSG"
	FORMATTED_MSG="STATUS: %s  -  %02dh:%02dm:%02ds elapsed while waiting for NAT "
	FORMATTED_MSG+="Gateway to become available..."
	SECONDS=0
	LAST_CHECK=0
	STATE='PENDING'
	until [[ $STATE == 'AVAILABLE' ]]; do
	  INTERVAL=$SECONDS-$LAST_CHECK
	  if [[ $INTERVAL -ge $CHECK_FREQUENCY ]]; then
	    STATE=$(aws ec2 describe-nat-gateways \
	      --nat-gateway-ids $NAT_GW_ID \
	      --query 'NatGateways[*].{State:State}' \
	      --output text \
	      --region ${AWS_REGION[${REGION}]})
	    STATE=$(echo $STATE | tr '[:lower:]' '[:upper:]')
	    LAST_CHECK=$SECONDS
	  fi
	  SECS=$SECONDS
	  STATUS_MSG=$(printf "$FORMATTED_MSG" \
	    $STATE $(($SECS/3600)) $(($SECS%3600/60)) $(($SECS%60)))
	  printf "    $STATUS_MSG\033[0K\r"
	  sleep 1
	done
	printf "\n    ......\n  NAT Gateway ID '$NAT_GW_ID' is now AVAILABLE.\n"

	# Create route to NAT Gateway
	MAIN_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
	  --filters Name=vpc-id,Values=$VPC_ID Name=association.main,Values=true \
	  --query 'RouteTables[*].{RouteTableId:RouteTableId}' \
	  --output text \
	  --region ${AWS_REGION[${REGION}]})
	echo "  Main Route Table ID is '$MAIN_ROUTE_TABLE_ID'."
	RESULT=$(aws ec2 create-route \
	  --route-table-id $MAIN_ROUTE_TABLE_ID \
	  --destination-cidr-block 0.0.0.0/0 \
	  --gateway-id $NAT_GW_ID \
	  --region ${AWS_REGION[${REGION}]})
	echo "  Route to '0.0.0.0/0' via NAT Gateway with ID '$NAT_GW_ID' ADDED to" \
	  "Route Table ID '$MAIN_ROUTE_TABLE_ID'."

	echo "Creating Security Group..."
	SG_ID=$(aws ec2 create-security-group \
	    --description 'Lambda SG' \
	    --group-name  'Lambda SG' \
	    --vpc-id $VPC_ID \
	    --output text \
	    --region ${AWS_REGION[${REGION}]})
	echo "  Security Group ID '$SG_ID' CREATED in VPC '$VPC_ID' in '${AWS_REGION[${REGION}]}' region."

	if [ ${REGION} -eq 1 ]; then
		> $CFG_FILE
	    	echo "declare -A SUBNET_PRIVATE_ID" >> $CFG_FILE
    		echo "declare -A SUBNET_PRIVATE_AZ" >> $CFG_FILE
	fi

	echo >> $CFG_FILE
	echo "REGION[${REGION}]=\"${AWS_REGION[${REGION}]}\"" >> $CFG_FILE
	echo "VPC_ID[${REGION}]=\"${VPC_ID}\"" >> $CFG_FILE
	echo "SUBNET_PUBLIC_ID[${REGION}]=\"${SUBNET_PUBLIC_ID}\"" >> $CFG_FILE
    	echo "SUBNET_PUBLIC_AZ[$REGION]=\"${AWS_REGION[${REGION}]}a\"" >> $CFG_FILE
	COUNT=0
	while [ $COUNT -lt  ${#SUBNET_PRIVATE_ID[@]} ] ; do
		echo "SUBNET_PRIVATE_ID[$(echo ${REGION} - 1 | bc),${COUNT}]=\"${SUBNET_PRIVATE_ID[$(echo ${COUNT} + 1 | bc)]}\"" >> $CFG_FILE
        	echo "SUBNET_PRIVATE_AZ[$(echo ${REGION} - 1 | bc),${COUNT}]=${SUBNET_PRIVATE_AZ[$(echo ${COUNT} + 1 | bc)]}" >> $CFG_FILE
		COUNT=$(echo $COUNT + 1 | bc)
	done
	echo "IGW_ID[${REGION}]=\"${IGW_ID}\"" >> $CFG_FILE
	echo "ROUTE_TABLE_ID[${REGION}]=\"${ROUTE_TABLE_ID}\"" >> $CFG_FILE
	echo "EIP_ALLOC_ID[${REGION}]=\"${EIP_ALLOC_ID}\"" >> $CFG_FILE
	echo "NAT_GW_ID[${REGION}]=\"${NAT_GW_ID}\"" >> $CFG_FILE
	echo "MAIN_ROUTE_TABLE_ID[${REGION}]=\"${MAIN_ROUTE_TABLE_ID}\"" >> $CFG_FILE
	echo "SG_ID[${REGION}]=\"${SG_ID}\"" >> $CFG_FILE

	echo >> $CFG_FILE

    REGION=$(echo $REGION + 1 | bc)
done
echo "COMPLETED"
