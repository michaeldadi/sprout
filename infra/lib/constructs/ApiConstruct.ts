import { Construct } from 'constructs';
import { Duration, RemovalPolicy } from 'aws-cdk-lib';
import { Architecture, Runtime } from 'aws-cdk-lib/aws-lambda';
import { Table } from 'aws-cdk-lib/aws-dynamodb';
import { Bucket } from 'aws-cdk-lib/aws-s3';
import {
    CorsHttpMethod,
    HttpApi,
    HttpMethod,
} from 'aws-cdk-lib/aws-apigatewayv2';
import { HttpLambdaIntegration } from 'aws-cdk-lib/aws-apigatewayv2-integrations';
import { HttpUserPoolAuthorizer } from 'aws-cdk-lib/aws-apigatewayv2-authorizers';
import { UserPool, UserPoolClient } from 'aws-cdk-lib/aws-cognito';
import { NodejsFunction, OutputFormat } from "aws-cdk-lib/aws-lambda-nodejs";

export interface ApiConstructProps {
    transactions: Table;
    ledgers: Table;
    receipts: Bucket;
    userPool: UserPool;
    userPoolClient: UserPoolClient;
    environment: string;
}

export class ApiConstruct extends Construct {
    public readonly httpApi: HttpApi;

    constructor(scope: Construct, id: string, props: ApiConstructProps) {
        super(scope, id);

        const env = {
            TXN_TABLE: props.transactions.tableName,
            LEDGER_TABLE: props.ledgers.tableName,
            RECEIPTS_BUCKET: props.receipts.bucketName,
            ENVIRONMENT: props.environment
        };

        // Helper to bundle a handler out of "../services/**.ts"
        const mkFn = (name: string, entryRel: string) =>
            new NodejsFunction(this, name, {
                runtime: Runtime.NODEJS_20_X,
                architecture: Architecture.ARM_64,
                memorySize: 256,
                timeout: Duration.seconds(10),
                handler: 'index.handler',
                entry: entryRel,
                bundling: {
                  minify: true,
                  sourceMap: true,
                  target: 'node20',
                  format: OutputFormat.CJS, // matches "type": "commonjs" in package.json
                  mainFields: ['module', 'main'],
                  externalModules: [], // DO NOT externalize @aws-sdk/*; we want them bundled
                },
                environment: env
            });

        // Lambdas
        const getSync = mkFn('GetSync', '../services/api/sync/getSync.ts');
        const postTxn = mkFn('PostTransaction', '../services/api/transactions/postTransaction.ts');
        const patchTxn = mkFn('PatchTransaction', '../services/api/transactions/patchTransaction.ts');
        const deleteTxn = mkFn('DeleteTransaction', '../services/api/transactions/deleteTransaction.ts');
        const createUploadUrl = mkFn('CreateReceiptUrl', '../services/api/uploads/createReceiptUrl.ts');

        // Permissions
        props.transactions.grantReadWriteData(getSync);
        props.transactions.grantReadWriteData(postTxn);
        props.transactions.grantReadWriteData(patchTxn);
        props.transactions.grantReadWriteData(deleteTxn);

        props.ledgers.grantReadWriteData(getSync); // expand with ledger mutations as needed
        props.receipts.grantPut(createUploadUrl);  // presigned PUT signer

        // HTTP API
        this.httpApi = new HttpApi(this, 'HttpApi', {
            corsPreflight: {
                allowHeaders: ['authorization','content-type','x-client-request-id','if-match'],
                allowMethods: [CorsHttpMethod.GET, CorsHttpMethod.POST, CorsHttpMethod.PATCH, CorsHttpMethod.DELETE, CorsHttpMethod.OPTIONS],
                allowOrigins: ['*'],
                maxAge: Duration.days(1)
            }
        });

        // Cognito JWT Authorizer (User Pool)
        const authorizer = new HttpUserPoolAuthorizer('CognitoAuth', props.userPool, {
            userPoolClients: [props.userPoolClient]
        });

        // Integrations
        const iSync   = new HttpLambdaIntegration('iSync', getSync);
        const iPost   = new HttpLambdaIntegration('iPost', postTxn);
        const iPatch  = new HttpLambdaIntegration('iPatch', patchTxn);
        const iDelete = new HttpLambdaIntegration('iDelete', deleteTxn);
        const iUpload = new HttpLambdaIntegration('iUpload', createUploadUrl);

        // Routes (all protected)
        this.httpApi.addRoutes({
            path: '/sync',
            methods: [HttpMethod.GET],
            integration: iSync,
            authorizer
        });

        this.httpApi.addRoutes({
            path: '/transactions',
            methods: [HttpMethod.POST],
            integration: iPost,
            authorizer
        });

        this.httpApi.addRoutes({
            path: '/transactions/{id}',
            methods: [HttpMethod.PATCH],
            integration: iPatch,
            authorizer
        });

        this.httpApi.addRoutes({
            path: '/transactions/{id}',
            methods: [HttpMethod.DELETE],
            integration: iDelete,
            authorizer
        });

        this.httpApi.addRoutes({
            path: '/uploads/receipts',
            methods: [HttpMethod.POST],
            integration: iUpload,
            authorizer
        });
    }
}
