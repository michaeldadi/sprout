import type { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import {
  createSuccessResponse,
  createErrorResponse,
  getUserIdFromEvent,
  isValidUUID
} from '../common/utils';
import { db } from '../common/database';

/**
 * DELETE /transactions/{id}
 * Deletes an existing transaction
 *
 * Path Parameters:
 * - id: Transaction ID
 */
export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  try {
    console.log('DeleteTransaction handler called', {
      pathParameters: event.pathParameters,
      headers: event.headers
    });

    // Handle CORS preflight
    if (event.httpMethod === 'OPTIONS') {
      return createSuccessResponse({});
    }

    // Get user ID from JWT token or headers
    const userId = getUserIdFromEvent(event);
    if (!userId) {
      return createErrorResponse(
        'UNAUTHORIZED',
        'User ID not found in request context',
        401
      );
    }

    // Get transaction ID from path parameters
    const transactionId = event.pathParameters?.id;
    if (!transactionId) {
      return createErrorResponse(
        'BAD_REQUEST',
        'Transaction ID is required in path',
        400
      );
    }

    // Validate transaction ID format
    if (!isValidUUID(transactionId)) {
      return createErrorResponse(
        'BAD_REQUEST',
        'Invalid transaction ID format',
        400
      );
    }

    console.log(`Deleting transaction ${transactionId} for user ${userId}`);

    // Check if transaction exists and belongs to user
    const existingTransaction = await db.getTransactionById(transactionId, userId);
    if (!existingTransaction) {
      return createErrorResponse(
        'NOT_FOUND',
        'Transaction not found or does not belong to user',
        404
      );
    }

    // Delete transaction from database
    const deleted = await db.deleteTransaction(transactionId, userId);

    if (!deleted) {
      return createErrorResponse(
        'INTERNAL_SERVER_ERROR',
        'Failed to delete transaction',
        500
      );
    }

    console.log(`Successfully deleted transaction ${transactionId} for user ${userId}`);

    // Return 204 No Content for successful deletion
    return {
      statusCode: 204,
      body: '',
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS'
      }
    };

  } catch (error) {
    console.error('Error in DeleteTransaction handler:', error);

    return createErrorResponse(
      'INTERNAL_SERVER_ERROR',
      'An unexpected error occurred while deleting the transaction',
      500
    );
  }
};
