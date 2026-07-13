import { X, FileText, Printer } from 'lucide-react';
import { downloadHtmlAsPdf } from '../lib/htmlPdf';
import { amountInWords } from '../lib/amountInWords';

// Printable money voucher for a transaction: DEBIT (expense) / CREDIT (income)
export default function VoucherModal({ transaction: t, entityName, onClose }) {
  if (!t) return null;

  const isDebit = t.type === 'expense';
  const voucherTitle = isDebit ? 'DEBIT VOUCHER' : 'CREDIT VOUCHER';
  const voucherNo = `VCH-${(t.date || '').replace(/-/g, '')}-${(t.id || '').slice(0, 4).toUpperCase()}`;
  const dateStr = new Date(t.date).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
  const amount = Number(t.amount || 0);
  const accountName = t.accounts?.name || (t.liability_id ? 'On Credit (Baki)' : 'N/A');
  const categoryName = t.categories?.name || 'Other';

  // Rendered as browser HTML then captured (html2canvas) so Bangla text in
  // descriptions/categories and the ৳ symbol print correctly.
  const downloadPDF = () => {
    const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    const money = amount.toLocaleString('en-IN', { minimumFractionDigits: 2 });
    const badge = isDebit ? '#dc2626' : '#16a34a';
    const cell = 'border:1px solid #64748b;padding:8px 12px;font-size:13px;color:#111827;';
    const html = `
      <div style="padding:40px 48px;">
        <div style="border:2px solid #374151;padding:28px 32px;">
          <div style="text-align:center;border-bottom:2px solid #1f2937;padding-bottom:12px;">
            <div style="font-size:22px;font-weight:700;color:#111827;">${esc(entityName || 'TakaKhata')}</div>
            <div style="font-size:11px;color:#6b7280;">Personal Finance Manager</div>
            <span style="display:inline-block;margin-top:10px;padding:5px 18px;font-size:12px;font-weight:700;color:#ffffff;background:${badge};border-radius:4px;">${voucherTitle}</span>
          </div>
          <div style="display:flex;justify-content:space-between;font-size:12px;color:#374151;margin:14px 0 10px;">
            <span><b>Voucher No:</b> ${esc(voucherNo)}</span>
            <span><b>Date:</b> ${esc(dateStr)}</span>
          </div>
          <table style="width:100%;border-collapse:collapse;">
            <tr>
              <th style="${cell}background:#f3f4f6;text-align:left;">Particulars</th>
              <th style="${cell}background:#f3f4f6;text-align:right;width:130px;">Amount (৳)</th>
            </tr>
            <tr>
              <td style="${cell}vertical-align:top;">
                <div style="font-weight:600;color:#111827;">${esc(t.description || categoryName)}</div>
                <div style="font-size:11px;color:#6b7280;margin-top:4px;">Category: ${esc(categoryName)}</div>
                <div style="font-size:11px;color:#6b7280;">${isDebit ? 'Paid From' : 'Received In'}: ${esc(accountName)}</div>
              </td>
              <td style="${cell}text-align:right;font-weight:700;vertical-align:top;">${money}</td>
            </tr>
            <tr>
              <td style="${cell}text-align:right;font-weight:700;">Total</td>
              <td style="${cell}text-align:right;font-weight:700;">${money}</td>
            </tr>
          </table>
          <div style="font-size:11.5px;font-style:italic;color:#374151;margin-top:10px;"><b>In Words:</b> ${esc(amountInWords(amount))}</div>
          <div style="display:flex;justify-content:space-between;gap:24px;margin-top:64px;">
            ${['Prepared By', 'Checked By', isDebit ? 'Received By' : 'Deposited By']
              .map(l => `<div style="flex:1;text-align:center;border-top:1px solid #4b5563;padding-top:5px;font-size:11px;color:#4b5563;">${l}</div>`)
              .join('')}
          </div>
        </div>
      </div>`;
    downloadHtmlAsPdf(html, `${voucherNo}.pdf`);
  };

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-[60] flex items-center justify-center p-4" onClick={onClose}>
      <div className="bg-[#12122a] border border-white/10 rounded-2xl w-full max-w-lg shadow-2xl max-h-[90vh] overflow-y-auto" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between p-5 border-b border-white/10">
          <h2 className="text-lg font-semibold text-white flex items-center gap-2"><Printer size={18} /> Voucher</h2>
          <button onClick={onClose} className="text-white/40 hover:text-white transition-colors"><X size={20} /></button>
        </div>

        {/* Paper preview */}
        <div className="p-5">
          <div className="bg-white text-gray-900 rounded-lg p-6 shadow-inner">
            <div className="text-center border-b-2 border-gray-800 pb-3">
              <p className="text-xl font-bold">{entityName || 'TakaKhata'}</p>
              <p className="text-[11px] text-gray-500">Personal Finance Manager</p>
              <span className={`inline-block mt-2 px-4 py-1 text-xs font-bold text-white rounded ${isDebit ? 'bg-red-600' : 'bg-green-600'}`}>
                {voucherTitle}
              </span>
            </div>
            <div className="flex justify-between text-xs mt-3 mb-2 text-gray-700">
              <span><b>Voucher No:</b> {voucherNo}</span>
              <span><b>Date:</b> {dateStr}</span>
            </div>
            <table className="w-full text-sm border border-gray-400 border-collapse">
              <thead>
                <tr>
                  <th className="border border-gray-400 px-2 py-1.5 text-left text-xs bg-gray-100">Particulars</th>
                  <th className="border border-gray-400 px-2 py-1.5 text-right text-xs bg-gray-100 w-28">Amount (৳)</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td className="border border-gray-400 px-2 py-2 align-top">
                    <p className="font-medium">{t.description || categoryName}</p>
                    <p className="text-xs text-gray-500 mt-1">Category: {categoryName}</p>
                    <p className="text-xs text-gray-500">{isDebit ? 'Paid From' : 'Received In'}: {accountName}</p>
                  </td>
                  <td className="border border-gray-400 px-2 py-2 text-right font-semibold align-top">
                    {amount.toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                  </td>
                </tr>
                <tr>
                  <td className="border border-gray-400 px-2 py-1.5 font-bold text-right">Total</td>
                  <td className="border border-gray-400 px-2 py-1.5 text-right font-bold">
                    {amount.toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                  </td>
                </tr>
              </tbody>
            </table>
            <p className="text-xs italic mt-2 text-gray-700"><b>In Words:</b> {amountInWords(amount)}</p>
            <div className="grid grid-cols-3 gap-4 mt-10 text-center text-[11px] text-gray-600">
              <div className="border-t border-gray-500 pt-1">Prepared By</div>
              <div className="border-t border-gray-500 pt-1">Checked By</div>
              <div className="border-t border-gray-500 pt-1">{isDebit ? 'Received By' : 'Deposited By'}</div>
            </div>
          </div>
        </div>

        <div className="flex justify-end gap-3 px-5 pb-5">
          <button onClick={onClose} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Close</button>
          <button onClick={downloadPDF} className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-5 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 transition-all font-medium">
            <FileText size={16} /> Download PDF
          </button>
        </div>
      </div>
    </div>
  );
}
