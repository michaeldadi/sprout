import { Construct } from 'constructs';
import {
    DatabaseInstance,
    DatabaseInstanceEngine,
    PostgresEngineVersion,
    InstanceClass,
    InstanceSize,
    Credentials,
    SubnetGroup,
    ParameterGroup,
    DatabaseCluster,
    DatabaseClusterEngine,
    AuroraPostgresEngineVersion,
} from 'aws-cdk-lib/aws-rds';
import {
    Vpc,
    SubnetType,
    SecurityGroup,
    Port,
} from 'aws-cdk-lib/aws-ec2';
import { Secret } from 'aws-cdk-lib/aws-secretsmanager';
import { RemovalPolicy, CfnOutput } from 'aws-cdk-lib';

export interface DatabaseConstructProps {
    environment: string;
    vpc?: Vpc;
    useCluster?: boolean; // Use Aurora cluster for prod, single instance for dev
}

export class DatabaseConstruct extends Construct {
    public readonly database: DatabaseInstance | DatabaseCluster;
    public readonly vpc: Vpc;
    public readonly securityGroup: SecurityGroup;
    public readonly credentials: Secret;

    constructor(scope: Construct, id: string, props: DatabaseConstructProps) {
        super(scope, id);

        // Create VPC if not provided
        this.vpc = props.vpc || new Vpc(this, 'DatabaseVpc', {
            natGateways: props.environment === 'prod' ? 2 : 1,
            maxAzs: props.environment === 'prod' ? 3 : 2,
            subnetConfiguration: [
                {
                    cidrMask: 24,
                    name: 'Public',
                    subnetType: SubnetType.PUBLIC,
                },
                {
                    cidrMask: 24,
                    name: 'Private',
                    subnetType: SubnetType.PRIVATE_WITH_EGRESS,
                },
                {
                    cidrMask: 28,
                    name: 'Database',
                    subnetType: SubnetType.PRIVATE_ISOLATED,
                }
            ]
        });

        // Create security group for database
        this.securityGroup = new SecurityGroup(this, 'DatabaseSecurityGroup', {
            vpc: this.vpc,
            description: `Security group for Sprout ${props.environment} database`,
            allowAllOutbound: false
        });

        // Allow connections from within VPC
        this.securityGroup.addIngressRule(
            this.securityGroup,
            Port.tcp(5432),
            'Allow database connections from within VPC'
        );

        // Create database credentials secret
        this.credentials = new Secret(this, 'DatabaseCredentials', {
            secretName: `sprout-db-credentials-${props.environment}`,
            description: `Database credentials for Sprout ${props.environment}`,
            generateSecretString: {
                secretStringTemplate: JSON.stringify({ username: 'sprout_admin' }),
                generateStringKey: 'password',
                excludeCharacters: '"@/\\'
            }
        });

        // Create subnet group
        const subnetGroup = new SubnetGroup(this, 'DatabaseSubnetGroup', {
            vpc: this.vpc,
            description: `Database subnet group for Sprout ${props.environment}`,
            vpcSubnets: {
                subnetType: SubnetType.PRIVATE_ISOLATED
            }
        });

        // Database configuration based on environment
        const isProduction = props.environment === 'prod';
        const useCluster = props.useCluster || isProduction;

        if (useCluster) {
            // Aurora Serverless v2 cluster for production
            this.database = new DatabaseCluster(this, 'DatabaseCluster', {
                clusterIdentifier: `sprout-cluster-${props.environment}`,
                engine: DatabaseClusterEngine.auroraPostgres({
                    version: AuroraPostgresEngineVersion.VER_15_4
                }),
                credentials: Credentials.fromSecret(this.credentials),
                defaultDatabaseName: process.env.DB_NAME || `sprout_${props.environment}`,
                vpc: this.vpc,
                securityGroups: [this.securityGroup],
                subnetGroup,
                serverlessV2ScalingConfiguration: {
                    minCapacity: isProduction ? 1 : 0.5,
                    maxCapacity: isProduction ? 16 : 4
                },
                backup: {
                    retention: isProduction ? 
                        RemovalPolicy.RETAIN : 
                        RemovalPolicy.DESTROY,
                    preferredWindow: '03:00-04:00'
                },
                preferredMaintenanceWindow: 'sun:04:00-sun:05:00',
                deletionProtection: isProduction,
                removalPolicy: isProduction ? 
                    RemovalPolicy.RETAIN : 
                    RemovalPolicy.DESTROY,
                parameterGroup: ParameterGroup.fromParameterGroupName(
                    this, 'ClusterParameterGroup', 
                    'default.aurora-postgresql15'
                )
            });
        } else {
            // Single RDS instance for dev/staging
            this.database = new DatabaseInstance(this, 'DatabaseInstance', {
                instanceIdentifier: `sprout-db-${props.environment}`,
                engine: DatabaseInstanceEngine.postgres({
                    version: PostgresEngineVersion.VER_15_4
                }),
                instanceType: props.environment === 'dev' ? 
                    InstanceClass.of(InstanceClass.BURSTABLE3, InstanceSize.MICRO) :
                    InstanceClass.of(InstanceClass.BURSTABLE3, InstanceSize.SMALL),
                credentials: Credentials.fromSecret(this.credentials),
                databaseName: process.env.DB_NAME || `sprout_${props.environment}`,
                vpc: this.vpc,
                securityGroups: [this.securityGroup],
                subnetGroup,
                allocatedStorage: 20,
                maxAllocatedStorage: props.environment === 'dev' ? 50 : 200,
                backupRetention: isProduction ? 
                    RemovalPolicy.RETAIN : 
                    RemovalPolicy.DESTROY,
                preferredBackupWindow: '03:00-04:00',
                preferredMaintenanceWindow: 'sun:04:00-sun:05:00',
                deletionProtection: isProduction,
                removalPolicy: isProduction ? 
                    RemovalPolicy.RETAIN : 
                    RemovalPolicy.DESTROY,
                parameterGroup: ParameterGroup.fromParameterGroupName(
                    this, 'InstanceParameterGroup',
                    'default.postgres15'
                )
            });
        }

        // Outputs
        new CfnOutput(this, 'DatabaseEndpoint', {
            value: this.database.clusterEndpoint?.hostname || 
                   (this.database as DatabaseInstance).instanceEndpoint.hostname,
            description: `Database endpoint for ${props.environment}`
        });

        new CfnOutput(this, 'DatabasePort', {
            value: this.database.clusterEndpoint?.port.toString() || 
                   (this.database as DatabaseInstance).instanceEndpoint.port.toString(),
            description: `Database port for ${props.environment}`
        });

        new CfnOutput(this, 'DatabaseName', {
            value: process.env.DB_NAME || `sprout_${props.environment}`,
            description: `Database name for ${props.environment}`
        });

        new CfnOutput(this, 'DatabaseCredentialsArn', {
            value: this.credentials.secretArn,
            description: `Database credentials secret ARN for ${props.environment}`
        });

        new CfnOutput(this, 'DatabaseVpcId', {
            value: this.vpc.vpcId,
            description: `VPC ID for ${props.environment} database`
        });
    }

    /**
     * Allow connections from a security group
     */
    public allowConnectionsFrom(securityGroup: SecurityGroup): void {
        this.securityGroup.addIngressRule(
            securityGroup,
            Port.tcp(5432),
            'Allow database connections from application'
        );
    }

    /**
     * Get connection string format for applications
     */
    public getConnectionString(): string {
        const endpoint = this.database.clusterEndpoint?.hostname || 
                        (this.database as DatabaseInstance).instanceEndpoint.hostname;
        const port = this.database.clusterEndpoint?.port || 
                    (this.database as DatabaseInstance).instanceEndpoint.port;
        const dbName = process.env.DB_NAME || `sprout_${this.node.tryGetContext('environment') || 'dev'}`;
        
        return `postgresql://{{username}}:{{password}}@${endpoint}:${port}/${dbName}`;
    }
}