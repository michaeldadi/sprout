import type { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import {
  createSuccessResponse,
  createErrorResponse,
  getUserIdFromEvent,
  isValidUUID
} from '../common/utils';
import { db } from '../common/database';
import { UpdateTransactionRequest } from '../common/types';

/**
 * PATCH /transactions/{id}
 * Updates an existing transaction
 *
 * Path Parameters:
 * - id: Transaction ID
 *
 * Body (all fields optional):
 * {
 *   "amount": -50.00,
 *   "category": "Entertainment",
 *   "description": "Movie tickets",
 *   "date": "2024-01-16"
 * }
 */
export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  try {
    console.log('PatchTransaction handler called', {
      pathParameters: event.pathParameters,
      body: event.body,
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

    // Parse request body
    let updates: UpdateTransactionRequest;
    try {
      if (!event.body) {
        return createErrorResponse(
          'BAD_REQUEST',
          'Request body is required',
          400
        );
      }
      updates = JSON.parse(event.body);
    } catch (parseError) {
      return createErrorResponse(
        'BAD_REQUEST',
        'Invalid JSON in request body',
        400
      );
    }

    // Validate that at least one field is being updated
    const updateFields = Object.keys(updates);
    if (updateFields.length === 0) {
      return createErrorResponse(
        'BAD_REQUEST',
        'At least one field must be provided for update',
        400
      );
    }

    // Validate individual fields if provided
    if (updates.amount !== undefined && typeof updates.amount !== 'number') {
      return createErrorResponse(
        'VALIDATION_ERROR',
        'Amount must be a number',
        400
      );
    }

    if (updates.category !== undefined) {
      if (typeof updates.category !== 'string' || updates.category.trim().length === 0) {
        return createErrorResponse(
          'VALIDATION_ERROR',
          'Category must be a non-empty string',
          400
        );
      }
      updates.category = updates.category.trim();
    }

    if (updates.date !== undefined && isNaN(Date.parse(updates.date))) {
      return createErrorResponse(
        'VALIDATION_ERROR',
        'Invalid date format. Use YYYY-MM-DD format.',
        400
      );
    }

    if (updates.description !== undefined && typeof updates.description !== 'string') {
      return createErrorResponse(
        'VALIDATION_ERROR',
        'Description must be a string',
        400
      );
    } else if (updates.description !== undefined) {
      updates.description = updates.description.trim();
    }

    console.log(`Updating transaction ${transactionId} for user ${userId}:`, updates);

    // Check if transaction exists and belongs to user
    const existingTransaction = await db.getTransactionById(transactionId, userId);
    if (!existingTransaction) {
      return createErrorResponse(
        'NOT_FOUND',
        'Transaction not found or does not belong to user',
        404
      );
    }

    // Update transaction in database
    const updatedTransaction = await db.updateTransaction(transactionId, userId, updates);

    if (!updatedTransaction) {
      return createErrorResponse(
        'INTERNAL_SERVER_ERROR',
        'Failed to update transaction',
        500
      );
    }

    console.log(`Successfully updated transaction ${transactionId} for user ${userId}`);

    return createSuccessResponse(updatedTransaction);

  } catch (error) {
    console.error('Error in PatchTransaction handler:', error);

    return createErrorResponse(
      'INTERNAL_SERVER_ERROR',
      'An unexpected error occurred while updating the transaction',
      500
    );
  }
};
