import type { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import {
  createSuccessResponse,
  createErrorResponse,
  getUserIdFromEvent
} from '../common/utils';

/**
 * POST /uploads/receipt-url
 * Creates a pre-signed URL for uploading receipt images to S3
 *
 * Body:
 * {
 *   "fileName": "receipt.jpg",
 *   "contentType": "image/jpeg",
 *   "transactionId": "txn_123" // optional, for associating with specific transaction
 * }
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

    // Parse request body
    let requestBody: {
      fileName: string;
      contentType: string;
      transactionId?: string;
    };

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
    if (!requestBody.fileName || typeof requestBody.fileName !== 'string') {
      return createErrorResponse(
        'VALIDATION_ERROR',
        'fileName is required and must be a string',
        400
      );
    }

    if (!requestBody.contentType || typeof requestBody.contentType !== 'string') {
      return createErrorResponse(
        'VALIDATION_ERROR',
        'contentType is required and must be a string',
        400
      );
    }

    // Validate content type (only allow images)
    const allowedContentTypes = [
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/gif',
      'image/webp'
    ];

    if (!allowedContentTypes.includes(requestBody.contentType.toLowerCase())) {
      return createErrorResponse(
        'VALIDATION_ERROR',
        'Only image files are allowed (JPEG, PNG, GIF, WebP)',
        400
      );
    }

    // Validate file extension matches content type
    const fileName = requestBody.fileName.toLowerCase();
    const validExtensions: Record<string, string[]> = {
      'image/jpeg': ['.jpg', '.jpeg'],
      'image/png': ['.png'],
      'image/gif': ['.gif'],
      'image/webp': ['.webp']
    };

    const expectedExtensions = validExtensions[requestBody.contentType.toLowerCase()] || [];
    const hasValidExtension = expectedExtensions.some(ext => fileName.endsWith(ext));

    if (!hasValidExtension) {
      return createErrorResponse(
        'VALIDATION_ERROR',
        `File extension does not match content type. Expected: ${expectedExtensions.join(', ')}`,
        400
      );
    }

    // The storage provider and private download contract are still open.
    // A plain bucket URL is neither signed nor usable with the private bucket.
    return createErrorResponse('UPLOAD_UNAVAILABLE', 'Receipt uploads are unavailable', 503);

  } catch (error) {
    console.error('Error in CreateReceiptUrl handler:', error);

    return createErrorResponse(
      'INTERNAL_SERVER_ERROR',
      'An unexpected error occurred while creating upload URL',
      500
    );
  }
};
