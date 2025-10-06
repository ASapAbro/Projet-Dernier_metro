const request = require('supertest');
const { testConnection, logApiRequest } = require('../src/database');

// Import de l'app sans démarrer le serveur
let app;

describe('API Endpoints', () => {
  beforeAll(() => {
    // Import dynamique pour éviter les problèmes de mock
    app = require('../server');
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('GET /health', () => {
    it('devrait retourner 200 avec statut OK quand la DB est connectée', async () => {
      testConnection.mockResolvedValue(true);

      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body).toHaveProperty('status', 'ok');
      expect(response.body).toHaveProperty('database', 'connected');
      expect(response.body).toHaveProperty('timestamp');
      expect(testConnection).toHaveBeenCalled();
    });

    it('devrait retourner 503 quand la DB n\'est pas connectée', async () => {
      testConnection.mockResolvedValue(false);

      const response = await request(app)
        .get('/health')
        .expect(503);

      expect(response.body).toHaveProperty('error', 'database connection failed');
      expect(response.body).toHaveProperty('status', 'unhealthy');
    });

    it('devrait gérer les erreurs de test de connexion', async () => {
      testConnection.mockRejectedValue(new Error('Connection timeout'));

      const response = await request(app)
        .get('/health')
        .expect(503);

      expect(response.body).toHaveProperty('error', 'health check failed');
      expect(response.body).toHaveProperty('message', 'Connection timeout');
    });
  });

  describe('GET /next-metro', () => {
    it('devrait retourner 400 si le paramètre station manque', async () => {
      const response = await request(app)
        .get('/next-metro')
        .expect(400);

      expect(response.body).toHaveProperty('error', 'missing station');
    });

    it('devrait retourner les en-têtes JSON corrects', async () => {
      const response = await request(app)
        .get('/next-metro');

      expect(response.headers['content-type']).toMatch(/application\/json/);
    });
  });

  describe('GET /stations', () => {
    it('devrait avoir le bon content-type', async () => {
      const response = await request(app)
        .get('/stations');

      expect(response.headers['content-type']).toMatch(/application\/json/);
    });
  });

  describe('GET /api-docs.json', () => {
    it('devrait retourner la spécification OpenAPI', async () => {
      const response = await request(app)
        .get('/api-docs.json')
        .expect(200);

      expect(response.headers['content-type']).toMatch(/application\/json/);
      expect(response.body).toHaveProperty('openapi');
      expect(response.body).toHaveProperty('info');
      expect(response.body.info).toHaveProperty('title', 'Dernier Metro Paris API');
    });
  });

  describe('GET /*', () => {
    it('devrait retourner 404 pour les routes inexistantes', async () => {
      const response = await request(app)
        .get('/route-inexistante')
        .expect(404);

      expect(response.body).toHaveProperty('error', 'route not found');
    });

    it('devrait retourner du JSON pour les 404', async () => {
      const response = await request(app)
        .get('/another-missing-route')
        .expect(404);

      expect(response.headers['content-type']).toMatch(/application\/json/);
    });
  });

  describe('Middleware de logging', () => {
    it('devrait logger les requêtes API', async () => {
      logApiRequest.mockResolvedValue();

      await request(app)
        .get('/health');

      // Le log est asynchrone, on attend un peu
      await new Promise(resolve => setTimeout(resolve, 100));

      expect(logApiRequest).toHaveBeenCalledWith(
        'GET',
        '/health',
        expect.any(Number), // status code
        expect.any(Number), // duration
        expect.any(String), // user agent
        expect.any(String), // ip
        null, // query params
        null  // response data
      );
    });
  });
});
