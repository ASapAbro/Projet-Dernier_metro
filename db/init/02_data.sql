-- Données de test pour l'API Dernier Metro Paris
-- Insertion des données initiales

-- Insertion des lignes de métro (quelques lignes principales)
INSERT INTO metro_lines (code, name, color) VALUES
('M1', 'Ligne 1', '#FFCD00'),
('M4', 'Ligne 4', '#CF009E'),
('M6', 'Ligne 6', '#82DC73'),
('M7', 'Ligne 7', '#FA9ABA'),
('M9', 'Ligne 9', '#B6BD00'),
('M14', 'Ligne 14', '#62259D')
ON CONFLICT (code) DO NOTHING;

-- Insertion des stations principales de Paris
INSERT INTO stations (name, slug, latitude, longitude, zone, accessibility) VALUES
('Châtelet', 'chatelet', 48.8583, 2.3472, 1, true),
('Concorde', 'concorde', 48.8656, 2.3212, 1, true),
('République', 'republique', 48.8677, 2.3634, 1, false),
('Bastille', 'bastille', 48.8532, 2.3692, 1, true),
('Nation', 'nation', 48.8483, 2.3955, 1, true),
('Gare de Lyon', 'gare-de-lyon', 48.8449, 2.3739, 1, true),
('Montparnasse', 'montparnasse', 48.8422, 2.3219, 1, true),
('Champs-Élysées', 'champs-elysees', 48.8738, 2.2975, 1, false),
('Opéra', 'opera', 48.8710, 2.3317, 1, true),
('Saint-Lazare', 'saint-lazare', 48.8757, 2.3251, 1, true),
('Gare du Nord', 'gare-du-nord', 48.8809, 2.3553, 1, true),
('Gare de l''Est', 'gare-de-est', 48.8766, 2.3590, 1, true)
ON CONFLICT (slug) DO NOTHING;

-- Liaison stations-lignes pour la ligne M1 (exemple)
INSERT INTO line_stations (line_id, station_id, station_order, direction) 
SELECT l.id, s.id, 1, 'Vincennes'
FROM metro_lines l, stations s 
WHERE l.code = 'M1' AND s.slug = 'chatelet'
ON CONFLICT DO NOTHING;

INSERT INTO line_stations (line_id, station_id, station_order, direction) 
SELECT l.id, s.id, 2, 'Vincennes'
FROM metro_lines l, stations s 
WHERE l.code = 'M1' AND s.slug = 'concorde'
ON CONFLICT DO NOTHING;

INSERT INTO line_stations (line_id, station_id, station_order, direction) 
SELECT l.id, s.id, 3, 'Vincennes'
FROM metro_lines l, stations s 
WHERE l.code = 'M1' AND s.slug = 'champs-elysees'
ON CONFLICT DO NOTHING;

-- Horaires de service pour toutes les lignes
INSERT INTO service_schedules (line_id, day_type, service_start, service_end, last_train_window_start, headway_minutes)
SELECT id, 'weekday', '05:30:00', '01:15:00', '00:45:00', 3
FROM metro_lines
ON CONFLICT (line_id, day_type) DO NOTHING;

INSERT INTO service_schedules (line_id, day_type, service_start, service_end, last_train_window_start, headway_minutes)
SELECT id, 'saturday', '06:00:00', '02:15:00', '01:45:00', 4
FROM metro_lines
ON CONFLICT (line_id, day_type) DO NOTHING;

INSERT INTO service_schedules (line_id, day_type, service_start, service_end, last_train_window_start, headway_minutes)
SELECT id, 'sunday', '07:00:00', '01:15:00', '00:45:00', 5
FROM metro_lines
ON CONFLICT (line_id, day_type) DO NOTHING;
