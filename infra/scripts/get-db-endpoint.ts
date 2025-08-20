#!/usr/bin/env node

/**
 * Helper script to get database endpoint from CDK outputs
 * Usage: npx ts-node scripts/get-db-endpoint.ts --env dev
 */

import { CloudFormationClient, DescribeStacksCommand } from '@aws-sdk/client-cloudformation';

async function getDatabaseEndpoint(): Promise<void> {
    const args = process.argv.slice(2);
    const envIndex = args.indexOf('--env');
    
    if (envIndex === -1 || !args[envIndex + 1]) {
        console.error('Usage: npx ts-node get-db-endpoint.ts --env <dev|prod>');
        process.exit(1);
    }
    
    const environment = args[envIndex + 1];
    
    if (!['dev', 'prod'].includes(environment)) {
        console.error('Environment must be "dev" or "prod"');
        process.exit(1);
    }

    const cloudFormation = new CloudFormationClient({
        region: process.env.AWS_REGION || 'us-east-1'
    });

    try {
        const stackName = `SproutStack-${environment}`;
        console.log(`📋 Getting outputs from stack: ${stackName}`);
        
        const response = await cloudFormation.send(new DescribeStacksCommand({
            StackName: stackName
        }));
        
        const stack = response.Stacks?.[0];
        if (!stack) {
            console.error(`Stack ${stackName} not found`);
            process.exit(1);
        }
        
        const outputs = stack.Outputs || [];
        
        const dbEndpoint = outputs.find(output => output.OutputKey === 'DatabaseEndpoint');
        const dbPort = outputs.find(output => output.OutputKey === 'DatabasePort');
        const dbName = outputs.find(output => output.OutputKey === 'DatabaseName');
        const credentialsArn = outputs.find(output => output.OutputKey === 'DatabaseCredentialsArn');
        
        console.log('\n🗄️  Database Connection Details:');
        console.log('================================');
        console.log(`📍 Endpoint: ${dbEndpoint?.OutputValue || 'Not found'}`);
        console.log(`🔌 Port: ${dbPort?.OutputValue || '5432'}`);
        console.log(`💾 Database: ${dbName?.OutputValue || 'Not found'}`);
        console.log(`🔐 Credentials: ${credentialsArn?.OutputValue || 'Not found'}`);
        
        if (dbEndpoint?.OutputValue) {
            console.log('\n💡 Connection String:');
            console.log(`postgresql://{{username}}:{{password}}@${dbEndpoint.OutputValue}:${dbPort?.OutputValue || '5432'}/${dbName?.OutputValue || `sprout_${environment}`}`);
            
            console.log('\n🚀 Ready to run migration with:');
            console.log(`npm run migrate:${environment}`);
        } else {
            console.error('\n❌ Database endpoint not found in stack outputs');
            console.error('Make sure the CDK stack has been deployed successfully');
        }
        
    } catch (error: any) {
        console.error('❌ Error getting stack outputs:', error.message);
        
        if (error.name === 'ValidationError' || error.message.includes('does not exist')) {
            console.error(`\n💡 Stack ${stackName} not found. Deploy it first with:`);
            console.error(`cd infra && cdk deploy --context environment=${environment}`);
        }
        
        process.exit(1);
    }
}

if (require.main === module) {
    getDatabaseEndpoint().catch(console.error);
}