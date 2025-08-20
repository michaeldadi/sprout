# Sprout Database Setup

This directory contains database migration scripts and setup for the Sprout application's PostgreSQL database.

## Database Architecture

### Development Environment
- **Database Type**: Single RDS PostgreSQL instance
- **Instance Type**: db.t3.micro (cost-effective for dev)
- **Storage**: 20GB with auto-scaling up to 50GB
- **Backup**: 7-day retention
- **Multi-AZ**: Disabled (single AZ for cost savings)

### Production Environment
- **Database Type**: Aurora Serverless v2 Cluster
- **Scaling**: 1-16 ACUs (Auto-scaling based on load)
- **Storage**: Auto-scaling Aurora storage
- **Backup**: 30-day retention
- **Multi-AZ**: Enabled for high availability
- **Deletion Protection**: Enabled

## Environment Configuration

### Required Environment Variables

For the CDK deployment, set these in GitHub Secrets:

**Development:**
- `DB_NAME_DEV`: Database name (e.g., `sprout_dev`)

**Production:**
- `DB_NAME_PROD`: Database name (e.g., `sprout_prod`)

### Database Credentials

Database credentials are automatically generated and stored in AWS Secrets Manager:
- Dev: `sprout-db-credentials-dev`
- Prod: `sprout-db-credentials-prod`

## Deployment

### Deploy Dev Environment
```bash
cd infra
cdk deploy --context environment=dev
```

### Deploy Prod Environment
```bash
cd infra
cdk deploy --context environment=prod
```

## Database Connection

### From Lambda Functions
Use the AWS SDK to retrieve credentials from Secrets Manager:

```javascript
const AWS = require('aws-sdk');
const secretsManager = new AWS.SecretsManager();

const secret = await secretsManager.getSecretValue({
  SecretId: 'sprout-db-credentials-prod'
}).promise();

const credentials = JSON.parse(secret.SecretString);
// credentials.username and credentials.password
```

### Connection String Format
```
postgresql://{{username}}:{{password}}@{{endpoint}}:5432/{{database_name}}
```

## Migrations

### Running Initial Migration
1. Connect to the database using credentials from Secrets Manager
2. Run the migration file: `001_initial_schema.sql`

### Future Migrations
- Create new `.sql` files with incremental numbering
- Document schema changes
- Test in dev environment first

## Database Schema

The initial schema includes:

- **users**: User profiles (linked to Cognito)
- **categories**: Transaction categories
- **accounts**: Bank accounts, credit cards, etc.
- **transactions**: Financial transactions
- **budgets**: Budget tracking
- **goals**: Financial goals
- **recurring_transactions**: Recurring/scheduled transactions

## Security

- Database is deployed in private subnets
- Security groups restrict access to VPC only
- Credentials stored in AWS Secrets Manager
- SSL/TLS encryption enforced
- Deletion protection enabled in production

## Monitoring

- CloudWatch metrics enabled
- Performance Insights available
- Automated backups configured
- Maintenance windows scheduled for off-peak hours

## Cost Optimization

### Development
- Single instance instead of cluster
- Smaller instance type
- Shorter backup retention
- No deletion protection

### Production
- Aurora Serverless v2 for automatic scaling
- Only pay for actual usage
- Built-in high availability
- Automated backups and monitoring