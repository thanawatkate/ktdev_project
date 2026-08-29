const fs = require('fs');
const path = require('path');

const srcRoot = path.resolve(__dirname, '../src');

const checks = [
  {
    name: 'raw INSERT template',
    pattern: /db\.raw\(\s*`INSERT\s+INTO/ims,
  },
  {
    name: 'SQL INSERT concatenates request fields',
    pattern: /INSERT\s+INTO[\s\S]{0,600}\+\s*(bodyData|req\.body|Data|mainID)/im,
  },
  {
    name: 'legacy raw pagination SELECT',
    pattern: /SELECT\s+\*\s+FROM[\s\S]{0,200}ORDER\s+BY\s+id\s+ASC\s+LIMIT/im,
  },
  {
    name: 'legacy usergroup raw pagination SELECT',
    pattern: /SELECT\s+id,\s*nameen,\s*nameth\s+FROM\s+usergroup[\s\S]{0,200}LIMIT/im,
  },
];

function walk(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...walk(fullPath));
    } else if (entry.isFile() && entry.name.endsWith('.js')) {
      files.push(fullPath);
    }
  }
  return files;
}

const violations = [];
for (const file of walk(srcRoot)) {
  const content = fs.readFileSync(file, 'utf8');
  for (const check of checks) {
    if (check.pattern.test(content)) {
      violations.push(`${path.relative(process.cwd(), file)}: ${check.name}`);
    }
  }
}

if (violations.length > 0) {
  console.error('sql_safety_static_check: FAIL');
  for (const violation of violations) {
    console.error(`- ${violation}`);
  }
  process.exit(1);
}

console.log('sql_safety_static_check: PASS');
