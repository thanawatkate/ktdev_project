const path = require('path');
require('dotenv').config();

const migrations = {
  directory: path.join(__dirname, 'migrations'),
  tableName: 'knex_migrations',
  extension: 'js',
};

module.exports = {
  development: {
    client: 'mysql2',
    connection: {
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_NAME || 'saccm_registry',
    },
    pool: { min: 1, max: 8 },
    migrations,
  },
  production: {
    client: 'mysql2',
    connection: {
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_NAME,
    },
    pool: { min: 2, max: 10 },
    migrations,
  },
};
