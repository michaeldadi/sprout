import { Construct } from 'constructs';
import {
    AttributeType,
    BillingMode,
    ProjectionType,
    Table,
} from 'aws-cdk-lib/aws-dynamodb';
import {
    BlockPublicAccess,
    Bucket,
} from 'aws-cdk-lib/aws-s3';
import { RemovalPolicy, Duration } from 'aws-cdk-lib';

export interface StorageConstructProps {
    environment: string;
}

export class StorageConstruct extends Construct {
    public readonly transactions: Table;
    public readonly ledgers: Table;
    public readonly receipts: Bucket;

    constructor(scope: Construct, id: string, props: StorageConstructProps) {
        super(scope, id);

        this.transactions = new Table(this, 'Transactions', {
            tableName: `sprout-transactions-${props.environment}`,
            partitionKey: { name: 'userId', type: AttributeType.STRING },
            sortKey: { name: 'id', type: AttributeType.STRING },
            billingMode: BillingMode.PAY_PER_REQUEST,
            removalPolicy: RemovalPolicy.DESTROY
        });
        this.transactions.addGlobalSecondaryIndex({
            indexName: 'updatedAtIndex',
            partitionKey: { name: 'userId', type: AttributeType.STRING },
            sortKey: { name: 'updatedAt', type: AttributeType.STRING },
            projectionType: ProjectionType.ALL
        });

        this.ledgers = new Table(this, 'Ledgers', {
            tableName: `sprout-ledgers-${props.environment}`,
            partitionKey: { name: 'userId', type: AttributeType.STRING },
            sortKey: { name: 'id', type: AttributeType.STRING },
            billingMode: BillingMode.PAY_PER_REQUEST,
            removalPolicy: RemovalPolicy.DESTROY
        });
        this.ledgers.addGlobalSecondaryIndex({
            indexName: 'updatedAtIndex',
            partitionKey: { name: 'userId', type: AttributeType.STRING },
            sortKey: { name: 'updatedAt', type: AttributeType.STRING },
            projectionType: ProjectionType.ALL
        });

        this.receipts = new Bucket(this, 'ReceiptsBucket', {
            bucketName: `sprout-receipts-${props.environment}`,
            blockPublicAccess: BlockPublicAccess.BLOCK_ALL,
            enforceSSL: true,
            autoDeleteObjects: true,
            removalPolicy: RemovalPolicy.DESTROY,
            cors: [{
                allowedHeaders: ['*'],
                allowedMethods: [ // for presigned PUTs / reads
                    // @ts-ignore - enum is shared with apigw, but values map
                    'GET', 'PUT', 'HEAD'
                ],
                allowedOrigins: ['*'],
                maxAge: Duration.hours(1).toSeconds()
            }]
        });
    }
}
