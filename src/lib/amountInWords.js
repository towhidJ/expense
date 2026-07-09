// Convert a numeric amount to words in Bangladeshi (lakh/crore) numbering,
// e.g. 250000 -> "Two Lakh Fifty Thousand"
const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
  'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

function twoDigits(n) {
  if (n < 20) return ones[n];
  return (tens[Math.floor(n / 10)] + (n % 10 ? ' ' + ones[n % 10] : '')).trim();
}

function threeDigits(n) {
  const h = Math.floor(n / 100);
  const rest = n % 100;
  let out = '';
  if (h) out = ones[h] + ' Hundred';
  if (rest) out += (out ? ' ' : '') + twoDigits(rest);
  return out;
}

export function numberToWords(num) {
  num = Math.floor(Math.abs(num));
  if (num === 0) return 'Zero';
  const crore = Math.floor(num / 10000000);
  const lakh = Math.floor((num % 10000000) / 100000);
  const thousand = Math.floor((num % 100000) / 1000);
  const rest = num % 1000;
  const parts = [];
  if (crore) parts.push((crore > 99 ? numberToWords(crore) : twoDigits(crore)) + ' Crore');
  if (lakh) parts.push(twoDigits(lakh) + ' Lakh');
  if (thousand) parts.push(twoDigits(thousand) + ' Thousand');
  if (rest) parts.push(threeDigits(rest));
  return parts.join(' ');
}

// "Taka Two Lakh Fifty Thousand and Paisa Fifty Only"
export function amountInWords(amount) {
  const taka = Math.floor(Math.abs(amount));
  const paisa = Math.round((Math.abs(amount) - taka) * 100);
  let out = 'Taka ' + numberToWords(taka);
  if (paisa > 0) out += ' and Paisa ' + twoDigits(paisa);
  return out + ' Only';
}
