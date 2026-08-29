const path = require('path');

// Update with your config settings.
require('dotenv').config();

const migrations = {
  directory: path.join(__dirname, 'migrations'),
  tableName: 'knex_migrations',
  extension: 'js',
};

/**
 * @type { Object.<string, import("knex").Knex.Config> }
 */
module.exports = {

  development: {
    client: 'mysql2',
    connection: {
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME
    }, pool: {
      min: 2,
      max: 10
    },
    migrations,
    seeds: {
      directory: './data/seeds'
    }
  },
  production: {
    client: 'mysql2',
    connection: {
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME
    },
    pool: {
      min: 2,
      max: 10
    },
    migrations,
  }
};
