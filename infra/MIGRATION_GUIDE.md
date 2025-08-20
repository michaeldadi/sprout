# 🗄️ Database Migration Guide

This guide covers how to run initial migrations for your Sprout RDS databases.

## 📋 Prerequisites

1. **AWS CLI configured** with proper credentials
2. **CDK deployed** for the target environment
3. **Node.js dependencies** installed in the `infra` directory

## 🚀 Quick Start

### Method 1: Automatic Migration (Recommended)

The **easiest way** is to use the automatic migration that runs during CDK deployment:

```bash
# Deploy with automatic migration
cd infra
cdk deploy --context environment=dev    # For dev
cdk deploy --context environment=prod   # For prod
```

✅ **Migration runs automatically** during stack deployment
✅ **Idempotent** - safe to run multiple times
✅ **Tracks migration status** in `schema_migrations` table

---

### Method 2: Manual Migration

If you need to run migrations manually:

#### Step 1: Install Dependencies
```bash
cd infra
npm install
```

#### Step 2: Get Database Endpoint
```bash
# For dev environment
npm run db-endpoint:dev

# For prod environment  
npm run db-endpoint:prod
```

This will output database connection details like:
```
🗄️  Database Connection Details:
================================
📍 Endpoint: sprout-db-dev.xyz.us-east-1.rds.amazonaws.com
🔌 Port: 5432
💾 Database: sprout_dev
🔐 Credentials: arn:aws:secretsmanager:us-east-1:123456789:secret:sprout-db-credentials-dev
```

#### Step 3: Update Migration Script
Edit `scripts/run-migration.ts` and replace the `dbEndpoint` variable with the actual endpoint from Step 2:

```typescript
// Replace this line:
const dbEndpoint = `sprout-${environment === 'prod' ? 'cluster' : 'db'}-${environment}.REPLACE_WITH_ACTUAL_ENDPOINT.rds.amazonaws.com`;

// With the actual endpoint:
const dbEndpoint = 'sprout-db-dev.xyz.us-east-1.rds.amazonaws.com'; // From step 2
```

#### Step 4: Run Migration
```bash
# For dev environment
npm run migrate:dev

# For prod environment
npm run migrate:prod
```

## 🔍 Migration Script Details

The migration script:

1. **Fetches database credentials** from AWS Secrets Manager
2. **Connects to PostgreSQL** using SSL
3. **Creates migration tracking table** (`schema_migrations`)
4. **Checks if migration already applied** (idempotent)
5. **Runs migration in a transaction** (atomic)
6. **Records successful migration**

## 📊 Database Schema Created

The initial migration creates:

### Core Tables
- **`users`** - User profiles (linked to Cognito)
- **`categories`** - Transaction categories with colors/icons
- **`accounts`** - Bank accounts, credit cards, etc.
- **`transactions`** - Financial transactions with receipt storage

### Advanced Tables
- **`budgets`** - Budget tracking by category
- **`goals`** - Financial goals (savings, debt payoff)
- **`recurring_transactions`** - Scheduled/recurring transactions

### System Tables
- **`schema_migrations`** - Migration tracking

## 🔧 Troubleshooting

### Error: "Database endpoint not found"
```bash
# Make sure CDK stack is deployed
cdk list
cdk deploy --context environment=dev
```

### Error: "ENOTFOUND" or "Connection refused"
1. Check VPC security groups allow connections
2. Verify database endpoint is correct
3. Ensure you're running from correct AWS region

### Error: "AccessDenied" 
1. Check AWS credentials: `aws sts get-caller-identity`
2. Ensure IAM user has:
   - `secretsmanager:GetSecretValue` for the credentials
   - `rds-db:connect` for the database

### Migration already applied
This is expected! The script is idempotent and will skip if already run.

## 🛡️ Security Notes

- **Credentials never logged** - Retrieved from Secrets Manager
- **SSL/TLS enforced** - All connections encrypted
- **Transaction-based** - Migration is atomic
- **VPC isolated** - Database in private subnets only

## 🔄 Future Migrations

To add new migrations:

1. Create new file: `database/migrations/002_your_migration.sql`
2. Update the migration script to handle multiple files
3. Add migration version to tracking logic

## 📞 Getting Help

If you encounter issues:

1. **Check CDK deployment**: `cdk list`
2. **Verify AWS credentials**: `aws sts get-caller-identity`
3. **Check database status**: AWS Console → RDS
4. **View CloudWatch logs** for Lambda-based migrations

## 🎯 Quick Reference

```bash
# Get database connection info
npm run db-endpoint:dev
npm run db-endpoint:prod

# Run manual migrations
npm run migrate:dev
npm run migrate:prod

# Deploy with automatic migration
cdk deploy --context environment=dev
cdk deploy --context environment=prod
```