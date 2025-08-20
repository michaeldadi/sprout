#!/usr/bin/env node

/**
 * Manual migration runner script
 * Run this after your RDS database is deployed
 *
 * Usage:
 * npx ts-node scripts/run-migration.ts --env dev
 * npx ts-node scripts/run-migration.ts --env prod
 */

import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';
import { Client } from 'pg';
import * as fs from 'node:fs';
import * as path from 'node:path';

interface DatabaseCredentials {
    username: string;
    password: string;
}

async function runMigration(): Promise<void> {
    const args = process.argv.slice(2);
    const envIndex = args.indexOf('--env');

    if (envIndex === -1 || !args[envIndex + 1]) {
        console.error('Usage: npx ts-node run-migration.ts --env <dev|prod>');
        process.exit(1);
    }

    const environment = args[envIndex + 1];

    if (!['dev', 'prod'].includes(environment)) {
        console.error('Environment must be "dev" or "prod"');
        process.exit(1);
    }

    console.log(`🚀 Running migration for ${environment} environment...`);

    const secretsManager = new SecretsManagerClient({
        region: process.env.AWS_REGION || 'us-east-1'
    });

    try {
        // Get database credentials from Secrets Manager
        const secretName = `sprout-db-credentials-${environment}`;
        console.log(`📝 Fetching credentials from: ${secretName}`);

        const secretResponse = await secretsManager.send(new GetSecretValueCommand({
            SecretId: secretName
        }));

        if (!secretResponse.SecretString) {
            throw new Error('No secret string found');
        }

        const credentials: DatabaseCredentials = JSON.parse(secretResponse.SecretString);

        // Read migration file
        const migrationPath = path.join(__dirname, '../database/migrations/001_initial_schema.sql');

        if (!fs.existsSync(migrationPath)) {
            console.error(`Migration file not found: ${migrationPath}`);
            process.exit(1);
        }

        const migrationSql = fs.readFileSync(migrationPath, 'utf8');
        console.log('📄 Migration file loaded');

        // You'll need to get the database endpoint from the CDK outputs
        // For now, we'll show how to construct it
        const dbName = process.env.DB_NAME || `sprout_${environment}`;
        const dbEndpoint = `sprout-${environment === 'prod' ? 'cluster' : 'db'}-${environment}.REPLACE_WITH_ACTUAL_ENDPOINT.rds.amazonaws.com`;

        console.log('🔌 Connecting to database...');
        console.log('   Endpoint:', dbEndpoint);
        console.log('   Database:', dbName);
        console.log('   Username:', credentials.username);

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
            query_timeout: 120000,
        });

        await client.connect();
        console.log('✅ Connected to database successfully');

        // Create migrations tracking table if it doesn't exist
        console.log('📋 Setting up migration tracking...');
        await client.query(`
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version VARCHAR(255) PRIMARY KEY,
                applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
        `);

        // Check if migration has already been applied
        const migrationCheck = await client.query(
            'SELECT version FROM schema_migrations WHERE version = $1',
            ['001_initial_schema']
        );

        if (migrationCheck.rows.length > 0) {
            console.log('ℹ️  Migration already applied, skipping');
            await client.end();
            return;
        }

        console.log('🏗️  Running initial migration...');

        // Run the migration in a transaction
        await client.query('BEGIN');

        try {
            await client.query(migrationSql);

            // Record the migration
            await client.query(
                'INSERT INTO schema_migrations (version) VALUES ($1)',
                ['001_initial_schema']
            );

            await client.query('COMMIT');
            console.log('✅ Migration completed successfully!');

        } catch (error) {
            await client.query('ROLLBACK');
            throw error;
        }

        await client.end();
        console.log('🎉 Database migration finished');

    } catch (error: any) {
        console.error('❌ Migration failed:', error.message);

        if (error.code === 'ENOTFOUND') {
            console.error('\n💡 Make sure to:');
            console.error('1. Deploy your CDK stack first');
            console.error('2. Get the actual database endpoint from CDK outputs');
            console.error('3. Update the dbEndpoint variable in this script');
            console.error('\n📋 Get database endpoint with:');
            await getDatabaseEndpointFromOutputs(environment);
        }

        process.exit(1);
    }
}

// Get database endpoint from CDK outputs helper
async function getDatabaseEndpointFromOutputs(environment: string): Promise<void> {
    console.log(`aws cloudformation describe-stacks --stack-name SproutStack-${environment} --query "Stacks[0].Outputs[?OutputKey=='DatabaseEndpoint'].OutputValue" --output text`);
}

if (require.main === module) {
    runMigration().catch(console.error);
}
