// Common types for Sprout API

export interface Transaction {
  id: string;
  userId: string;
  amount: number;
  category: string;
  description?: string;
  date: string;
  receiptUrl?: string;
  createdAt: string;
  updatedAt: string;
}

export interface SyncData {
  transactions: Transaction[];
  lastSync: string;
  hasMore: boolean;
  nextCursor?: string;
}

export interface CreateTransactionRequest {
  amount: number;
  category: string;
  description?: string;
  date: string;
}

export interface UpdateTransactionRequest {
  amount?: number;
  category?: string;
  description?: string;
  date?: string;
}

export interface APIResponse<T = any> {
  statusCode: number;
  body: string;
  headers: {
    'Content-Type': string;
    'Access-Control-Allow-Origin': string;
    'Access-Control-Allow-Headers': string;
    'Access-Control-Allow-Methods': string;
  };
}

export interface ErrorResponse {
  error: string;
  message: string;
  timestamp: string;
}