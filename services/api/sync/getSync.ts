import type { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import {
  createSuccessResponse,
  createErrorResponse,
  getUserIdFromEvent
} from '../common/utils';
import { db, StorageUnavailableError } from '../common/database';
import { SyncData } from '../common/types';

/**
 * GET /sync
 * Synchronizes user's transaction data
 *
 * Query Parameters:
 * - cursor: Optional cursor for pagination
 * - limit: Number of transactions to return (default: 50, max: 100)
 * - since: ISO date string to get transactions modified since this date
 */
export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  try {
    // Handle CORS preflight
    if (event.httpMethod === 'OPTIONS') {
      return createSuccessResponse({});
    }

    // Get user ID from the authorizer's verified JWT claims.
    const userId = getUserIdFromEvent(event);
    if (!userId) {
      return createErrorResponse(
        'UNAUTHORIZED',
        'User ID not found in request context',
        401
      );
    }

    // Parse query parameters
    const queryParams = event.queryStringParameters || {};
    const cursor = queryParams.cursor;
    const limit = Math.min(parseInt(queryParams.limit || '50'), 100);
    const since = queryParams.since;

    // Validate since parameter if provided
    if (since && isNaN(Date.parse(since))) {
      return createErrorResponse(
        'INVALID_PARAMETER',
        'Invalid date format for "since" parameter. Use ISO 8601 format.',
        400
      );
    }

    // Fetch transactions from database
    const result = await db.getTransactionsByUserId(userId, cursor, limit);

    // Filter by since date if provided
    let transactions = result.transactions;
    if (since) {
      const sinceDate = new Date(since);
      transactions = transactions.filter(txn =>
        new Date(txn.updatedAt) > sinceDate
      );
    }

    // Prepare sync response
    const syncData: SyncData = {
      transactions,
      lastSync: new Date().toISOString(),
      hasMore: !!result.lastEvaluatedKey,
      nextCursor: result.lastEvaluatedKey
    };

    return createSuccessResponse(syncData);

  } catch (error) {
    if (error instanceof StorageUnavailableError) {
      return createErrorResponse('STORAGE_UNAVAILABLE', 'Transaction sync is unavailable', 503);
    }
    console.error('Error in GetSync handler:', error);

    return createErrorResponse(
      'INTERNAL_SERVER_ERROR',
      'An unexpected error occurred while syncing data',
      500
    );
  }
};
