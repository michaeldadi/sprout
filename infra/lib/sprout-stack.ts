import { Stack, StackProps, CfnOutput } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { AuthConstruct } from './constructs/AuthConstruct';
import { StorageConstruct } from './constructs/StorageConstruct';
import { DatabaseConstruct } from './constructs/DatabaseConstruct';
import { DatabaseMigrationConstruct } from './constructs/DatabaseMigrationConstruct';
import { ApiConstruct } from './constructs/ApiConstruct';

export interface SproutStackProps extends StackProps {
    environment: string;
}

export class SproutStack extends Stack {
    constructor(scope: Construct, id: string, props: SproutStackProps) {
        super(scope, id, props);

        const auth = new AuthConstruct(this, 'Auth', { environment: props.environment });
        const storage = new StorageConstruct(this, 'Storage', { environment: props.environment });
        
        // Add RDS database
        const database = new DatabaseConstruct(this, 'Database', {
            environment: props.environment,
            useCluster: props.environment === 'prod' // Use Aurora cluster for prod, single instance for dev
        });

        // Run database migrations
        new DatabaseMigrationConstruct(this, 'DatabaseMigration', {
            database: database.database,
            credentials: database.credentials,
            vpc: database.vpc,
            securityGroup: database.securityGroup,
            environment: props.environment
        });
        
        const api = new ApiConstruct(this, 'Api', {
            transactions: storage.transactions,
            ledgers: storage.ledgers,
            receipts: storage.receipts,
            userPool: auth.userPool,
            userPoolClient: auth.userPoolClient,
            environment: props.environment
        });

        // Outputs for iOS config
        new CfnOutput(this, 'HttpApiUrl', { value: api.httpApi.apiEndpoint });
        new CfnOutput(this, 'UserPoolId', { value: auth.userPool.userPoolId });
        new CfnOutput(this, 'UserPoolClientId', { value: auth.userPoolClient.userPoolClientId });
        new CfnOutput(this, 'ReceiptsBucket', { value: storage.receipts.bucketName });
        new CfnOutput(this, 'Region', { value: this.region });

        // Issuer URL (for reference if you ever switch to JWT authorizer by issuer)
        new CfnOutput(this, 'CognitoIssuer', {
            value: `https://cognito-idp.${this.region}.amazonaws.com/${auth.userPool.userPoolId}`
        });
    }
}
