#!/bin/bash

# Deploy Sprout stack to staging environment
echo "Deploying Sprout stack to staging environment..."

# Set environment
export ENVIRONMENT=staging

# Deploy the CDK stack
cdk deploy SproutStack-staging --context environment=staging

echo "Staging deployment complete!"
