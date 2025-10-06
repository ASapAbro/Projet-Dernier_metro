// Tests utilitaires et helpers
const { query } = require('../src/database');

describe('Utility Functions', () => {
  describe('Time formatting', () => {
    it('devrait formater les heures correctement', () => {
      const toHM = d => String(d.getHours()).padStart(2,'0') + ':' + String(d.getMinutes()).padStart(2,'0');
      
      const date1 = new Date('2025-10-06T08:05:00Z');
      const date2 = new Date('2025-10-06T14:30:00Z');
      const date3 = new Date('2025-10-06T00:00:00Z');

      expect(toHM(date1)).toBe('08:05');
      expect(toHM(date2)).toBe('14:30');
      expect(toHM(date3)).toBe('00:00');
    });
  });

  describe('Time calculations', () => {
    it('devrait calculer correctement les ajouts de minutes', () => {
      const now = new Date('2025-10-06T12:30:00Z');
      const headwayMs = 3 * 60 * 1000; // 3 minutes en ms
      const next = new Date(now.getTime() + headwayMs);

      expect(next.getMinutes()).toBe(33);
    });

    it('devrait gérer le passage d\'heure', () => {
      const now = new Date('2025-10-06T12:58:00Z');
      const headwayMs = 5 * 60 * 1000; // 5 minutes
      const next = new Date(now.getTime() + headwayMs);

      expect(next.getHours()).toBe(13);
      expect(next.getMinutes()).toBe(3);
    });
  });

  describe('Environment variables', () => {
    it('devrait utiliser les variables d\'environnement de test', () => {
      expect(process.env.NODE_ENV).toBe('test');
      expect(process.env.DB_NAME).toBe('dernier_metro_test');
    });
  });

  describe('Error handling', () => {
    it('devrait gérer les erreurs de base de données', async () => {
      query.mockRejectedValue(new Error('Connection failed'));

      try {
        await query('SELECT 1');
        fail('Devrait lever une erreur');
      } catch (error) {
        expect(error.message).toBe('Connection failed');
      }
    });
  });

  describe('JSON responses validation', () => {
    const validateMetroResponse = (response) => {
      const required = ['station', 'line', 'headwayMin', 'nextArrival', 'isLast', 'tz'];
      return required.every(field => response.hasOwnProperty(field));
    };

    const validateStationResponse = (response) => {
      const required = ['name', 'slug', 'zone', 'accessibility'];
      return required.every(field => response.hasOwnProperty(field));
    };

    it('devrait valider les réponses metro', () => {
      const validResponse = {
        station: 'Châtelet',
        line: 'M1',
        headwayMin: 3,
        nextArrival: '12:34',
        isLast: false,
        tz: 'Europe/Paris'
      };

      expect(validateMetroResponse(validResponse)).toBe(true);
    });

    it('devrait valider les réponses station', () => {
      const validResponse = {
        name: 'Châtelet',
        slug: 'chatelet',
        zone: 1,
        accessibility: true
      };

      expect(validateStationResponse(validResponse)).toBe(true);
    });

    it('devrait détecter les réponses invalides', () => {
      const invalidResponse = {
        station: 'Châtelet'
        // Champs manquants
      };

      expect(validateMetroResponse(invalidResponse)).toBe(false);
    });
  });
});
