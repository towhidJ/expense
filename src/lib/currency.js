// Multi-currency helper. Each account stores a manual exchange_rate
// (1 unit of the account's currency = X BDT; rate 1 for ৳ accounts).
// All app-wide totals are in BDT via these helpers.

export const toBDT = (account) =>
  Number(account?.current_balance || 0) * Number(account?.exchange_rate || 1);

export const sumBDT = (accounts = []) =>
  accounts.reduce((s, a) => s + toBDT(a), 0);

export const isForeign = (account) =>
  (account?.currency || '৳') !== '৳';

export const CURRENCIES = ['৳', '$', '€', '£', '﷼', 'د.إ', 'RM', '₹'];
