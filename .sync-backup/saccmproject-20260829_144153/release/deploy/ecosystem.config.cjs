/**
 * PM2 process file for SACCM production (Linux VPS).
 * Usage (from repo root on server):
 *   pm2 start release/deploy/ecosystem.config.cjs
 *   pm2 save && pm2 startup
 */
module.exports = {
  apps: [
    {
      name: 'saccm-api',
      cwd: './backend',
      script: 'index.js',
      instances: 1,
      exec_mode: 'fork',
      env: {
        NODE_ENV: 'production',
        PORT: '3801',
      },
      max_memory_restart: '512M',
      error_file: '/var/log/saccm/saccm-api-error.log',
      out_file: '/var/log/saccm/saccm-api-out.log',
      merge_logs: true,
      time: true,
    },
    {
      name: 'saccm-registry',
      cwd: './registry-backend',
      script: 'index.js',
      instances: 1,
      exec_mode: 'fork',
      env: {
        NODE_ENV: 'production',
        PORT: '3802',
      },
      max_memory_restart: '256M',
      error_file: '/var/log/saccm/saccm-registry-error.log',
      out_file: '/var/log/saccm/saccm-registry-out.log',
      merge_logs: true,
      time: true,
    },
  ],
};
