const { Pool } = require('pg');

// Configuration de la base de données depuis les variables d'environnement
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'dernier_metro',
  user: process.env.DB_USER || 'metro_user',
  password: process.env.DB_PASSWORD || 'metro_password',
  // Configuration du pool de connexions
  max: 20, // Nombre maximum de connexions
  idleTimeoutMillis: 30000, // Timeout pour les connexions inactives
  connectionTimeoutMillis: 2000, // Timeout pour l'établissement de connexion
};

// Création du pool de connexions
const pool = new Pool(dbConfig);

// Gestion des événements du pool
pool.on('connect', (client) => {
  console.log('🔗 Nouvelle connexion PostgreSQL établie');
});

pool.on('error', (err, client) => {
  console.error('❌ Erreur PostgreSQL:', err);
});

// Fonction utilitaire pour exécuter des requêtes
const query = async (text, params) => {
  const start = Date.now();
  try {
    const res = await pool.query(text, params);
    const duration = Date.now() - start;
    console.log('🔍 Query exécutée:', { text: text.substring(0, 50) + '...', duration: `${duration}ms`, rows: res.rowCount });
    return res;
  } catch (err) {
    const duration = Date.now() - start;
    console.error('❌ Erreur de requête:', { text: text.substring(0, 50) + '...', duration: `${duration}ms`, error: err.message });
    throw err;
  }
};

// Fonction pour tester la connexion
const testConnection = async () => {
  try {
    const result = await query('SELECT NOW() as current_time, version() as version');
    console.log('✅ Connexion PostgreSQL réussie:', {
      time: result.rows[0].current_time,
      version: result.rows[0].version.split(' ')[0] + ' ' + result.rows[0].version.split(' ')[1]
    });
    return true;
  } catch (err) {
    console.error('❌ Échec de la connexion PostgreSQL:', err.message);
    return false;
  }
};

// Fonction pour fermer proprement le pool
const closePool = async () => {
  try {
    await pool.end();
    console.log('🔒 Pool PostgreSQL fermé');
  } catch (err) {
    console.error('❌ Erreur lors de la fermeture du pool:', err.message);
  }
};

// Fonction pour logger les requêtes API dans la base
const logApiRequest = async (method, path, statusCode, duration, userAgent = null, ipAddress = null, queryParams = null, responseData = null) => {
  try {
    await query(`
      INSERT INTO api_logs (method, path, status_code, duration_ms, user_agent, ip_address, query_params, response_data)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    `, [method, path, statusCode, duration, userAgent, ipAddress, queryParams, responseData]);
  } catch (err) {
    // Ne pas faire échouer la requête principale si le logging échoue
    console.error('⚠️ Erreur lors du logging API:', err.message);
  }
};

module.exports = {
  pool,
  query,
  testConnection,
  closePool,
  logApiRequest
};
