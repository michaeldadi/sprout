// Database abstraction layer for DynamoDB operations
import { Transaction } from './types';

// Mock database operations for now - in a real app, you'd use AWS SDK DynamoDB client
export class DatabaseService {
  private tableName: string;

  constructor() {
    this.tableName = process.env.DYNAMODB_TABLE_NAME || 'sprout-transactions';
  }

  async getTransactionsByUserId(
    userId: string,
    lastEvaluatedKey?: string,
    limit: number = 50
  ): Promise<{ transactions: Transaction[]; lastEvaluatedKey?: string }> {
    // Mock implementation - replace with actual DynamoDB query
    console.log(`Fetching transactions for user ${userId}, limit: ${limit}, cursor: ${lastEvaluatedKey}`);
    
    // Simulate some sample data
    const mockTransactions: Transaction[] = [
      {
        id: 'txn_001',
        userId,
        amount: -45.67,
        category: 'Food',
        description: 'Lunch at cafe',
        date: '2024-01-15',
        createdAt: '2024-01-15T12:30:00Z',
        updatedAt: '2024-01-15T12:30:00Z'
      },
      {
        id: 'txn_002',
        userId,
        amount: -23.50,
        category: 'Transport',
        description: 'Uber ride',
        date: '2024-01-14',
        createdAt: '2024-01-14T18:45:00Z',
        updatedAt: '2024-01-14T18:45:00Z'
      }
    ];

    return {
      transactions: mockTransactions,
      lastEvaluatedKey: undefined // No more pages
    };
  }

  async createTransaction(transaction: Omit<Transaction, 'createdAt' | 'updatedAt'>): Promise<Transaction> {
    console.log('Creating transaction:', transaction);
    
    const now = new Date().toISOString();
    const newTransaction: Transaction = {
      ...transaction,
      createdAt: now,
      updatedAt: now
    };

    // Mock DynamoDB putItem operation
    // await dynamoDb.putItem({
    //   TableName: this.tableName,
    //   Item: marshall(newTransaction)
    // }).promise();

    return newTransaction;
  }

  async updateTransaction(
    id: string, 
    userId: string, 
    updates: Partial<Omit<Transaction, 'id' | 'userId' | 'createdAt' | 'updatedAt'>>
  ): Promise<Transaction | null> {
    console.log(`Updating transaction ${id} for user ${userId}:`, updates);

    // Mock update operation
    const updatedTransaction: Transaction = {
      id,
      userId,
      amount: updates.amount ?? -45.67,
      category: updates.category ?? 'Food',
      description: updates.description ?? 'Updated transaction',
      date: updates.date ?? '2024-01-15',
      receiptUrl: updates.receiptUrl,
      createdAt: '2024-01-15T12:30:00Z',
      updatedAt: new Date().toISOString()
    };

    return updatedTransaction;
  }

  async deleteTransaction(id: string, userId: string): Promise<boolean> {
    console.log(`Deleting transaction ${id} for user ${userId}`);
    
    // Mock DynamoDB deleteItem operation
    // await dynamoDb.deleteItem({
    //   TableName: this.tableName,
    //   Key: marshall({ id, userId })
    // }).promise();

    return true;
  }

  async getTransactionById(id: string, userId: string): Promise<Transaction | null> {
    console.log(`Getting transaction ${id} for user ${userId}`);
    
    // Mock get operation
    if (id === 'txn_001') {
      return {
        id: 'txn_001',
        userId,
        amount: -45.67,
        category: 'Food',
        description: 'Lunch at cafe',
        date: '2024-01-15',
        createdAt: '2024-01-15T12:30:00Z',
        updatedAt: '2024-01-15T12:30:00Z'
      };
    }

    return null;
  }
}

export const db = new DatabaseService();