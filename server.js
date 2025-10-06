const express = require('express');
const swaggerUi = require('swagger-ui-express');
const swaggerSpec = require('./swagger');
const { testConnection, logApiRequest, closePool } = require('./src/database');
const { StationModel, ScheduleModel } = require('./src/models');
const app = express();

// Configuration du port via ENV
const PORT = process.env.PORT || 3002;

// Middleware pour parser le JSON
app.use(express.json());

// Configuration Swagger UI
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
  explorer: true,
  customSiteTitle: "Dernier Metro Paris API"
}));

// Route pour récupérer la spec OpenAPI en JSON
app.get('/api-docs.json', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(swaggerSpec);
});

// Middleware de logging pour chaque requête avec BDD
app.use((req, res, next) => {
  const start = Date.now();
  
  // Intercept la fin de la réponse pour calculer la durée
  const originalSend = res.send;
  res.send = function(data) {
    const duration = Date.now() - start;
    const logMessage = `${req.method} ${req.path} - ${res.statusCode} - ${duration}ms`;
    console.log(logMessage);
    
    // Log asynchrone en base de données
    logApiRequest(
      req.method,
      req.path,
      res.statusCode,
      duration,
      req.get('User-Agent'),
      req.ip,
      Object.keys(req.query).length > 0 ? req.query : null,
      res.statusCode < 400 ? null : JSON.parse(data) // Ne stocker les réponses qu'en cas d'erreur
    ).catch(err => {
      console.error('Erreur log BDD:', err.message);
    });
    
    originalSend.call(this, data);
  };
  
  next();
});

/**
 * @swagger
 * /health:
 *   get:
 *     summary: Vérification de l'état de santé de l'API
 *     description: Endpoint pour vérifier que l'API et la base de données fonctionnent correctement
 *     tags:
 *       - Health
 *     responses:
 *       200:
 *         description: API en bon état de fonctionnement
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/HealthResponse'
 *       503:
 *         description: Problème de connexion à la base de données
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
// Route de santé avec test de la base de données
app.get('/health', async (req, res) => {
  try {
    const dbHealthy = await testConnection();
    
    if (dbHealthy) {
      res.status(200).json({ 
        status: 'ok',
        database: 'connected',
        timestamp: new Date().toISOString()
      });
    } else {
      res.status(503).json({ 
        error: 'database connection failed',
        status: 'unhealthy'
      });
    }
  } catch (err) {
    res.status(503).json({ 
      error: 'health check failed',
      message: err.message 
    });
  }
});

/**
 * @swagger
 * /next-metro:
 *   get:
 *     summary: Informations sur le prochain métro
 *     description: Retourne les informations sur le prochain passage de métro pour une station donnée avec données réelles de la base
 *     tags:
 *       - Metro
 *     parameters:
 *       - in: query
 *         name: station
 *         required: true
 *         description: Nom ou slug de la station de métro
 *         schema:
 *           type: string
 *           example: chatelet
 *     responses:
 *       200:
 *         description: Informations sur le prochain métro
 *         content:
 *           application/json:
 *             schema:
 *               oneOf:
 *                 - $ref: '#/components/schemas/MetroResponse'
 *                 - $ref: '#/components/schemas/MetroClosedResponse'
 *             examples:
 *               service_ouvert:
 *                 summary: Service ouvert
 *                 value:
 *                   station: "Châtelet"
 *                   line: "M1"
 *                   headwayMin: 3
 *                   nextArrival: "12:34"
 *                   isLast: false
 *                   tz: "Europe/Paris"
 *                   dayType: "weekday"
 *               dernier_metro:
 *                 summary: Dernier métro (entre 00:45 et 01:15)
 *                 value:
 *                   station: "Châtelet"
 *                   line: "M1"
 *                   headwayMin: 3
 *                   nextArrival: "01:05"
 *                   isLast: true
 *                   tz: "Europe/Paris"
 *                   dayType: "weekday"
 *               service_ferme:
 *                 summary: Service fermé (après 01:15)
 *                 value:
 *                   station: "Châtelet"
 *                   line: "M1"
 *                   service: "closed"
 *                   tz: "Europe/Paris"
 *       400:
 *         description: Paramètre station manquant
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               error: "missing station"
 *       404:
 *         description: Station non trouvée
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                 suggestions:
 *                   type: array
 *                   items:
 *                     type: string
 *             example:
 *               error: "unknown station"
 *               suggestions: ["Châtelet", "Champs-Élysées"]
 */
// Route principale pour les infos métro avec base de données
app.get('/next-metro', async (req, res) => {
  try {
    const { station } = req.query;
    
    // Validation de la station
    if (!station) {
      return res.status(400).json({ error: 'missing station' });
    }
    
    // Recherche de la station en base
    const stationData = await StationModel.getStationWithLines(station);
    
    if (!stationData) {
      // Station non trouvée, proposer des suggestions
      const suggestions = await StationModel.findSuggestions(station);
      return res.status(404).json({ 
        error: 'unknown station',
        suggestions: suggestions.map(s => s.name)
      });
    }
    
    // Déterminer la ligne principale (prendre la première pour simplifier)
    const primaryLine = stationData.lines.length > 0 ? stationData.lines[0] : { code: 'M1', name: 'Ligne 1' };
    
    // Calcul des infos métro avec les vraies données
    const metroInfo = await ScheduleModel.calculateNextArrival(primaryLine.code);
    
    // Si le service est fermé
    if (metroInfo.service === 'closed') {
      return res.status(200).json({
        station: stationData.name,
        line: primaryLine.code,
        service: 'closed',
        tz: metroInfo.tz
      });
    }
    
    // Réponse normale
    res.status(200).json({
      station: stationData.name,
      line: primaryLine.code,
      headwayMin: metroInfo.headwayMin,
      nextArrival: metroInfo.nextArrival,
      isLast: metroInfo.isLast,
      tz: metroInfo.tz,
      dayType: metroInfo.dayType,
      zone: stationData.zone,
      accessibility: stationData.accessibility
    });
    
  } catch (err) {
    console.error('Erreur /next-metro:', err);
    res.status(500).json({ 
      error: 'internal server error',
      message: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

/**
 * @swagger
 * /stations:
 *   get:
 *     summary: Liste des stations de métro
 *     description: Retourne la liste de toutes les stations disponibles
 *     tags:
 *       - Metro
 *     responses:
 *       200:
 *         description: Liste des stations
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 stations:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       name:
 *                         type: string
 *                       slug:
 *                         type: string
 *                       zone:
 *                         type: integer
 *                       accessibility:
 *                         type: boolean
 *                 count:
 *                   type: integer
 */
// Route pour lister les stations
app.get('/stations', async (req, res) => {
  try {
    const stations = await StationModel.findAll();
    
    res.status(200).json({
      stations: stations.map(station => ({
        name: station.name,
        slug: station.slug,
        zone: station.zone,
        accessibility: station.accessibility
      })),
      count: stations.length
    });
  } catch (err) {
    console.error('Erreur /stations:', err);
    res.status(500).json({ 
      error: 'internal server error',
      message: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Middleware 404 pour toutes les autres routes
app.use('*', (req, res) => {
  res.status(404).json({ error: 'route not found' });
});

// Démarrage du serveur
const server = app.listen(PORT, async () => {
  console.log(`🚇 Dernier Metro API running on port ${PORT}`);
  console.log(`📍 Health check: http://localhost:${PORT}/health`);
  console.log(`🚊 Metro info: http://localhost:${PORT}/next-metro?station=chatelet`);
  console.log(`� Stations list: http://localhost:${PORT}/stations`);
  console.log(`�📚 API Documentation: http://localhost:${PORT}/api-docs`);
  console.log(`📄 OpenAPI Spec: http://localhost:${PORT}/api-docs.json`);
  
  // Test de connexion à la base au démarrage
  console.log('🔍 Test de connexion à la base de données...');
  await testConnection();
});

// Gestion propre de l'arrêt du serveur
process.on('SIGTERM', async () => {
  console.log('📩 SIGTERM reçu, arrêt du serveur...');
  server.close(async () => {
    await closePool();
    process.exit(0);
  });
});

process.on('SIGINT', async () => {
  console.log('📩 SIGINT reçu, arrêt du serveur...');
  server.close(async () => {
    await closePool();
    process.exit(0);
  });
});
