const { execFileSync } = require('child_process');
const path = require('path');

const repoRoot = path.resolve(__dirname, '../..');

const allowedEnvFiles = new Set([
  '.env.example',
  '.env.production.example',
]);

const forbiddenRules = [
  {
    name: 'runtime environment file',
    match: (file) => {
      const base = path.posix.basename(file);
      return base === '.env' || (base.startsWith('.env.') && !allowedEnvFiles.has(base));
    },
  },
  {
    name: 'Flutter local tooling artifact',
    pattern: /^forntend\/\.dart_tool\//,
  },
  {
    name: 'local SQLite database artifact',
    pattern: /^forntend\/.*\.(db|db-shm|db-wal|sqlite|sqlite3)$/i,
  },
  {
    name: 'Android signing secret',
    match: (file) => (
      file === 'forntend/android/key.properties'
      || /^forntend\/android\/.*\.(jks|keystore)$/i.test(file)
    ),
  },
  {
    name: 'Node dependency artifact',
    pattern: /(^|\/)node_modules\//,
  },
  {
    name: 'build output artifact',
    pattern: /^(backend|registry-backend)\/dist\/|^release\/out\//,
  },
  {
    name: 'OS metadata artifact',
    pattern: /(^|\/)(Thumbs\.db|\.DS_Store)$/i,
  },
];

function trackedFiles() {
  const output = execFileSync('git', ['ls-files', '-z'], {
    cwd: repoRoot,
    encoding: 'utf8',
  });
  return output.split('\0').filter(Boolean).map((file) => file.replace(/\\/g, '/'));
}

const violations = [];
for (const file of trackedFiles()) {
  for (const rule of forbiddenRules) {
    const matched = rule.match ? rule.match(file) : rule.pattern.test(file);
    if (matched) {
      violations.push(`${file}: ${rule.name}`);
    }
  }
}

if (violations.length > 0) {
  console.error('repo_hygiene_static_check: FAIL');
  for (const violation of violations) {
    console.error(`- ${violation}`);
  }
  process.exit(1);
}

console.log('repo_hygiene_static_check: PASS');
