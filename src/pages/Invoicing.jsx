import { useMemo, useState } from 'react';
import { useInvoices } from '../hooks/useInvoices';
import { useAccounts } from '../context/AccountContext';
import { useCategories } from '../hooks/useCategories';
import { useEntity } from '../context/EntityContext';
import { downloadHtmlAsPdf, statementHtml } from '../lib/htmlPdf';
import StatCard from '../components/StatCard';
import { Receipt, Plus, Trash2, Download, CheckCircle2, X } from 'lucide-react';

const fmt = (n) => `৳${Math.round(Number(n || 0)).toLocaleString()}`;
const today = () => new Date().toISOString().split('T')[0];
const STATUS_META = {
  draft: { label: 'Draft', cls: 'bg-white/10 text-white/50' },
  sent: { label: 'Sent', cls: 'bg-cyan-500/20 text-cyan-400' },
  paid: { label: 'Paid', cls: 'bg-emerald-500/20 text-emerald-400' },
  overdue: { label: 'Overdue', cls: 'bg-red-500/20 text-red-400' },
  cancelled: { label: 'Cancelled', cls: 'bg-white/5 text-white/30' }
};

const invoiceTotal = (inv) => (inv.invoice_items || []).reduce((s, it) => s + Number(it.quantity) * Number(it.unit_price), 0);

export default function Invoicing() {
  const { invoices, loading, saveInvoice, deleteInvoice, markPaid } = useInvoices();
  const { accounts } = useAccounts();
  const { categories } = useCategories();
  const { currentEntity } = useEntity();
  const incomeCategories = categories?.filter(c => c.type === 'income') || [];

  const [editing, setEditing] = useState(null); // invoice being edited, or 'new'
  const [payingInvoice, setPayingInvoice] = useState(null);
  const [payForm, setPayForm] = useState({ account_id: '', category_id: '', date: today() });

  const initialForm = () => ({
    invoice_number: `INV-${String(invoices.length + 1).padStart(4, '0')}`,
    client_name: '', client_contact: '', issue_date: today(), due_date: '', notes: '',
    items: [{ description: '', quantity: 1, unit_price: '' }]
  });
  const [form, setForm] = useState(initialForm);

  const now = new Date();
  const unpaid = invoices.filter(i => i.status !== 'paid' && i.status !== 'cancelled');
  const unpaidTotal = unpaid.reduce((s, i) => s + invoiceTotal(i), 0);
  const paidThisYear = invoices.filter(i => i.status === 'paid' && new Date(i.issue_date).getFullYear() === now.getFullYear()).reduce((s, i) => s + invoiceTotal(i), 0);

  const formTotal = useMemo(() => form.items.reduce((s, it) => s + (Number(it.quantity) || 0) * (Number(it.unit_price) || 0), 0), [form.items]);

  const openNew = () => { setForm(initialForm()); setEditing('new'); };
  const openEdit = (inv) => {
    setForm({
      invoice_number: inv.invoice_number, client_name: inv.client_name, client_contact: inv.client_contact || '',
      issue_date: inv.issue_date, due_date: inv.due_date || '', notes: inv.notes || '',
      items: inv.invoice_items?.length ? inv.invoice_items.map(it => ({ description: it.description, quantity: it.quantity, unit_price: it.unit_price })) : [{ description: '', quantity: 1, unit_price: '' }]
    });
    setEditing(inv.id);
  };

  const updateItem = (i, field, value) => setForm(f => ({ ...f, items: f.items.map((it, idx) => idx === i ? { ...it, [field]: value } : it) }));
  const addItem = () => setForm(f => ({ ...f, items: [...f.items, { description: '', quantity: 1, unit_price: '' }] }));
  const removeItem = (i) => setForm(f => ({ ...f, items: f.items.filter((_, idx) => idx !== i) }));

  const handleSave = async (e) => {
    e.preventDefault();
    try {
      const items = form.items.filter(it => it.description.trim()).map(it => ({ description: it.description, quantity: parseFloat(it.quantity) || 1, unit_price: parseFloat(it.unit_price) || 0 }));
      await saveInvoice({
        invoice_number: form.invoice_number,
        client_name: form.client_name,
        client_contact: form.client_contact || null,
        issue_date: form.issue_date,
        due_date: form.due_date || null,
        notes: form.notes || null,
        status: editing === 'new' ? 'draft' : undefined
      }, items, editing === 'new' ? null : editing);
      setEditing(null);
    } catch (err) {
      alert(err.code === '23505' ? 'This invoice number already exists.' : 'Error saving invoice: ' + err.message);
    }
  };

  const handleMarkPaid = async (e) => {
    e.preventDefault();
    try {
      await markPaid(payingInvoice.id, payForm);
      setPayingInvoice(null);
    } catch (err) {
      alert('Error marking paid: ' + err.message);
    }
  };

  const exportPdf = (inv) => {
    const head = ['Description', 'Qty', 'Unit Price', 'Total'];
    const rows = (inv.invoice_items || []).map(it => [it.description, String(it.quantity), fmt(it.unit_price), fmt(it.quantity * it.unit_price)]);
    rows.push(['', '', 'Total', fmt(invoiceTotal(inv))]);
    const html = statementHtml({
      entityName: currentEntity?.name,
      title: `Invoice ${inv.invoice_number}`,
      subtitle: `${inv.client_name} · Issued ${new Date(inv.issue_date).toLocaleDateString()}${inv.due_date ? ` · Due ${new Date(inv.due_date).toLocaleDateString()}` : ''}`,
      head, rows, boldRows: [rows.length - 1]
    });
    downloadHtmlAsPdf(html, `${inv.invoice_number}.pdf`);
  };

  if (loading) return <div className="text-white/50 p-6">Loading invoices...</div>;

  return (
    <div className="space-y-6 animate-in">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-white">Invoicing</h1>
          <p className="text-white/40 text-sm mt-1">Bill clients and track payments.</p>
        </div>
        <button onClick={openNew} className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-cyan-500/20">
          <Plus size={18} /> New Invoice
        </button>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <StatCard title="Outstanding" value={fmt(unpaidTotal)} icon={Receipt} gradient={["#f59e0b", "#d97706"]} iconBg="bg-amber-500/10" />
        <StatCard title="Paid This Year" value={fmt(paidThisYear)} icon={CheckCircle2} gradient={["#34d399", "#10b981"]} iconBg="bg-emerald-500/10" />
        <StatCard title="Unpaid Invoices" value={unpaid.length} icon={Receipt} gradient={["#f87171", "#ef4444"]} iconBg="bg-red-500/10" />
      </div>

      {editing && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4">{editing === 'new' ? 'New Invoice' : 'Edit Invoice'}</h2>
          <form onSubmit={handleSave} className="space-y-4">
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <div>
                <label className="block text-sm text-white/60 mb-1">Invoice Number</label>
                <input required type="text" value={form.invoice_number} onChange={e => setForm({ ...form, invoice_number: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Client Name</label>
                <input required type="text" value={form.client_name} onChange={e => setForm({ ...form, client_name: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Client Contact</label>
                <input type="text" value={form.client_contact} onChange={e => setForm({ ...form, client_contact: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
              </div>
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="block text-sm text-white/60 mb-1">Issue Date</label>
                  <input required type="date" value={form.issue_date} onChange={e => setForm({ ...form, issue_date: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-3 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
                </div>
                <div>
                  <label className="block text-sm text-white/60 mb-1">Due Date</label>
                  <input type="date" value={form.due_date} onChange={e => setForm({ ...form, due_date: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-3 py-2.5 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
                </div>
              </div>
            </div>

            <div className="space-y-2">
              <label className="block text-sm text-white/60">Line Items</label>
              {form.items.map((it, i) => (
                <div key={i} className="flex gap-2">
                  <input type="text" placeholder="Description" value={it.description} onChange={e => updateItem(i, 'description', e.target.value)} className="flex-1 bg-[#12122a] border border-white/10 rounded-xl px-3 py-2 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
                  <input type="number" step="0.01" placeholder="Qty" value={it.quantity} onChange={e => updateItem(i, 'quantity', e.target.value)} className="w-20 bg-[#12122a] border border-white/10 rounded-xl px-3 py-2 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
                  <input type="number" step="0.01" placeholder="Unit Price" value={it.unit_price} onChange={e => updateItem(i, 'unit_price', e.target.value)} className="w-32 bg-[#12122a] border border-white/10 rounded-xl px-3 py-2 text-white text-sm focus:outline-none focus:border-cyan-500/50" />
                  <button type="button" onClick={() => removeItem(i)} className="text-white/30 hover:text-red-400 p-2"><X size={16} /></button>
                </div>
              ))}
              <button type="button" onClick={addItem} className="text-xs text-cyan-400 hover:underline">+ Add line item</button>
              <p className="text-right text-white font-semibold">Total: {fmt(formTotal)}</p>
            </div>

            <div>
              <label className="block text-sm text-white/60 mb-1">Notes</label>
              <textarea value={form.notes} onChange={e => setForm({ ...form, notes: e.target.value })} rows={2} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50" />
            </div>

            <div className="flex justify-end gap-3">
              <button type="button" onClick={() => setEditing(null)} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
              <button type="submit" className="bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 transition-all font-medium">Save Invoice</button>
            </div>
          </form>
        </div>
      )}

      {payingInvoice && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6 w-full max-w-md shadow-2xl">
            <h2 className="text-xl font-semibold text-white mb-2">Mark Paid</h2>
            <p className="text-sm text-white/50 mb-6">{payingInvoice.invoice_number} — <strong className="text-white">{fmt(invoiceTotal(payingInvoice))}</strong></p>
            <form onSubmit={handleMarkPaid} className="space-y-4">
              <div>
                <label className="block text-sm text-white/60 mb-1">Deposit To Account</label>
                <select required value={payForm.account_id} onChange={e => setPayForm({ ...payForm, account_id: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50">
                  <option value="">Select an account...</option>
                  {accounts.map(a => <option key={a.id} value={a.id}>{a.name}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Income Category</label>
                <select required value={payForm.category_id} onChange={e => setPayForm({ ...payForm, category_id: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50">
                  <option value="">Select a category...</option>
                  {incomeCategories.map(c => <option key={c.id} value={c.id}>{c.icon} {c.name}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-sm text-white/60 mb-1">Payment Date</label>
                <input required type="date" value={payForm.date} onChange={e => setPayForm({ ...payForm, date: e.target.value })} className="w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-emerald-500/50" />
              </div>
              <div className="flex justify-end gap-3 mt-6">
                <button type="button" onClick={() => setPayingInvoice(null)} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
                <button type="submit" className="bg-emerald-500 hover:bg-emerald-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-emerald-500/20 transition-all font-medium">Confirm</button>
              </div>
            </form>
          </div>
        </div>
      )}

      <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-white/5 border-b border-white/10">
                <th className="text-left py-3 px-5 text-white/60 font-medium">Invoice</th>
                <th className="text-left py-3 px-5 text-white/60 font-medium">Client</th>
                <th className="text-right py-3 px-5 text-white/60 font-medium">Total</th>
                <th className="text-left py-3 px-5 text-white/60 font-medium">Status</th>
                <th className="text-right py-3 px-5 text-white/60 font-medium">Actions</th>
              </tr>
            </thead>
            <tbody>
              {invoices.map(inv => (
                <tr key={inv.id} className="border-b border-white/5 hover:bg-white/[0.02]">
                  <td className="py-3 px-5 text-white font-medium">{inv.invoice_number}</td>
                  <td className="py-3 px-5 text-white/70">{inv.client_name}</td>
                  <td className="py-3 px-5 text-right text-white font-medium">{fmt(invoiceTotal(inv))}</td>
                  <td className="py-3 px-5">
                    <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${STATUS_META[inv.status].cls}`}>{STATUS_META[inv.status].label.toUpperCase()}</span>
                  </td>
                  <td className="py-3 px-5">
                    <div className="flex justify-end gap-2">
                      {inv.status !== 'paid' && inv.status !== 'cancelled' && (
                        <button onClick={() => { setPayingInvoice(inv); setPayForm({ account_id: '', category_id: '', date: today() }); }} className="text-xs bg-emerald-500 hover:bg-emerald-600 text-white px-3 py-1.5 rounded-lg font-medium">
                          Mark Paid
                        </button>
                      )}
                      <button onClick={() => openEdit(inv)} className="text-xs bg-white/5 hover:bg-white/10 text-white/60 px-3 py-1.5 rounded-lg">Edit</button>
                      <button onClick={() => exportPdf(inv)} className="text-white/40 hover:text-cyan-400 p-1.5 rounded-lg hover:bg-cyan-500/10" title="Download PDF"><Download size={14} /></button>
                      <button onClick={() => { if (confirm(`Delete invoice ${inv.invoice_number}?`)) deleteInvoice(inv.id).catch(err => alert(err.message)); }} className="text-white/30 hover:text-red-400 p-1.5 rounded-lg hover:bg-red-500/10"><Trash2 size={14} /></button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {invoices.length === 0 && (
          <div className="text-center py-10">
            <Receipt className="mx-auto text-white/20 mb-3" size={40} />
            <p className="text-white/40 text-sm">No invoices yet — create the first one.</p>
          </div>
        )}
      </div>
    </div>
  );
}
