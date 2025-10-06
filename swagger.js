const swaggerJSDoc = require('swagger-jsdoc');

const swaggerDefinition = {
  openapi: '3.0.0',
  info: {
    title: 'Dernier Metro Paris API',
    version: '1.0.0',
    description: 'API pour savoir si on peut attraper le dernier métro à Paris',
    contact: {
      name: 'API Support',
    },
  },
  servers: [
    {
      url: 'http://localhost:3002',
      description: 'Serveur de développement',
    },
  ],
  components: {
    schemas: {
      HealthResponse: {
        type: 'object',
        properties: {
          status: {
            type: 'string',
            example: 'ok',
            description: 'Statut de santé de l\'API'
          }
        }
      },
      MetroResponse: {
        type: 'object',
        properties: {
          station: {
            type: 'string',
            example: 'Chatelet',
            description: 'Nom de la station de métro'
          },
          line: {
            type: 'string',
            example: 'M1',
            description: 'Ligne de métro'
          },
          headwayMin: {
            type: 'integer',
            example: 3,
            description: 'Fréquence des métros en minutes'
          },
          nextArrival: {
            type: 'string',
            example: '12:34',
            description: 'Heure du prochain métro au format HH:MM'
          },
          isLast: {
            type: 'boolean',
            example: false,
            description: 'Indique si c\'est le dernier métro de la nuit'
          },
          tz: {
            type: 'string',
            example: 'Europe/Paris',
            description: 'Fuseau horaire'
          }
        }
      },
      MetroClosedResponse: {
        type: 'object',
        properties: {
          station: {
            type: 'string',
            example: 'Chatelet',
            description: 'Nom de la station de métro'
          },
          line: {
            type: 'string',
            example: 'M1',
            description: 'Ligne de métro'
          },
          service: {
            type: 'string',
            example: 'closed',
            description: 'Statut du service'
          },
          tz: {
            type: 'string',
            example: 'Europe/Paris',
            description: 'Fuseau horaire'
          }
        }
      },
      ErrorResponse: {
        type: 'object',
        properties: {
          error: {
            type: 'string',
            example: 'missing station',
            description: 'Message d\'erreur'
          }
        }
      }
    }
  }
};

const options = {
  swaggerDefinition,
  // Chemins vers les fichiers contenant les annotations OpenAPI
  apis: ['./server.js'],
};

const swaggerSpec = swaggerJSDoc(options);

module.exports = swaggerSpec;
