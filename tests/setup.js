// Configuration globale pour les tests
process.env.NODE_ENV = 'test';
process.env.DB_HOST = 'localhost';
process.env.DB_PORT = '5432';
process.env.DB_NAME = 'dernier_metro_test';
process.env.DB_USER = 'metro_user';
process.env.DB_PASSWORD = 'metro_password';

// Mock du module database pour éviter les vraies connexions DB dans les tests unitaires
jest.mock('../src/database', () => ({
  query: jest.fn(),
  testConnection: jest.fn(),
  closePool: jest.fn(),
  logApiRequest: jest.fn()
}));

// Timeout global pour les tests
jest.setTimeout(10000);
