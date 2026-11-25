import { APIGatewayProxyHandler } from 'aws-lambda';
import {
  CognitoIdentityProviderClient,
  AdminCreateUserCommand,
  AdminSetUserPasswordCommand,
  AdminInitiateAuthCommand,
  AdminUpdateUserAttributesCommand,
  AdminGetUserCommand
} from '@aws-sdk/client-cognito-identity-provider';
import * as jwt from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';

const cognito = new CognitoIdentityProviderClient({});
const USER_POOL_ID = process.env.USER_POOL_ID!;
const CLIENT_ID = process.env.CLIENT_ID!;

// Apple's public key endpoint
const client = jwksClient({
  jwksUri: 'https://appleid.apple.com/auth/keys',
  cache: true,
  cacheMaxAge: 86400000, // 24 hours
});

interface AppleIdToken {
  iss: string;
  aud: string;
  exp: number;
  iat: number;
  sub: string; // Apple user ID
  email?: string;
  email_verified?: string;
  auth_time: number;
  nonce_supported: boolean;
  real_user_status?: number;
}

async function getApplePublicKey(kid: string): Promise<string> {
  return new Promise((resolve, reject) => {
    client.getSigningKey(kid, (err, key) => {
      if (err) {
        reject(err);
      } else {
        const signingKey = key?.getPublicKey();
        if (!signingKey) {
          reject(new Error('Could not get public key'));
        } else {
          resolve(signingKey);
        }
      }
    });
  });
}

async function verifyAppleToken(idToken: string): Promise<AppleIdToken> {
  // Decode the token header to get the key ID
  const decoded = jwt.decode(idToken, { complete: true });
  if (!decoded || typeof decoded === 'string') {
    throw new Error('Invalid token');
  }

  const { kid } = decoded.header;
  if (!kid) {
    throw new Error('No kid in token header');
  }

  // Get Apple's public key
  const publicKey = await getApplePublicKey(kid);

  // Verify the token
  const verified = jwt.verify(idToken, publicKey, {
    algorithms: ['RS256'],
    issuer: 'https://appleid.apple.com',
    audience: process.env.APPLE_CLIENT_ID || 'com.michaeldadi.sprout', // Your Apple app ID
  }) as AppleIdToken;

  return verified;
}

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    // Parse request body
    const body = JSON.parse(event.body || '{}');
    const { idToken, authorizationCode, fullName } = body;

    if (!idToken) {
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ error: 'Missing idToken' }),
      };
    }

    // Verify Apple ID token
    const appleUser = await verifyAppleToken(idToken);

    // Create username from Apple ID (prefixed to avoid conflicts)
    const username = `apple_${appleUser.sub}`;
    const email = appleUser.email || `${appleUser.sub}@privaterelay.appleid.com`;

    // Check if user already exists
    let userExists = false;
    try {
      await cognito.send(new AdminGetUserCommand({
        UserPoolId: USER_POOL_ID,
        Username: username,
      }));
      userExists = true;
    } catch (error: any) {
      if (error.name !== 'UserNotFoundException') {
        throw error;
      }
    }

    // Create user if doesn't exist
    if (!userExists) {
      // Create the user
      await cognito.send(new AdminCreateUserCommand({
        UserPoolId: USER_POOL_ID,
        Username: username,
        UserAttributes: [
          { Name: 'email', Value: email },
          { Name: 'email_verified', Value: 'true' }, // Apple has verified the email
          { Name: 'custom:apple_sub', Value: appleUser.sub },
          ...(fullName ? [
            { Name: 'given_name', Value: fullName.split(' ')[0] || '' },
            { Name: 'family_name', Value: fullName.split(' ').slice(1).join(' ') || '' },
            { Name: 'name', Value: fullName }
          ] : []),
        ],
        MessageAction: 'SUPPRESS', // Don't send welcome email
      }));

      // Set a permanent dummy password (user won't use it, they'll use Apple Sign In)
      const dummyPassword = `Apple_${appleUser.sub}_${Date.now()}`;
      await cognito.send(new AdminSetUserPasswordCommand({
        UserPoolId: USER_POOL_ID,
        Username: username,
        Password: dummyPassword,
        Permanent: true,
      }));
    }

    // Generate Cognito tokens using custom auth flow
    // Note: This requires setting up a custom auth flow in Cognito
    // For now, we'll use admin auth flow with the dummy password
    const authResponse = await cognito.send(new AdminInitiateAuthCommand({
      UserPoolId: USER_POOL_ID,
      ClientId: CLIENT_ID,
      AuthFlow: 'ADMIN_NO_SRP_AUTH',
      AuthParameters: {
        USERNAME: username,
        // In production, you'd use a custom auth flow instead of password
      },
    }));

    if (!authResponse.AuthenticationResult) {
      throw new Error('Authentication failed');
    }

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        accessToken: authResponse.AuthenticationResult.AccessToken,
        idToken: authResponse.AuthenticationResult.IdToken,
        refreshToken: authResponse.AuthenticationResult.RefreshToken,
        expiresIn: authResponse.AuthenticationResult.ExpiresIn,
      }),
    };

  } catch (error) {
    console.error('Apple Sign In error:', error);

    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        error: 'Authentication failed',
        message: error instanceof Error ? error.message : 'Unknown error'
      }),
    };
  }
};
