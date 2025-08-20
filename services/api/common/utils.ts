import { APIResponse, ErrorResponse } from './types';

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS'
};

export function createResponse<T>(
  statusCode: number,
  body: T,
  additionalHeaders: Record<string, string> = {}
): APIResponse<T> {
  return {
    statusCode,
    body: JSON.stringify(body),
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders,
      ...additionalHeaders
    }
  };
}

export function createSuccessResponse<T>(data: T, statusCode: number = 200): APIResponse<T> {
  return createResponse(statusCode, data);
}

export function createErrorResponse(
  error: string,
  message: string,
  statusCode: number = 400
): APIResponse<ErrorResponse> {
  const errorBody: ErrorResponse = {
    error,
    message,
    timestamp: new Date().toISOString()
  };
  return createResponse(statusCode, errorBody);
}

export function getUserIdFromEvent(event: any): string | null {
  // Extract user ID from JWT claims or API Gateway authorizer context
  const claims = event.requestContext?.authorizer?.claims;
  if (claims?.sub) {
    return claims.sub;
  }

  // Fallback for local development or different auth setup
  const userId = event.headers?.['x-user-id'] || event.headers?.['X-User-Id'];
  return userId || null;
}

export function validateRequiredFields(body: any, fields: string[]): string | null {
  for (const field of fields) {
    if (!body[field] && body[field] !== 0) {
      return `Missing required field: ${field}`;
    }
  }
  return null;
}

export function generateId(): string {
  return Date.now().toString(36) + Math.random().toString(36).substring(2);
}

export function isValidUUID(id: string): boolean {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRegex.test(id) || /^[a-z0-9]{8,}$/.test(id); // Allow generated IDs too
}
