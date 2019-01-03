
# LambdaAPI


Serverless hello world application that exposes the following API:

Description: Saves/updates the given user's name and date of birth in the database.

    Request: PUT /hello/John { "dateOfBirth": "2000-01-01" }
    Response: 204 No Content

Description: Returns a hello/birthday message for the given user

    Request: GET /hello/john
    Response: 200 OK

a. when John's birthday is in 5 days:

    { "message": "Hello, John! Your birthday is in 5 days" }

b. when John's birthday is today:

    { "message": "Hello, John! Happy birthday!" }

This application build an API using Flask and Flask_restful packages,
flywhell to object mapping to DynamoDB, and Zappa to deploy the API using AWS Lambda Functions.

## Stack used

 - **[Flask](http://flask.pocoo.org/)**: a microframework for Python based on Werkzeug and Jinja 2.
 
 - **[Flask-RESTful](https://flask-restful.readthedocs.io/en/latest/)**: an extension for Flask that adds support for quickly building REST
   APIs.
   
 - **[Flywheel](https://flywheel.readthedocs.io/en/latest/#)**: a library for mapping python objects to DynamoDB tables. It uses a SQLAlchemy-like syntax for queries.
  
 -  **[Zappa](https://github.com/Miserlou/Zappa)**: a system for running serverless Python applications using AWS Lambda and AWS API Gateway.
   That means **infinite scaling**, **zero downtime**, **zero
   maintenance** - and at a fraction of the cost of a traditional web
   server.
 - **[AWS Lambda](https://aws.amazon.com/lambda/)**: runs code without provisioning or managing servers.  **AWS Lambda automatically scales the application** by running code in response to each trigger.
   The code runs in parallel and processes each trigger individually, scaling precisely with the size of the workload.
 - **[AWS API Gateway](https://aws.amazon.com/api-gateway/)**: a fully managed service that makes it easy for developers 
   to create, publish, maintain, monitor, and secure APIs at any scale.
 - **[AWS DynamoDB](https://aws.amazon.com/dynamodb/)**: a key-value and document database that delivers single-digit millisecond performance at **any scale**.

## Requirements
 - `bash`
 - Python 3.6.x (Zappa is not yet compatible with Python 3.7, AWS Lambda added support for Python 3.7 recently)
 - Python virtualenv
 - `awcli` should be installed and configured with valid AWS credentials.
 - `make`

## Configuration

This is a multi region deployment. The resources will be disposed as described in the following architectural diagram:

![enter image description here](https://raw.githubusercontent.com/progerjkd/LambdaAPI/master/AWS%20Architecture.png)


Attention: the commands above should be performed in the `bash` shell. Any shell different of bash can cause fails (mainly in MacOS systems).

Run the Makefile to create the virtualenv, install the required dependencies and provision the AWS resources:

    make all

Zappa will automatically package the application and local virtual environment into a Lambda-compatible archive, set up the function handler, upload the archive to S3, create and manage the necessary Amazon IAM policies and roles, register it as a new Lambda function, create a new API Gateway resource, create WSGI-compatible routes for it, link it to the new Lambda function, and finally delete the archive from your S3 bucket.

To delete all AWS resources provisioned run:

    make destroy

As a multi zone deployment, the AWS regions in which the app and database will be deployed are configured in the follwing files (defaults to `us-east-1` and `us-east-2`):

    aws-config.sh
    dynamodb-config.sh
    code/db.py


# Running

Zappa will return the API endpoints at the end of `make all`:

    Deployment complete!: https://88kzdzl50a.execute-api.us-east-1.amazonaws.com/production

Access the API URL and perform actions through the /hello endpoint.

    Request: GET https://88kzdzl50a.execute-api.us-east-1.amazonaws.com/production/hello/Roger
    Response: 200 OK
    {
	    "message": "Hello, Roger! Happy birthday!"
    }

