#!/usr/bin/env node
import 'source-map-support/register';
import { App, Tags } from 'aws-cdk-lib';
import { SproutStack } from '../lib/sprout-stack';

const app = new App();

// Get environment from context or environment variable
const environment = app.node.tryGetContext('environment') || process.env.ENVIRONMENT || 'dev';

// Validate environment
if (!['dev', 'staging', 'prod'].includes(environment)) {
    throw new Error(`Invalid environment: ${environment}. Must be one of: dev, staging, prod`);
}

// Create a stack with environment-specific naming
new SproutStack(app, `SproutStack-${environment}`, {
    env: {
        account: process.env.CDK_DEFAULT_ACCOUNT,
        region: process.env.CDK_DEFAULT_REGION
    },
    environment
});

Tags.of(app).add('app', 'sprout');
Tags.of(app).add('environment', environment);
