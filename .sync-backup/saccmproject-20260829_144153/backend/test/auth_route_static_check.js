const fs = require('fs');
const path = require('path');

const routesRoot = path.resolve(__dirname, '../src/routes');

const publicRouteFiles = new Set([
  'login.route.js',
  'programmingLanguages.route.js',
]);

const fullAuthRouteFiles = new Set([
  'approval.route.js',
  'bank.route.js',
  'bankaccount.route.js',
  'budget_source.route.js',
  'chequeaccount.route.js',
  'expense.route.js',
  'expensereq.route.js',
  'expensetype.route.js',
  'finance_compliance.route.js',
  'fiscal_year_opening.route.js',
  'forms.route.js',
  'income.route.js',
  'incometype.route.js',
  'loan.route.js',
  'member.route.js',
  'moneygroup.route.js',
  'moneytype.route.js',
  'party.route.js',
  'paycheque.route.js',
  'register.route.js',
  'repayloan.route.js',
  'users.route.js',
]);

function routeCallSnippets(content) {
  const snippets = [];
  const pattern = /router\.(post|put|patch|delete)\s*\(/g;
  let match;
  while ((match = pattern.exec(content)) !== null) {
    const start = match.index;
    const end = content.indexOf(');', start);
    snippets.push({
      method: match[1],
      text: content.slice(start, end === -1 ? start + 200 : end + 2),
    });
  }
  return snippets;
}

const violations = [];
const routeFiles = fs
  .readdirSync(routesRoot)
  .filter((file) => file.endsWith('.js'))
  .sort();

for (const file of routeFiles) {
  const fullPath = path.join(routesRoot, file);
  const content = fs.readFileSync(fullPath, 'utf8');
  const hasRequireAuthBoundary = /router\.use\(\s*requireAuth\s*\)/.test(content);
  const hasReportBoundary = /router\.use\(\s*requireReportAccess\s*\)/.test(content);
  const hasSetupBoundary = /router\.use\(\s*requireSetupAccess\s*\)/.test(content);
  const hasInternalSecret = /checkInternalSecret\s*\(/.test(content);

  if (fullAuthRouteFiles.has(file) && !hasRequireAuthBoundary) {
    violations.push(`${file}: expected router.use(requireAuth) boundary`);
  }

  if (file === 'reports.route.js' && !hasReportBoundary) {
    violations.push(`${file}: expected router.use(requireReportAccess) boundary`);
  }

  if (file === 'setup.route.js' && !hasSetupBoundary) {
    violations.push(`${file}: expected router.use(requireSetupAccess) boundary`);
  }

  if (file === 'internal.route.js' && !hasInternalSecret) {
    violations.push(`${file}: expected internal secret guard`);
  }

  if (publicRouteFiles.has(file) || hasRequireAuthBoundary || hasReportBoundary || hasSetupBoundary || hasInternalSecret) {
    continue;
  }

  for (const snippet of routeCallSnippets(content)) {
    if (!/\brequireAuth\b/.test(snippet.text)) {
      violations.push(`${file}: ${snippet.method.toUpperCase()} route missing requireAuth`);
    }
  }
}

if (violations.length > 0) {
  console.error('auth_route_static_check: FAIL');
  for (const violation of violations) {
    console.error(`- ${violation}`);
  }
  process.exit(1);
}

console.log('auth_route_static_check: PASS');
