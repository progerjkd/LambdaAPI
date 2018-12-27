SHELL := /bin/bash

VENV=.venv

help:
	@echo
	@echo "Usage"
	@echo
	@echo " make venv		# creates the virtualenv and install the required dependencies"
	@echo " make awsconfig		# creates the AWS resources needed to this deployment (VPC, NAT GW, Subnets, iGW)"
	@echo " make dynamodbconfig	# creates the DynamoDB tables and enables the Cross-Region Replication"
	@echo " make zappaconfig	# creates the zappa configuration file for a multi region app deployment"
	@echo " make zappadeploy	# Deploy the application to AWS Lambda into different Regions"
	@echo " make awsdestroy	# destroy all the AWS resources provisioned in this deployment"
	@echo " make dynamodbdestroy	# destroy the DynamoDB tables and Cross-Region Replication"
	@echo " make all		# call all these targets in the right sequence to provision and deploy the application"
	@echo " make destroy		# call all the destroy scripts to undeploy the application and release all the resources"
	@echo " make clean		# clean the venv and configuration files"

venv:	virtualenv dependencies

virtualenv:
	virtualenv $(VENV)

dependencies:
	source $(VENV)/bin/activate && pip install -r code/resources/requirements.txt

awsconfig:
	./aws-config.sh

awsdestroy:
	./aws-destroy.sh

dynamodbconfig:
	./dynamodb-config.sh

dynamodbdestroy:
	./dynamodb-destroy.sh

zappaconfig:
	./zappa-config.sh

zappadeploy:
	source .venv/bin/activate && cd code && zappa deploy production && zappa deploy production_us_east_2

zappaundeploy:
	source .venv/bin/activate && cd code && zappa undeploy -y production && zappa undeploy -y production_us_east_2

all:	venv awsconfig dynamodbconfig zappaconfig zappadeploy

destroy: zappaundeploy dynamodbdestroy awsdestroy

clean:
	rm -fr $(VENV) *\.cfg
