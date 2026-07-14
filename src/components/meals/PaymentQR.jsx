import { useState } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { QrCode, X } from 'lucide-react';

// Encodes a plain-text payload, not a bkash:// deep link — bKash/Nagad don't
// publish a stable public URI scheme, so plain text stays robust and
// readable if scanned by any generic QR reader.
function payload(method, number, amount, groupName) {
  const amt = amount ? `৳${Number(amount).toLocaleString()}` : '';
  return `Send ${amt} to ${method} ${number} (Send Money)${groupName ? ` — ${groupName}` : ''}`.trim();
}

export default function PaymentQR({ paymentInfo, groupName, amount }) {
  const [open, setOpen] = useState(null); // 'bkash' | 'nagad' | null

  const bkash = paymentInfo?.bkash_number;
  const nagad = paymentInfo?.nagad_number;
  if (!bkash && !nagad) return null;

  return (
    <div className="flex flex-wrap items-center gap-2">
      {bkash && (
        <button type="button" onClick={() => setOpen('bkash')} className="flex items-center gap-2 px-3 py-2 rounded-xl bg-pink-500/10 border border-pink-500/20 text-pink-400 text-sm hover:bg-pink-500/20">
          <QrCode size={15} /> bKash QR
        </button>
      )}
      {nagad && (
        <button type="button" onClick={() => setOpen('nagad')} className="flex items-center gap-2 px-3 py-2 rounded-xl bg-orange-500/10 border border-orange-500/20 text-orange-400 text-sm hover:bg-orange-500/20">
          <QrCode size={15} /> Nagad QR
        </button>
      )}

      {open && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4" onClick={() => setOpen(null)}>
          <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6 w-full max-w-xs text-center" onClick={e => e.stopPropagation()}>
            <button onClick={() => setOpen(null)} className="ml-auto block text-white/40 hover:text-white mb-2"><X size={18} /></button>
            <h3 className="text-white font-semibold mb-1">{open === 'bkash' ? 'bKash' : 'Nagad'} Send Money</h3>
            <p className="text-white/40 text-xs mb-4">{open === 'bkash' ? bkash : nagad}</p>
            <div className="bg-white rounded-xl p-4 inline-block">
              <QRCodeSVG value={payload(open === 'bkash' ? 'bKash' : 'Nagad', open === 'bkash' ? bkash : nagad, amount, groupName)} size={200} />
            </div>
            <p className="text-white/30 text-xs mt-3">Scan and send manually — this isn't an automatic payment link.</p>
          </div>
        </div>
      )}
    </div>
  );
}
