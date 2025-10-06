const { query } = require('./database');

// Modèle pour les stations de métro
class StationModel {
  
  // Rechercher une station par son slug ou nom (insensible à la casse)
  static async findBySlug(slug) {
    const result = await query(`
      SELECT * FROM stations 
      WHERE LOWER(slug) = LOWER($1) OR LOWER(name) = LOWER($1)
    `, [slug]);
    return result.rows[0] || null;
  }

  // Rechercher des stations par nom (suggestions)
  static async findSuggestions(searchTerm, limit = 5) {
    const result = await query(`
      SELECT name, slug FROM stations 
      WHERE name ILIKE $1 OR slug ILIKE $1
      ORDER BY 
        CASE 
          WHEN name ILIKE $2 THEN 1 
          WHEN slug ILIKE $2 THEN 2
          ELSE 3 
        END,
        name
      LIMIT $3
    `, [`%${searchTerm}%`, `${searchTerm}%`, limit]);
    return result.rows;
  }

  // Obtenir toutes les stations
  static async findAll() {
    const result = await query(
      'SELECT * FROM stations ORDER BY name'
    );
    return result.rows;
  }

  // Vérifier si une station existe et obtenir ses lignes (insensible à la casse)
  static async getStationWithLines(searchTerm) {
    const result = await query(`
      SELECT 
        s.*,
        COALESCE(
          json_agg(
            json_build_object(
              'code', ml.code,
              'name', ml.name,
              'color', ml.color
            )
          ) FILTER (WHERE ml.id IS NOT NULL), 
          '[]'::json
        ) as lines
      FROM stations s
      LEFT JOIN line_stations ls ON s.id = ls.station_id
      LEFT JOIN metro_lines ml ON ls.line_id = ml.id
      WHERE LOWER(s.slug) = LOWER($1) OR LOWER(s.name) = LOWER($1)
      GROUP BY s.id
    `, [searchTerm]);
    
    return result.rows[0] || null;
  }
}

// Modèle pour les horaires de service
class ScheduleModel {
  
  // Obtenir les horaires pour une ligne et un type de jour
  static async getScheduleForLine(lineCode, dayType = 'weekday') {
    const result = await query(`
      SELECT ss.* 
      FROM service_schedules ss
      JOIN metro_lines ml ON ss.line_id = ml.id
      WHERE ml.code = $1 AND ss.day_type = $2
    `, [lineCode, dayType]);
    
    return result.rows[0] || null;
  }

  // Déterminer le type de jour actuel
  static getDayType(date = new Date()) {
    const day = date.getDay(); // 0 = dimanche, 6 = samedi
    if (day === 0) return 'sunday';
    if (day === 6) return 'saturday';
    return 'weekday';
  }

  // Calculer les prochains passages avec les données réelles
  static async calculateNextArrival(lineCode, now = new Date()) {
    const dayType = this.getDayType(now);
    const schedule = await this.getScheduleForLine(lineCode, dayType);
    
    if (!schedule) {
      // Fallback sur les horaires par défaut si pas de données
      return this.calculateDefaultArrival(now);
    }

    const tz = 'Europe/Paris';
    const toHM = d => String(d.getHours()).padStart(2,'0') + ':' + String(d.getMinutes()).padStart(2,'0');
    
    // Conversion des heures de service
    const serviceEnd = new Date(now);
    const [endHour, endMin] = schedule.service_end.split(':');
    serviceEnd.setHours(parseInt(endHour), parseInt(endMin), 0, 0);
    
    const lastWindow = new Date(now);
    const [lastHour, lastMin] = schedule.last_train_window_start.split(':');
    lastWindow.setHours(parseInt(lastHour), parseInt(lastMin), 0, 0);
    
    // Service fermé après l'heure de fin
    if (now > serviceEnd) {
      return { service: 'closed', tz };
    }
    
    // Calcul du prochain passage
    const headwayMs = schedule.headway_minutes * 60 * 1000;
    const next = new Date(now.getTime() + headwayMs);
    
    return {
      nextArrival: toHM(next),
      isLast: now >= lastWindow,
      headwayMin: schedule.headway_minutes,
      tz,
      dayType,
      serviceEnd: toHM(serviceEnd)
    };
  }

  // Méthode de fallback avec les horaires par défaut
  static calculateDefaultArrival(now = new Date(), headwayMin = 3) {
    const tz = 'Europe/Paris';
    const toHM = d => String(d.getHours()).padStart(2,'0') + ':' + String(d.getMinutes()).padStart(2,'0');
    
    const end = new Date(now); 
    end.setHours(1, 15, 0, 0);
    const lastWindow = new Date(now); 
    lastWindow.setHours(0, 45, 0, 0);
    
    if (now > end) {
      return { service: 'closed', tz };
    }
    
    const next = new Date(now.getTime() + headwayMin * 60 * 1000);
    
    return { 
      nextArrival: toHM(next), 
      isLast: now >= lastWindow, 
      headwayMin, 
      tz 
    };
  }
}

module.exports = {
  StationModel,
  ScheduleModel
};
