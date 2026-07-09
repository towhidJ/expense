import { useState, useEffect } from 'react';
import { useBazar } from '../hooks/useBazar';
import { useAccounts } from '../context/AccountContext';
import { useCategories } from '../hooks/useCategories';
import { useAttachments } from '../hooks/useAttachments';
import DocumentUpload from '../components/DocumentUpload';
import { ShoppingBasket, Plus, Store, Banknote, HandCoins, Edit2, Trash2, X, Phone, Paperclip, FileText } from 'lucide-react';

const inputCls = "w-full bg-[#12122a] border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-cyan-500/50";
const labelCls = "block text-sm text-white/60 mb-1";

export default function Bazar() {
  const { shops, purchases, payments, loading, addShop, updateShop, deleteShop, addPurchase, deletePurchase, payShop } = useBazar();
  const { accounts, fetchAccounts } = useAccounts();
  const { categories } = useCategories();
  const { uploadMany, fetchAttachments } = useAttachments();
  const [invoiceFiles, setInvoiceFiles] = useState([]);
  const [invoiceView, setInvoiceView] = useState(null); // { purchase, attachments } | 'loading'
  const expenseCategories = categories?.filter(c => c.type === 'expense') || [];
  // Preselect a grocery-ish category if the user has one
  const defaultCategory = expenseCategories.find(c => /bazar|বাজার|groc|food|খাবার/i.test(c.name)) || expenseCategories[0];

  const [historyTab, setHistoryTab] = useState('purchases');

  // Purchase form
  const [isAdding, setIsAdding] = useState(false);
  const initialPurchase = {
    payment_type: 'cash',
    account_id: '',
    shop_id: '',
    category_id: '',
    amount: '',
    date: new Date().toISOString().split('T')[0],
    description: ''
  };
  const [purchaseForm, setPurchaseForm] = useState(initialPurchase);

  // Shop add/edit form
  const [shopModal, setShopModal] = useState(null); // null | 'new' | shop object
  const [shopForm, setShopForm] = useState({ name: '', phone: '', notes: '' });

  // Pay due modal
  const [payingShop, setPayingShop] = useState(null);
  const [payForm, setPayForm] = useState({ account_id: '', amount: '', date: '', notes: '' });

  useEffect(() => {
    if (isAdding && !purchaseForm.category_id && defaultCategory) {
      setPurchaseForm(f => ({ ...f, category_id: defaultCategory.id }));
    }
  }, [isAdding, defaultCategory, purchaseForm.category_id]);

  const totalShopDue = shops.reduce((sum, s) => sum + Number(s.remaining_balance || 0), 0);
  const thisMonth = new Date().toISOString().slice(0, 7);
  const monthPurchases = purchases.filter(p => p.date?.startsWith(thisMonth));
  const monthTotal = monthPurchases.reduce((sum, p) => sum + Number(p.amount), 0);
  const monthCash = monthPurchases.filter(p => p.payment_type === 'cash').reduce((sum, p) => sum + Number(p.amount), 0);
  const monthDue = monthTotal - monthCash;
  const monthPayments = payments.filter(p => p.date?.startsWith(thisMonth)).reduce((sum, p) => sum + Number(p.amount), 0);

  const handlePurchaseSubmit = async (e) => {
    e.preventDefault();
    try {
      const { transactionId } = await addPurchase({ ...purchaseForm, amount: parseFloat(purchaseForm.amount) });
      if (invoiceFiles.length && transactionId) {
        try {
          await uploadMany(invoiceFiles, { transactionId });
        } catch (upErr) {
          console.error(upErr);
          alert('Purchase saved, but invoice upload failed: ' + upErr.message);
        }
      }
      setIsAdding(false);
      setInvoiceFiles([]);
      setPurchaseForm({ ...initialPurchase, category_id: purchaseForm.category_id });
      await fetchAccounts();
    } catch (err) {
      console.error(err);
      alert('Error saving purchase: ' + err.message);
    }
  };

  const handleViewInvoice = async (p) => {
    if (!p.transaction_id) { alert('No invoice attached.'); return; }
    setInvoiceView('loading');
    const atts = await fetchAttachments({ transactionId: p.transaction_id });
    setInvoiceView({ purchase: p, attachments: atts });
  };

  const handleShopSubmit = async (e) => {
    e.preventDefault();
    try {
      if (shopModal === 'new') {
        await addShop(shopForm);
      } else {
        await updateShop(shopModal.id, shopForm);
      }
      setShopModal(null);
    } catch (err) {
      console.error(err);
      alert('Error saving shop: ' + err.message);
    }
  };

  const handleDeleteShop = async (shop) => {
    if (Number(shop.remaining_balance) > 0) {
      alert('This shop still has due. Pay it off before deleting.');
      return;
    }
    if (!window.confirm(`Delete shop "${shop.name}"? Purchase history will be kept.`)) return;
    try {
      await deleteShop(shop.id);
    } catch (err) {
      console.error(err);
      alert('Error deleting shop: ' + err.message);
    }
  };

  const handleDeletePurchase = async (p) => {
    if (!window.confirm('Delete this purchase? Account balance / shop due will be restored.')) return;
    try {
      await deletePurchase(p.id);
      await fetchAccounts();
    } catch (err) {
      console.error(err);
      alert('Error deleting purchase: ' + err.message);
    }
  };

  const handlePaySubmit = async (e) => {
    e.preventDefault();
    const amount = parseFloat(payForm.amount);
    if (amount > Number(payingShop.remaining_balance)) {
      if (!window.confirm('Amount is more than the current due. Continue?')) return;
    }
    try {
      await payShop({ shop_id: payingShop.id, account_id: payForm.account_id, amount, date: payForm.date, notes: payForm.notes });
      setPayingShop(null);
      await fetchAccounts();
    } catch (err) {
      console.error(err);
      alert('Error paying due: ' + err.message);
    }
  };

  if (loading) return <div className="text-white/50 p-6">Loading bazar...</div>;

  return (
    <div className="space-y-6 animate-in">
      {/* Header */}
      <div className="flex flex-wrap justify-between items-center gap-3">
        <div>
          <h1 className="text-2xl font-bold text-white">Bazar (বাজার)</h1>
          <p className="text-white/40 text-sm mt-1">Daily cash bazar & monthly shop dues in one place.</p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => { setShopForm({ name: '', phone: '', notes: '' }); setShopModal('new'); }}
            className="flex items-center gap-2 bg-white/5 hover:bg-white/10 border border-white/10 text-white px-4 py-2 rounded-xl transition-colors"
          >
            <Store size={18} /> New Shop
          </button>
          <button
            onClick={() => setIsAdding(true)}
            className="flex items-center gap-2 bg-cyan-500 hover:bg-cyan-600 text-white px-4 py-2 rounded-xl transition-colors shadow-lg shadow-cyan-500/20"
          >
            <Plus size={18} /> New Purchase
          </button>
        </div>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <div className="bg-white/5 border border-white/10 rounded-xl p-4">
          <p className="text-white/40 text-xs">This Month Bazar</p>
          <p className="text-white text-lg font-semibold mt-1">৳{monthTotal.toLocaleString()}</p>
        </div>
        <div className="bg-white/5 border border-white/10 rounded-xl p-4">
          <p className="text-white/40 text-xs">Cash (নগদ)</p>
          <p className="text-emerald-400 text-lg font-semibold mt-1">৳{monthCash.toLocaleString()}</p>
        </div>
        <div className="bg-white/5 border border-white/10 rounded-xl p-4">
          <p className="text-white/40 text-xs">On Due (বাকিতে)</p>
          <p className="text-amber-400 text-lg font-semibold mt-1">৳{monthDue.toLocaleString()}</p>
        </div>
        <div className="bg-white/5 border border-white/10 rounded-xl p-4">
          <p className="text-white/40 text-xs">Total Shop Due (মোট বাকি)</p>
          <p className="text-red-400 text-lg font-semibold mt-1">৳{totalShopDue.toLocaleString()}</p>
          {monthPayments > 0 && <p className="text-white/30 text-[11px] mt-0.5">Paid this month: ৳{monthPayments.toLocaleString()}</p>}
        </div>
      </div>

      {/* Purchase form */}
      {isAdding && (
        <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-6">
          <h2 className="text-lg font-semibold text-white mb-4">Record a Bazar Purchase</h2>
          <form onSubmit={handlePurchaseSubmit} className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="sm:col-span-2">
              <label className={labelCls}>Payment</label>
              <div className="grid grid-cols-2 gap-2">
                <button
                  type="button"
                  onClick={() => setPurchaseForm({ ...purchaseForm, payment_type: 'cash' })}
                  className={`flex items-center justify-center gap-2 py-2.5 rounded-xl border text-sm font-medium transition-colors ${
                    purchaseForm.payment_type === 'cash'
                      ? 'bg-emerald-500/20 border-emerald-500/40 text-emerald-300'
                      : 'bg-white/5 border-white/10 text-white/50 hover:text-white'
                  }`}
                >
                  <Banknote size={16} /> Cash (নগদ)
                </button>
                <button
                  type="button"
                  onClick={() => setPurchaseForm({ ...purchaseForm, payment_type: 'due' })}
                  className={`flex items-center justify-center gap-2 py-2.5 rounded-xl border text-sm font-medium transition-colors ${
                    purchaseForm.payment_type === 'due'
                      ? 'bg-amber-500/20 border-amber-500/40 text-amber-300'
                      : 'bg-white/5 border-white/10 text-white/50 hover:text-white'
                  }`}
                >
                  <HandCoins size={16} /> Due (বাকিতে)
                </button>
              </div>
            </div>

            {purchaseForm.payment_type === 'cash' ? (
              <div>
                <label className={labelCls}>Pay From Account</label>
                <select required value={purchaseForm.account_id} onChange={e => setPurchaseForm({ ...purchaseForm, account_id: e.target.value })} className={inputCls}>
                  <option value="">Select Account</option>
                  {accounts.map(a => <option key={a.id} value={a.id}>{a.name} ({a.currency}{Number(a.current_balance).toLocaleString()})</option>)}
                </select>
              </div>
            ) : (
              <div>
                <label className={labelCls}>Shop (দোকান)</label>
                <select required value={purchaseForm.shop_id} onChange={e => setPurchaseForm({ ...purchaseForm, shop_id: e.target.value })} className={inputCls}>
                  <option value="">Select Shop</option>
                  {shops.map(s => <option key={s.id} value={s.id}>{s.name} (Due: ৳{Number(s.remaining_balance).toLocaleString()})</option>)}
                </select>
                {shops.length === 0 && <p className="text-xs text-amber-400/80 mt-1">No shops yet — add one with the "New Shop" button first.</p>}
              </div>
            )}

            <div>
              <label className={labelCls}>Category</label>
              <select required value={purchaseForm.category_id} onChange={e => setPurchaseForm({ ...purchaseForm, category_id: e.target.value })} className={inputCls}>
                <option value="">Select Category</option>
                {expenseCategories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
              {expenseCategories.length === 0 && <p className="text-xs text-amber-400/80 mt-1">Create an expense category (e.g. "Bazar") in Categories first.</p>}
            </div>

            <div>
              <label className={labelCls}>Amount</label>
              <input required type="number" step="0.01" min="0.01" value={purchaseForm.amount} onChange={e => setPurchaseForm({ ...purchaseForm, amount: e.target.value })} className={inputCls} />
            </div>
            <div>
              <label className={labelCls}>Date</label>
              <input required type="date" value={purchaseForm.date} onChange={e => setPurchaseForm({ ...purchaseForm, date: e.target.value })} className={inputCls} />
            </div>
            <div className="sm:col-span-2">
              <label className={labelCls}>Description (items bought)</label>
              <textarea value={purchaseForm.description} onChange={e => setPurchaseForm({ ...purchaseForm, description: e.target.value })} rows={2} className={inputCls} placeholder="e.g. Rice 5kg, fish, vegetables" />
            </div>
            <div className="sm:col-span-2">
              <DocumentUpload files={invoiceFiles} onChange={setInvoiceFiles} label="Invoice / Receipt (Optional, max 25 MB)" />
            </div>
            <div className="sm:col-span-2 flex justify-end gap-3 mt-2">
              <button type="button" onClick={() => setIsAdding(false)} className="px-5 py-2.5 rounded-xl text-white/60 hover:text-white hover:bg-white/5 transition-colors">Cancel</button>
              <button type="submit" className="bg-cyan-500 hover:bg-cyan-600 text-white px-6 py-2.5 rounded-xl shadow-lg shadow-cyan-500/20 transition-all font-medium">Save Purchase</button>
            </div>
          </form>
        </div>
      )}

      {/* Shops */}
      <div>
        <h2 className="text-lg font-semibold text-white mb-3">Shops (দোকানের খাতা)</h2>
        {shops.length === 0 ? (
          <div className="bg-white/5 border border-white/10 rounded-2xl p-8 text-center text-white/40">
            <Store className="mx-auto mb-2 opacity-40" size={32} />
            No shops yet. Add the shops you buy bazar from on credit.
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
            {shops.map(shop => (
              <div key={shop.id} className="bg-[#1a1a2e] border border-white/10 rounded-2xl p-4">
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <p className="text-white font-semibold truncate">{shop.name}</p>
                    {shop.phone && (
                      <p className="text-white/40 text-xs flex items-center gap-1 mt-0.5"><Phone size={11} /> {shop.phone}</p>
                    )}
                  </div>
                  <div className="flex gap-1 shrink-0">
                    <button onClick={() => { setShopForm({ name: shop.name, phone: shop.phone || '', notes: shop.notes || '' }); setShopModal(shop); }} className="p-2 rounded-lg bg-white/5 text-white/50 hover:text-white hover:bg-white/10 transition-colors" title="Edit shop">
                      <Edit2 size={14} />
                    </button>
                    <button onClick={() => handleDeleteShop(shop)} className="p-2 rounded-lg bg-white/5 text-red-400/60 hover:text-red-400 hover:bg-red-500/10 transition-colors" title="Delete shop">
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>
                <div className="mt-3 flex items-end justify-between">
                  <div>
                    <p className="text-white/40 text-xs">Current Due (বাকি)</p>
                    <p className={`text-xl font-bold ${Number(shop.remaining_balance) > 0 ? 'text-red-400' : 'text-emerald-400'}`}>
                      ৳{Number(shop.remaining_balance).toLocaleString()}
                    </p>
                  </div>
                  <button
                    onClick={() => {
                      setPayForm({ account_id: '', amount: shop.remaining_balance || '', date: new Date().toISOString().split('T')[0], notes: '' });
                      setPayingShop(shop);
                    }}
                    disabled={Number(shop.remaining_balance) <= 0}
                    className="px-4 py-2 rounded-xl bg-emerald-500/15 border border-emerald-500/30 text-emerald-300 text-sm font-medium hover:bg-emerald-500/25 transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
                  >
                    Pay Due
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* History */}
      <div className="bg-[#1a1a2e] border border-white/10 rounded-2xl overflow-hidden">
        <div className="flex border-b border-white/10">
          <button
            onClick={() => setHistoryTab('purchases')}
            className={`px-5 py-3 text-sm font-medium transition-colors ${historyTab === 'purchases' ? 'text-cyan-400 border-b-2 border-cyan-400' : 'text-white/40 hover:text-white'}`}
          >
            Purchases ({purchases.length})
          </button>
          <button
            onClick={() => setHistoryTab('payments')}
            className={`px-5 py-3 text-sm font-medium transition-colors ${historyTab === 'payments' ? 'text-cyan-400 border-b-2 border-cyan-400' : 'text-white/40 hover:text-white'}`}
          >
            Due Payments ({payments.length})
          </button>
        </div>
        <div className="overflow-x-auto">
          {historyTab === 'purchases' ? (
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-white/5 border-b border-white/10">
                  <th className="text-left py-3 px-4 text-white/60 font-medium">Date</th>
                  <th className="text-left py-3 px-4 text-white/60 font-medium">Payment</th>
                  <th className="text-left py-3 px-4 text-white/60 font-medium">Source</th>
                  <th className="text-right py-3 px-4 text-white/60 font-medium">Amount</th>
                  <th className="text-left py-3 px-4 text-white/60 font-medium">Description</th>
                  <th className="text-right py-3 px-4 text-white/60 font-medium">Action</th>
                </tr>
              </thead>
              <tbody>
                {purchases.length === 0 ? (
                  <tr><td colSpan="6" className="text-center py-8 text-white/40">No bazar purchases yet.</td></tr>
                ) : purchases.map(p => (
                  <tr key={p.id} className="border-b border-white/5 hover:bg-white/[0.02] transition-colors">
                    <td className="py-3 px-4 text-white/70 whitespace-nowrap">{p.date}</td>
                    <td className="py-3 px-4">
                      <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium ${
                        p.payment_type === 'cash' ? 'bg-emerald-500/15 text-emerald-300' : 'bg-amber-500/15 text-amber-300'
                      }`}>
                        {p.payment_type === 'cash' ? <><Banknote size={11} /> Cash</> : <><HandCoins size={11} /> Due</>}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-white/70">{p.payment_type === 'cash' ? (p.accounts?.name || '-') : (p.liabilities?.name || 'Deleted shop')}</td>
                    <td className="py-3 px-4 text-right font-medium text-white">৳{Number(p.amount).toLocaleString()}</td>
                    <td className="py-3 px-4 text-white/50 max-w-[240px] truncate">{p.description || '-'}</td>
                    <td className="py-3 px-4 text-right whitespace-nowrap">
                      <button onClick={() => handleViewInvoice(p)} className="p-2 rounded-lg bg-white/5 text-white/40 hover:text-cyan-400 hover:bg-cyan-500/10 transition-colors" title="View invoice">
                        <Paperclip size={14} />
                      </button>
                      <button onClick={() => handleDeletePurchase(p)} className="ml-1 p-2 rounded-lg bg-white/5 text-red-400/60 hover:text-red-400 hover:bg-red-500/10 transition-colors" title="Delete purchase">
                        <Trash2 size={14} />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-white/5 border-b border-white/10">
                  <th className="text-left py-3 px-4 text-white/60 font-medium">Date</th>
                  <th className="text-left py-3 px-4 text-white/60 font-medium">Shop</th>
                  <th className="text-left py-3 px-4 text-white/60 font-medium">From Account</th>
                  <th className="text-right py-3 px-4 text-white/60 font-medium">Amount</th>
                  <th className="text-left py-3 px-4 text-white/60 font-medium">Notes</th>
                </tr>
              </thead>
              <tbody>
                {payments.length === 0 ? (
                  <tr><td colSpan="5" className="text-center py-8 text-white/40">No due payments yet.</td></tr>
                ) : payments.map(p => (
                  <tr key={p.id} className="border-b border-white/5 hover:bg-white/[0.02] transition-colors">
                    <td className="py-3 px-4 text-white/70 whitespace-nowrap">{p.date}</td>
                    <td className="py-3 px-4 text-white/80">{p.liabilities?.name || '-'}</td>
                    <td className="py-3 px-4 text-white/70">{p.accounts?.name || '-'}</td>
                    <td className="py-3 px-4 text-right font-medium text-emerald-400">৳{Number(p.amount).toLocaleString()}</td>
                    <td className="py-3 px-4 text-white/50">{p.notes || '-'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {/* Invoice viewer modal */}
      {invoiceView && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-[60] flex items-center justify-center p-4" onClick={() => setInvoiceView(null)}>
          <div className="bg-[#12122a] border border-white/10 rounded-2xl w-full max-w-sm shadow-2xl" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between p-5 border-b border-white/10">
              <h2 className="text-lg font-semibold text-white flex items-center gap-2"><Paperclip size={16} /> Invoice</h2>
              <button onClick={() => setInvoiceView(null)} className="text-white/40 hover:text-white transition-colors"><X size={20} /></button>
            </div>
            <div className="p-5 space-y-2">
              {invoiceView === 'loading' ? (
                <p className="text-white/40 text-sm py-4 text-center">Loading...</p>
              ) : invoiceView.attachments.length === 0 ? (
                <p className="text-white/40 text-sm py-4 text-center">No invoice attached to this purchase.</p>
              ) : invoiceView.attachments.map(att => (
                <a
                  key={att.id}
                  href={att.file_url}
                  target="_blank"
                  rel="noreferrer"
                  className="flex items-center gap-2 bg-white/5 border border-white/10 rounded-xl px-3 py-2.5 text-sm text-white/80 hover:text-cyan-400 hover:border-cyan-500/30 transition-colors"
                >
                  <FileText size={15} className="text-cyan-400 shrink-0" />
                  <span className="truncate">{att.file_name}</span>
                </a>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Shop add/edit modal */}
      {shopModal && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-[60] flex items-center justify-center p-4" onClick={() => setShopModal(null)}>
          <div className="bg-[#12122a] border border-white/10 rounded-2xl w-full max-w-sm shadow-2xl" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between p-6 border-b border-white/10">
              <h2 className="text-lg font-semibold text-white">{shopModal === 'new' ? 'Add Shop' : 'Edit Shop'}</h2>
              <button onClick={() => setShopModal(null)} className="text-white/40 hover:text-white transition-colors"><X size={20} /></button>
            </div>
            <form onSubmit={handleShopSubmit} className="p-6 space-y-4">
              <div>
                <label className={labelCls}>Shop Name</label>
                <input required autoFocus value={shopForm.name} onChange={e => setShopForm({ ...shopForm, name: e.target.value })} className={inputCls} placeholder="e.g. Rahim Store" />
              </div>
              <div>
                <label className={labelCls}>Phone (optional)</label>
                <input value={shopForm.phone} onChange={e => setShopForm({ ...shopForm, phone: e.target.value })} className={inputCls} placeholder="01XXXXXXXXX" />
              </div>
              <div>
                <label className={labelCls}>Notes (optional)</label>
                <textarea value={shopForm.notes} onChange={e => setShopForm({ ...shopForm, notes: e.target.value })} rows={2} className={inputCls} />
              </div>
              <button type="submit" className="w-full py-3 rounded-xl bg-gradient-to-r from-cyan-500 to-purple-600 text-white font-semibold text-sm hover:shadow-lg hover:shadow-cyan-500/25 transition-all">
                {shopModal === 'new' ? 'Add Shop' : 'Save Changes'}
              </button>
            </form>
          </div>
        </div>
      )}

      {/* Pay due modal */}
      {payingShop && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-[60] flex items-center justify-center p-4" onClick={() => setPayingShop(null)}>
          <div className="bg-[#12122a] border border-white/10 rounded-2xl w-full max-w-sm shadow-2xl" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between p-6 border-b border-white/10">
              <div>
                <h2 className="text-lg font-semibold text-white">Pay Due — {payingShop.name}</h2>
                <p className="text-xs text-white/40 mt-0.5">Current due: ৳{Number(payingShop.remaining_balance).toLocaleString()}</p>
              </div>
              <button onClick={() => setPayingShop(null)} className="text-white/40 hover:text-white transition-colors"><X size={20} /></button>
            </div>
            <form onSubmit={handlePaySubmit} className="p-6 space-y-4">
              <div>
                <label className={labelCls}>Pay From Account</label>
                <select required value={payForm.account_id} onChange={e => setPayForm({ ...payForm, account_id: e.target.value })} className={inputCls}>
                  <option value="">Select Account</option>
                  {accounts.map(a => <option key={a.id} value={a.id}>{a.name} ({a.currency}{Number(a.current_balance).toLocaleString()})</option>)}
                </select>
              </div>
              <div>
                <label className={labelCls}>Amount</label>
                <input required type="number" step="0.01" min="0.01" value={payForm.amount} onChange={e => setPayForm({ ...payForm, amount: e.target.value })} className={inputCls} />
                <p className="text-xs text-white/30 mt-1">Partial payment is fine — the rest stays as due.</p>
              </div>
              <div>
                <label className={labelCls}>Date</label>
                <input required type="date" value={payForm.date} onChange={e => setPayForm({ ...payForm, date: e.target.value })} className={inputCls} />
              </div>
              <div>
                <label className={labelCls}>Notes (optional)</label>
                <input value={payForm.notes} onChange={e => setPayForm({ ...payForm, notes: e.target.value })} className={inputCls} placeholder="e.g. June month payment" />
              </div>
              <button type="submit" className="w-full py-3 rounded-xl bg-emerald-500 hover:bg-emerald-600 text-white font-semibold text-sm transition-colors shadow-lg shadow-emerald-500/20">
                Pay ৳{payForm.amount ? Number(payForm.amount).toLocaleString() : '0'}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
