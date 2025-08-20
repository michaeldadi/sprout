import type { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import {
  createSuccessResponse,
  createErrorResponse,
  getUserIdFromEvent,
  generateId
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
    console.log('CreateReceiptUrl handler called', {
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

    // Generate unique file key for S3
    const fileExtension = requestBody.fileName.substring(requestBody.fileName.lastIndexOf('.'));
    const uniqueFileName = `receipts/${userId}/${generateId()}${fileExtension}`;

    // S3 bucket configuration
    const bucketName = process.env.RECEIPTS_BUCKET_NAME || 'sprout-receipts-dev';
    const region = process.env.AWS_REGION || 'us-east-1';

    // In a real implementation, you would use AWS SDK to generate pre-signed URL
    // For now, we'll return a mock pre-signed URL structure
    const presignedUrl = `https://${bucketName}.s3.${region}.amazonaws.com/${uniqueFileName}`;
    const publicUrl = `https://${bucketName}.s3.${region}.amazonaws.com/${uniqueFileName}`;

    console.log('Generated upload URLs:', {
      userId,
      fileName: requestBody.fileName,
      uniqueFileName,
      transactionId: requestBody.transactionId
    });

    // Mock S3 pre-signed URL generation
    // In real implementation:
    // const s3 = new AWS.S3();
    // const presignedUrl = s3.getSignedUrl('putObject', {
    //   Bucket: bucketName,
    //   Key: uniqueFileName,
    //   ContentType: requestBody.contentType,
    //   Expires: 3600, // 1 hour
    //   Conditions: [
    //     ['content-length-range', 0, 10485760] // 10MB max
    //   ]
    // });

    const response = {
      uploadUrl: presignedUrl,
      publicUrl: publicUrl,
      fileName: uniqueFileName,
      contentType: requestBody.contentType,
      expiresIn: 3600, // 1 hour in seconds
      maxFileSize: 10485760, // 10MB in bytes
      transactionId: requestBody.transactionId
    };

    console.log(`Successfully created upload URL for user ${userId}`);

    return createSuccessResponse(response, 201);

  } catch (error) {
    console.error('Error in CreateReceiptUrl handler:', error);

    return createErrorResponse(
      'INTERNAL_SERVER_ERROR',
      'An unexpected error occurred while creating upload URL',
      500
    );
  }
};
