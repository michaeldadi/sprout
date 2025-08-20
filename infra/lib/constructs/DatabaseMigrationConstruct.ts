import { Construct } from 'constructs';
import { Function, Runtime, Code, Architecture } from 'aws-cdk-lib/aws-lambda';
import { CustomResource, Duration } from 'aws-cdk-lib';
import { Provider } from 'aws-cdk-lib/custom-resources';
import { Secret } from 'aws-cdk-lib/aws-secretsmanager';
import { DatabaseInstance, DatabaseCluster } from 'aws-cdk-lib/aws-rds';
import { SecurityGroup, Vpc } from 'aws-cdk-lib/aws-ec2';
import * as fs from 'node:fs';
import * as path from 'node:path';

export interface DatabaseMigrationConstructProps {
    database: DatabaseInstance | DatabaseCluster;
    credentials: Secret;
    vpc: Vpc;
    securityGroup: SecurityGroup;
    environment: string;
}

export class DatabaseMigrationConstruct extends Construct {
    constructor(scope: Construct, id: string, props: DatabaseMigrationConstructProps) {
        super(scope, id);

        // Create the migration Lambda function
        const migrationFunction = new Function(this, 'MigrationFunction', {
            runtime: Runtime.NODEJS_18_X,
            architecture: Architecture.ARM_64,
            handler: 'index.handler',
            code: Code.fromInline(this.getMigrationCode()),
            timeout: Duration.minutes(10),
            vpc: props.vpc,
            securityGroups: [props.securityGroup],
            environment: {
                DB_SECRET_ARN: props.credentials.secretArn,
                DB_NAME: process.env.DB_NAME || `sprout_${props.environment}`,
                ENVIRONMENT: props.environment
            }
        });

        // Grant permissions to read the database secret
        props.credentials.grantRead(migrationFunction);

        // Create custom resource provider
        const provider = new Provider(this, 'MigrationProvider', {
            onEventHandler: migrationFunction,
            logRetention: 14
        });

        // Create custom resource that triggers the migration
        new CustomResource(this, 'MigrationResource', {
            serviceToken: provider.serviceToken,
            properties: {
                // Change this value to trigger re-deployment of migrations
                MigrationVersion: '1.0.0',
                Environment: props.environment,
                DatabaseEndpoint: this.getDatabaseEndpoint(props.database),
                // Include a hash of migration files to detect changes
                MigrationHash: this.getMigrationHash()
            }
        });
    }

    private getDatabaseEndpoint(database: DatabaseInstance | DatabaseCluster): string {
        if ('clusterEndpoint' in database && database.clusterEndpoint) {
            return database.clusterEndpoint.hostname;
        } else if ('instanceEndpoint' in database) {
            return database.instanceEndpoint.hostname;
        }
        throw new Error('Unable to determine database endpoint');
    }

    private getMigrationHash(): string {
        try {
            const migrationPath = path.join(__dirname, '../../database/migrations/001_initial_schema.sql');
            const content = fs.readFileSync(migrationPath, 'utf8');
            return require('crypto').createHash('md5').update(content).digest('hex');
        } catch (error) {
            console.warn('Could not read migration file for hash:', error);
            return 'default-hash';
        }
    }

    private getMigrationCode(): string {
        // Read the SQL migration file
        let migrationSql: string;
        try {
            const migrationPath = path.join(__dirname, '../../database/migrations/001_initial_schema.sql');
            migrationSql = fs.readFileSync(migrationPath, 'utf8');
        } catch (err) {
            console.warn('Could not read migration file, using inline SQL');
            migrationSql = this.getInlineMigrationSql();

            throw new Error(`Migration file not found - Error: ${err} - migrationSql: ${migrationSql}`);
        }

        return `
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const { Client } = require('pg');

const MIGRATION_SQL = \`${migrationSql.replace(/`/g, '\\`')}\`;

exports.handler = async (event) => {
    console.log('Migration event:', JSON.stringify(event, null, 2));

    const secretsManager = new SecretsManagerClient({});

    try {
        // Get database credentials from Secrets Manager
        const secretResponse = await secretsManager.send(new GetSecretValueCommand({
            SecretId: process.env.DB_SECRET_ARN
        }));

        const credentials = JSON.parse(secretResponse.SecretString);

        // Get database endpoint from event properties
        const dbEndpoint = event.ResourceProperties.DatabaseEndpoint;
        const dbName = process.env.DB_NAME;

        console.log('Connecting to database:', dbEndpoint);

        // Create database connection
        const client = new Client({
            host: dbEndpoint,
            port: 5432,
            database: dbName,
            user: credentials.username,
            password: credentials.password,
            ssl: {
                rejectUnauthorized: false
            },
            connectionTimeoutMillis: 30000,
            query_timeout: 60000,
        });

        await client.connect();
        console.log('Connected to database successfully');

        // Check if migrations table exists
        const migrationsTableQuery = \`
            SELECT EXISTS (
                SELECT FROM information_schema.tables
                WHERE table_name = 'schema_migrations'
            );
        \`;

        const tableExists = await client.query(migrationsTableQuery);

        if (!tableExists.rows[0].exists) {
            console.log('Creating schema_migrations table');
            await client.query(\`
                CREATE TABLE schema_migrations (
                    version VARCHAR(255) PRIMARY KEY,
                    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                );
            \`);
        }

        // Check if migration has already been applied
        const migrationCheck = await client.query(
            'SELECT version FROM schema_migrations WHERE version = $1',
            ['001_initial_schema']
        );

        if (migrationCheck.rows.length === 0) {
            console.log('Running initial migration...');

            // Run the migration
            await client.query(MIGRATION_SQL);

            // Record the migration
            await client.query(
                'INSERT INTO schema_migrations (version) VALUES ($1)',
                ['001_initial_schema']
            );

            console.log('Migration completed successfully');
        } else {
            console.log('Migration already applied, skipping');
        }

        await client.end();

        return {
            Status: 'SUCCESS',
            PhysicalResourceId: \`migration-\${event.ResourceProperties.MigrationVersion}\`,
            Data: {
                MigrationApplied: true,
                Environment: process.env.ENVIRONMENT
            }
        };

    } catch (error) {
        console.error('Migration failed:', error);

        return {
            Status: 'FAILED',
            Reason: error.message,
            PhysicalResourceId: \`migration-\${event.ResourceProperties.MigrationVersion}\`
        };
    }
};
`;
    }

    private getInlineMigrationSql(): string {
        return `
-- Initial database schema for Sprout application
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cognito_user_id VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_users_cognito_user_id ON users(cognito_user_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    color VARCHAR(7),
    icon VARCHAR(50),
    parent_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

INSERT INTO categories (name, description, color, icon) VALUES
    ('Food & Dining', 'Restaurant, groceries, takeout', '#FF6B6B', 'restaurant'),
    ('Transportation', 'Gas, car payments, public transit', '#4ECDC4', 'car'),
    ('Entertainment', 'Movies, games, hobbies', '#45B7D1', 'movie'),
    ('Shopping', 'Clothing, electronics, general purchases', '#96CEB4', 'shopping-cart'),
    ('Health & Medical', 'Doctor visits, pharmacy, fitness', '#FFEAA7', 'heart'),
    ('Bills & Utilities', 'Rent, electricity, internet, phone', '#DDA0DD', 'file-text'),
    ('Income', 'Salary, freelance, investments', '#98D8C8', 'dollar-sign')
ON CONFLICT DO NOTHING;
        `;
    }
}
