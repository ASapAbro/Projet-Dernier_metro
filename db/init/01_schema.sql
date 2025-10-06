-- Création des tables pour l'API Dernier Metro Paris
-- Fichier d'initialisation de la base de données

-- Table des lignes de métro
CREATE TABLE IF NOT EXISTS metro_lines (
    id SERIAL PRIMARY KEY,
    code VARCHAR(10) NOT NULL UNIQUE, -- M1, M2, etc.
    name VARCHAR(100) NOT NULL, -- Ligne 1, Ligne 2, etc.
    color VARCHAR(7), -- Code couleur hex (#FFCD00 pour M1)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table des stations
CREATE TABLE IF NOT EXISTS stations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE, -- chatelet, concorde, etc.
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    zone INTEGER DEFAULT 1, -- Zone tarifaire
    accessibility BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table de liaison lignes-stations (many-to-many)
CREATE TABLE IF NOT EXISTS line_stations (
    id SERIAL PRIMARY KEY,
    line_id INTEGER REFERENCES metro_lines(id) ON DELETE CASCADE,
    station_id INTEGER REFERENCES stations(id) ON DELETE CASCADE,
    station_order INTEGER NOT NULL, -- Ordre de la station sur la ligne
    direction VARCHAR(50), -- terminus ou direction
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(line_id, station_id, direction)
);

-- Table des horaires de service
CREATE TABLE IF NOT EXISTS service_schedules (
    id SERIAL PRIMARY KEY,
    line_id INTEGER REFERENCES metro_lines(id) ON DELETE CASCADE,
    day_type VARCHAR(20) NOT NULL, -- weekday, saturday, sunday, holiday
    service_start TIME NOT NULL DEFAULT '05:30:00',
    service_end TIME NOT NULL DEFAULT '01:15:00',
    last_train_window_start TIME NOT NULL DEFAULT '00:45:00',
    headway_minutes INTEGER NOT NULL DEFAULT 3, -- Fréquence en minutes
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(line_id, day_type)
);

-- Table de logs des requêtes (pour le monitoring)
CREATE TABLE IF NOT EXISTS api_logs (
    id SERIAL PRIMARY KEY,
    method VARCHAR(10) NOT NULL,
    path VARCHAR(255) NOT NULL,
    status_code INTEGER NOT NULL,
    duration_ms INTEGER NOT NULL,
    user_agent TEXT,
    ip_address INET,
    query_params JSONB,
    response_data JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_stations_slug ON stations(slug);
CREATE INDEX IF NOT EXISTS idx_line_stations_line_id ON line_stations(line_id);
CREATE INDEX IF NOT EXISTS idx_line_stations_station_id ON line_stations(station_id);
CREATE INDEX IF NOT EXISTS idx_service_schedules_line_day ON service_schedules(line_id, day_type);
CREATE INDEX IF NOT EXISTS idx_api_logs_created_at ON api_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_api_logs_path ON api_logs(path);
