#!/bin/bash

# Deploy Sprout stack to production environment
echo "Deploying Sprout stack to production environment..."

# Set environment
export ENVIRONMENT=prod

# Deploy the CDK stack
cdk deploy SproutStack-prod --context environment=prod

echo "Production deployment complete!"
