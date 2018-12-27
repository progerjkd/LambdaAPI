from flywheel import Engine

engine = Engine()
# select the region to connect to the DynamoDB table
# one region per time
engine.connect_to_region('us-east-1')
