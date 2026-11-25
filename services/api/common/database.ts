import { Transaction } from './types';

/** The transaction store has not been selected or connected yet. */
export class StorageUnavailableError extends Error {
  constructor() {
    super('Transaction storage is not configured');
    this.name = 'StorageUnavailableError';
  }
}

// Keep the API boundary explicit until a real, user-scoped store is wired in.
// Returning sample records or acknowledging writes here would corrupt sync state.
export class DatabaseService {
  async getTransactionsByUserId(
    _userId: string,
    _lastEvaluatedKey?: string,
    _limit: number = 50
  ): Promise<{ transactions: Transaction[]; lastEvaluatedKey?: string }> {
    throw new StorageUnavailableError();
  }

  async createTransaction(
    _transaction: Omit<Transaction, 'createdAt' | 'updatedAt'>
  ): Promise<Transaction> {
    throw new StorageUnavailableError();
  }

  async updateTransaction(
    _id: string,
    _userId: string,
    _updates: Partial<Omit<Transaction, 'id' | 'userId' | 'createdAt' | 'updatedAt'>>
  ): Promise<Transaction | null> {
    throw new StorageUnavailableError();
  }

  async deleteTransaction(_id: string, _userId: string): Promise<boolean> {
    throw new StorageUnavailableError();
  }

  async getTransactionById(_id: string, _userId: string): Promise<Transaction | null> {
    throw new StorageUnavailableError();
  }
}

export const db = new DatabaseService();
