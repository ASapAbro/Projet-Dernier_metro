const { StationModel, ScheduleModel } = require('../src/models');
const { query } = require('../src/database');

// Mock des données de test
const mockStations = [
  { id: 1, name: 'Châtelet', slug: 'chatelet', zone: 1, accessibility: true },
  { id: 2, name: 'Concorde', slug: 'concorde', zone: 1, accessibility: true },
  { id: 3, name: 'Champs-Élysées', slug: 'champs-elysees', zone: 1, accessibility: false }
];

const mockStationWithLines = {
  id: 1,
  name: 'Châtelet',
  slug: 'chatelet',
  zone: 1,
  accessibility: true,
  lines: [
    { code: 'M1', name: 'Ligne 1', color: '#FFCD00' },
    { code: 'M4', name: 'Ligne 4', color: '#CF009E' }
  ]
};

const mockSchedule = {
  line_id: 1,
  day_type: 'weekday',
  service_start: '05:30:00',
  service_end: '01:15:00',
  last_train_window_start: '00:45:00',
  headway_minutes: 3
};

describe('StationModel', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findBySlug', () => {
    it('devrait trouver une station par son slug', async () => {
      query.mockResolvedValue({ rows: [mockStations[0]] });

      const result = await StationModel.findBySlug('chatelet');

      expect(query).toHaveBeenCalledWith(
        expect.stringContaining('SELECT * FROM stations'),
        ['chatelet']
      );
      expect(result).toEqual(mockStations[0]);
    });

    it('devrait être insensible à la casse', async () => {
      query.mockResolvedValue({ rows: [mockStations[0]] });

      const result = await StationModel.findBySlug('CHATELET');

      expect(query).toHaveBeenCalledWith(
        expect.stringContaining('LOWER(slug) = LOWER($1) OR LOWER(name) = LOWER($1)'),
        ['CHATELET']
      );
      expect(result).toEqual(mockStations[0]);
    });

    it('devrait retourner null si aucune station trouvée', async () => {
      query.mockResolvedValue({ rows: [] });

      const result = await StationModel.findBySlug('inexistante');

      expect(result).toBeNull();
    });
  });

  describe('findSuggestions', () => {
    it('devrait retourner des suggestions basées sur la recherche', async () => {
      const suggestions = [
        { name: 'Châtelet', slug: 'chatelet' },
        { name: 'Champs-Élysées', slug: 'champs-elysees' }
      ];
      query.mockResolvedValue({ rows: suggestions });

      const result = await StationModel.findSuggestions('cha');

      expect(query).toHaveBeenCalledWith(
        expect.stringContaining('WHERE name ILIKE $1 OR slug ILIKE $1'),
        ['%cha%', 'cha%', 5]
      );
      expect(result).toEqual(suggestions);
    });

    it('devrait limiter le nombre de suggestions', async () => {
      query.mockResolvedValue({ rows: [] });

      await StationModel.findSuggestions('test', 3);

      expect(query).toHaveBeenCalledWith(
        expect.any(String),
        ['%test%', 'test%', 3]
      );
    });
  });

  describe('findAll', () => {
    it('devrait retourner toutes les stations triées par nom', async () => {
      query.mockResolvedValue({ rows: mockStations });

      const result = await StationModel.findAll();

      expect(query).toHaveBeenCalledWith(
        'SELECT * FROM stations ORDER BY name'
      );
      expect(result).toEqual(mockStations);
    });
  });

  describe('getStationWithLines', () => {
    it('devrait retourner une station avec ses lignes', async () => {
      query.mockResolvedValue({ rows: [mockStationWithLines] });

      const result = await StationModel.getStationWithLines('chatelet');

      expect(query).toHaveBeenCalledWith(
        expect.stringContaining('json_agg'),
        ['chatelet']
      );
      expect(result).toEqual(mockStationWithLines);
      expect(result.lines).toHaveLength(2);
    });
  });
});

describe('ScheduleModel', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getDayType', () => {
    it('devrait retourner "weekday" pour un jour de semaine', () => {
      const lundi = new Date('2025-10-06T10:00:00Z'); // Lundi
      expect(ScheduleModel.getDayType(lundi)).toBe('weekday');
    });

    it('devrait retourner "saturday" pour samedi', () => {
      const samedi = new Date('2025-10-11T10:00:00Z'); // Samedi
      expect(ScheduleModel.getDayType(samedi)).toBe('saturday');
    });

    it('devrait retourner "sunday" pour dimanche', () => {
      const dimanche = new Date('2025-10-12T10:00:00Z'); // Dimanche
      expect(ScheduleModel.getDayType(dimanche)).toBe('sunday');
    });
  });

  describe('getScheduleForLine', () => {
    it('devrait récupérer les horaires pour une ligne', async () => {
      query.mockResolvedValue({ rows: [mockSchedule] });

      const result = await ScheduleModel.getScheduleForLine('M1', 'weekday');

      expect(query).toHaveBeenCalledWith(
        expect.stringContaining('FROM service_schedules ss'),
        ['M1', 'weekday']
      );
      expect(result).toEqual(mockSchedule);
    });

    it('devrait retourner null si aucun horaire trouvé', async () => {
      query.mockResolvedValue({ rows: [] });

      const result = await ScheduleModel.getScheduleForLine('MX', 'weekday');

      expect(result).toBeNull();
    });
  });

  describe('calculateDefaultArrival', () => {
    it('devrait calculer le prochain passage avec les horaires par défaut', () => {
      // 14:30 local - clairement pendant les heures de service
      const now = new Date();
      now.setHours(14, 30, 0, 0);
      
      const result = ScheduleModel.calculateDefaultArrival(now, 3);

      expect(result).toHaveProperty('nextArrival');
      expect(result).toHaveProperty('isLast', false);
      expect(result).toHaveProperty('headwayMin', 3);
      expect(result).toHaveProperty('tz', 'Europe/Paris');
      expect(result).not.toHaveProperty('service');
    });

    it('devrait marquer le service fermé après 01:15', () => {
      // 02:00 local = après 01:15
      const lateNight = new Date();
      lateNight.setHours(2, 0, 0, 0);
      
      const result = ScheduleModel.calculateDefaultArrival(lateNight);

      expect(result).toHaveProperty('service', 'closed');
      expect(result).toHaveProperty('tz', 'Europe/Paris');
      expect(result).not.toHaveProperty('nextArrival');
    });

    it('devrait marquer isLast=true après 00:45', () => {
      // 00:50 local = après 00:45 mais avant 01:15
      const lastMetro = new Date();
      lastMetro.setHours(0, 50, 0, 0);
      
      const result = ScheduleModel.calculateDefaultArrival(lastMetro);

      expect(result).toHaveProperty('isLast', true);
      expect(result).toHaveProperty('nextArrival'); // Service encore ouvert
      expect(result).not.toHaveProperty('service');
    });
  });
});
