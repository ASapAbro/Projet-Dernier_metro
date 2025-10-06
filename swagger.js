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
          },
          database: {
            type: 'string',
            example: 'connected',
            description: 'Statut de la connexion à la base de données'
          },
          timestamp: {
            type: 'string',
            format: 'date-time',
            example: '2025-10-06T08:31:55.618Z',
            description: 'Timestamp du check de santé'
          }
        },
        required: ['status']
      },
      MetroResponse: {
        type: 'object',
        properties: {
          station: {
            type: 'string',
            example: 'Châtelet',
            description: 'Nom de la station de métro'
          },
          line: {
            type: 'string',
            example: 'M1',
            description: 'Code de la ligne de métro'
          },
          headwayMin: {
            type: 'integer',
            example: 3,
            minimum: 1,
            maximum: 15,
            description: 'Fréquence des métros en minutes'
          },
          nextArrival: {
            type: 'string',
            pattern: '^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$',
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
          },
          dayType: {
            type: 'string',
            enum: ['weekday', 'saturday', 'sunday'],
            example: 'weekday',
            description: 'Type de jour pour les horaires'
          },
          zone: {
            type: 'integer',
            example: 1,
            minimum: 1,
            maximum: 5,
            description: 'Zone tarifaire de la station'
          },
          accessibility: {
            type: 'boolean',
            example: true,
            description: 'Station accessible aux personnes à mobilité réduite'
          }
        },
        required: ['station', 'line', 'headwayMin', 'nextArrival', 'isLast', 'tz']
      },
      MetroClosedResponse: {
        type: 'object',
        properties: {
          station: {
            type: 'string',
            example: 'Châtelet',
            description: 'Nom de la station de métro'
          },
          line: {
            type: 'string',
            example: 'M1',
            description: 'Code de la ligne de métro'
          },
          service: {
            type: 'string',
            example: 'closed',
            enum: ['closed'],
            description: 'Statut du service (fermé)'
          },
          tz: {
            type: 'string',
            example: 'Europe/Paris',
            description: 'Fuseau horaire'
          }
        },
        required: ['station', 'line', 'service', 'tz']
      },
      StationListResponse: {
        type: 'object',
        properties: {
          stations: {
            type: 'array',
            items: {
              $ref: '#/components/schemas/Station'
            },
            description: 'Liste des stations'
          },
          count: {
            type: 'integer',
            example: 12,
            description: 'Nombre total de stations'
          }
        },
        required: ['stations', 'count']
      },
      Station: {
        type: 'object',
        properties: {
          name: {
            type: 'string',
            example: 'Châtelet',
            description: 'Nom de la station'
          },
          slug: {
            type: 'string',
            example: 'chatelet',
            description: 'Identifiant URL-friendly de la station'
          },
          zone: {
            type: 'integer',
            example: 1,
            minimum: 1,
            maximum: 5,
            description: 'Zone tarifaire'
          },
          accessibility: {
            type: 'boolean',
            example: true,
            description: 'Accessibilité PMR'
          }
        },
        required: ['name', 'slug', 'zone', 'accessibility']
      },
      ErrorResponse: {
        type: 'object',
        properties: {
          error: {
            type: 'string',
            example: 'missing station',
            description: 'Message d\'erreur'
          }
        },
        required: ['error']
      },
      NotFoundResponse: {
        type: 'object',
        properties: {
          error: {
            type: 'string',
            example: 'unknown station',
            description: 'Message d\'erreur'
          },
          suggestions: {
            type: 'array',
            items: {
              type: 'string'
            },
            example: ['Châtelet', 'Champs-Élysées'],
            description: 'Suggestions de stations similaires'
          }
        },
        required: ['error', 'suggestions']
      }
    },
    parameters: {
      StationParam: {
        name: 'station',
        in: 'query',
        required: true,
        description: 'Nom ou slug de la station de métro (insensible à la casse)',
        schema: {
          type: 'string',
          minLength: 2,
          maxLength: 100
        },
        examples: {
          slug: {
            summary: 'Par slug',
            value: 'chatelet'
          },
          name: {
            summary: 'Par nom complet',
            value: 'Châtelet'
          },
          partial: {
            summary: 'Nom partiel',
            value: 'chat'
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
