import type { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import {
  createSuccessResponse,
  createErrorResponse,
  getUserIdFromEvent,
  validateRequiredFields,
  generateId
} from '../common/utils';
import { db } from '../common/database';
import { CreateTransactionRequest, Transaction } from '../common/types';

/**
 * POST /transactions
 * Creates a new transaction
 *
 * Body:
 * {
 *   "amount": -45.67,
 *   "category": "Food",
 *   "description": "Lunch at cafe", // optional
 *   "date": "2024-01-15"
 * }
 */
export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  try {
    console.log('PostTransaction handler called', {
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

    // Parse request body
    let requestBody: CreateTransactionRequest;
    try {
      if (!event.body) {
        return createErrorResponse(
          'BAD_REQUEST',
          'Request body is required',
          400
        );
      }
      requestBody = JSON.parse(event.body);
    } catch (parseError) {
      return createErrorResponse(
        'BAD_REQUEST',
        'Invalid JSON in request body',
        400
      );
    }

    // Validate required fields
    const validationError = validateRequiredFields(requestBody, ['amount', 'category', 'date']);
    if (validationError) {
      return createErrorResponse(
        'VALIDATION_ERROR',
        validationError,
        400
      );
    }

    // Validate field types and values
    if (typeof requestBody.amount !== 'number') {
      return createErrorResponse(
        'VALIDATION_ERROR',
        'Amount must be a number',
        400
      );
    }

    if (typeof requestBody.category !== 'string' || requestBody.category.trim().length === 0) {
      return createErrorResponse(
        'VALIDATION_ERROR',
        'Category must be a non-empty string',
        400
      );
    }

    // Validate date format
    if (isNaN(Date.parse(requestBody.date))) {
      return createErrorResponse(
        'VALIDATION_ERROR',
        'Invalid date format. Use YYYY-MM-DD format.',
        400
      );
    }

    // Validate optional description
    if (requestBody.description !== undefined && typeof requestBody.description !== 'string') {
      return createErrorResponse(
        'VALIDATION_ERROR',
        'Description must be a string',
        400
      );
    }

    // Create new transaction
    const transactionId = generateId();
    const newTransaction: Omit<Transaction, 'createdAt' | 'updatedAt'> = {
      id: transactionId,
      userId,
      amount: requestBody.amount,
      category: requestBody.category.trim(),
      description: requestBody.description?.trim() || undefined,
      date: requestBody.date
    };

    console.log('Creating new transaction:', newTransaction);

    // Save to database
    const createdTransaction = await db.createTransaction(newTransaction);

    console.log(`Successfully created transaction ${transactionId} for user ${userId}`);

    return createSuccessResponse(createdTransaction, 201);

  } catch (error) {
    console.error('Error in PostTransaction handler:', error);

    return createErrorResponse(
      'INTERNAL_SERVER_ERROR',
      'An unexpected error occurred while creating the transaction',
      500
    );
  }
};
