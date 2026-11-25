import type { APIGatewayProxyHandler } from 'aws-lambda';
import { StreamChat } from 'stream-chat';
import { getUserIdFromEvent } from '../common/utils';

// Stream Chat configuration
export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const userId = getUserIdFromEvent(event);
    if (!userId) {
      return {
        statusCode: 401,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ error: 'Unauthorized' }),
      };
    }

    const apiKey = process.env.STREAM_API_KEY;
    const apiSecret = process.env.STREAM_API_SECRET;
    if (!apiKey || !apiSecret) {
      return {
        statusCode: 503,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ error: 'Chat is unavailable' }),
      };
    }

    const claims = (event.requestContext.authorizer as any)?.jwt?.claims
      ?? (event.requestContext.authorizer as any)?.claims ?? {};
    const email = claims.email;
    const username = claims['cognito:username'] || claims.username;
    const name = claims.name || claims.given_name || username || email;
    const serverClient = StreamChat.getInstance(apiKey, apiSecret);

    // Create or update the user in Stream Chat
    try {
      await serverClient.upsertUser({
        id: userId,
        name: typeof name === 'string' ? name : userId,
        email: typeof email === 'string' ? email : undefined,
        role: 'user',
      });
    } catch (error) {
      console.error('Error upserting user:', error);
      return {
        statusCode: 502,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ error: 'Chat is unavailable' }),
      };
    }

    // Generate Stream Chat token
    const token = serverClient.createToken(userId);

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        token,
        userId,
        apiKey,
      }),
    };

  } catch (error) {
    console.error('Stream token generation error:', error);

    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        error: 'Failed to generate Stream token'
      }),
    };
  }
};
