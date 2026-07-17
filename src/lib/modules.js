// Single source of truth for premium-gateable modules. The `key` strings are
// the shared contract with the DB (`module_access.module_key`) and the Flutter
// app — never rename a key without migrating the table.
//
// Client rule everywhere: a key missing from module_access is FREE. The core
// trio below is never seeded, so it can never be gated.

export const ALWAYS_FREE = ['dashboard', 'transactions', 'accounts'];

export const MODULES = [
  { key: 'scan', label: 'Scan Receipt', path: '/scan' },
  { key: 'bazar', label: 'Bazar', path: '/bazar' },
  { key: 'transfers', label: 'Transfers', path: '/transfers' },
  { key: 'recurring', label: 'Recurring', path: '/recurring' },
  { key: 'categories', label: 'Categories', path: '/categories' },
  { key: 'import', label: 'Import', path: '/import' },
  { key: 'reports', label: 'Reports', path: '/reports' },
  { key: 'insights', label: 'AI Insights', path: '/insights' },
  { key: 'forecast', label: 'Forecast', path: '/forecast' },
  { key: 'budgets', label: 'Budgets', path: '/budgets' },
  { key: 'goals', label: 'Goals', path: '/goals' },
  { key: 'savings', label: 'Savings', path: '/savings' },
  { key: 'tax', label: 'Tax', path: '/tax' },
  { key: 'zakat', label: 'Zakat', path: '/zakat' },
  { key: 'assets', label: 'Assets', path: '/assets' },
  { key: 'investments', label: 'Investments', path: '/investments' },
  { key: 'liabilities', label: 'Liabilities', path: '/liabilities' },
  { key: 'lending', label: 'Dena-Paona', path: '/lending' },
  { key: 'insurance', label: 'Insurance', path: '/insurance' },
  { key: 'warranty', label: 'Warranty', path: '/warranty' },
  { key: 'utility', label: 'Utility Bills', path: '/utility' },
  { key: 'rent', label: 'Rent', path: '/rent' },
  { key: 'subscriptions', label: 'Subscriptions', path: '/subscriptions' },
  { key: 'splitter', label: 'Bill Splitter', path: '/splitter' },
  { key: 'family', label: 'Family', path: '/family' },
  { key: 'meals', label: 'Meal Manager', path: '/meals' },
  { key: 'activity', label: 'Activity Log', path: '/activity' },
  { key: 'backup', label: 'Backup', path: '/backup' }
];

export const moduleKeyByPath = Object.fromEntries(MODULES.map(m => [m.path, m.key]));
