import { Construct } from 'constructs';
import {
    OAuthScope,
    UserPool,
    UserPoolClient,
    AccountRecovery,
    Mfa,
} from 'aws-cdk-lib/aws-cognito';
import { Duration } from 'aws-cdk-lib';

export interface AuthConstructProps {
    environment: string;
}

export class AuthConstruct extends Construct {
    public readonly userPool: UserPool;
    public readonly userPoolClient: UserPoolClient;

    constructor(scope: Construct, id: string, props: AuthConstructProps) {
        super(scope, id);

        this.userPool = new UserPool(this, 'UserPool', {
            userPoolName: `sprout-user-pool-${props.environment}`,
            selfSignUpEnabled: true,
            signInAliases: { email: true },
            autoVerify: { email: true },
            accountRecovery: AccountRecovery.EMAIL_ONLY,
            mfa: Mfa.OFF,
        });

        this.userPoolClient = new UserPoolClient(this, 'UserPoolClient', {
            userPool: this.userPool,
            userPoolClientName: `sprout-user-pool-client-${props.environment}`,
            authFlows: {
                userPassword: true,
                userSrp: true
            },
            oAuth: {
                scopes: [OAuthScope.OPENID, OAuthScope.EMAIL]
            },
            accessTokenValidity: Duration.hours(1),
            idTokenValidity: Duration.hours(1),
            refreshTokenValidity: Duration.days(30)
        });
    }
}
