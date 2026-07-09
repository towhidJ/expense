import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../pdf_export.dart';
import '../theme.dart';

/// Reports with 6 tabs mirroring the web app:
/// Overview • Income Statement • Cash Flow • Balance Sheet • Trial Balance • Bazar Report.
/// Every statement can be shared as a PDF (rendered from the widget itself,
/// so Bangla text is pixel-perfect).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Tx>? _txs;
  List<Liability> _liabilities = [];
  List<Repayment> _repayments = [];
  List<Saving> _savings = [];
  List<Transfer> _transfers = [];
  List<Asset> _assets = [];
  List<Investment> _investments = [];
  List<Liability> _shops = [];
  List<BazarPurchase> _bazarPurchases = [];
  List<Repayment> _bazarPayments = [];

  final _incomeKey = GlobalKey();
  final _cashKey = GlobalKey();
  final _balanceKey = GlobalKey();
  final _trialKey = GlobalKey();
  final _bazarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _txs = null);
    final st = widget.state;
    final txs = await st.fetchTransactions(start: _month, end: DateTime(_month.year, _month.month + 1, 0));
    final (liabs, repays) = await st.fetchLiabilities();
    final savings = await st.fetchSavings();
    final transfers = await st.fetchTransfers();
    final assets = await st.fetchAssets();
    final investments = await st.fetchInvestments();
    final (shops, bazarPurchases, bazarPayments) = await st.fetchBazar();
    if (!mounted) return;
    setState(() {
      _liabilities = liabs;
      _repayments = repays;
      _savings = savings;
      _transfers = transfers;
      _assets = assets;
      _investments = investments;
      _shops = shops;
      _bazarPurchases = bazarPurchases;
      _bazarPayments = bazarPayments;
      _txs = txs;
    });
  }

  bool _inMonth(DateTime d) => d.year == _month.year && d.month == _month.month;

  Map<String, double> _byCategory(String type) {
    final map = <String, double>{};
    for (final t in _txs ?? <Tx>[]) {
      if (t.type != type) continue;
      final key = t.categoryName.isEmpty ? 'Uncategorized' : t.categoryName;
      map[key] = (map[key] ?? 0) + t.amount;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports & Statements', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Income Statement'),
              Tab(text: 'Cash Flow'),
              Tab(text: 'Balance Sheet'),
              Tab(text: 'Trial Balance'),
              Tab(text: 'Bazar Report'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() => _month = DateTime(_month.year, _month.month - 1));
                      _load();
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(DateFormat('MMMM yyyy').format(_month),
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: kFg)),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _month = DateTime(_month.year, _month.month + 1));
                      _load();
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _txs == null
                  ? const Center(child: CircularProgressIndicator(color: kCyan))
                  : TabBarView(
                      children: [
                        _overview(),
                        _incomeStatement(),
                        _cashFlow(),
                        _balanceSheet(),
                        _trialBalance(),
                        _bazarReport(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- shared building blocks ----------

  Widget _statementCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
    GlobalKey? pdfKey,
    String? fileName,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        FadeSlideIn(
          child: RepaintBoundary(
            key: pdfKey,
            // Opaque background so the captured PDF isn't transparent.
            child: Container(
              color: kBg,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Text(widget.state.currentEntity?.name.toUpperCase() ?? '',
                                    style: const TextStyle(fontSize: 10, letterSpacing: 2, color: kCyan)),
                                const SizedBox(height: 2),
                                Text(title,
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kFg)),
                                Text(subtitle, style: TextStyle(fontSize: 11, color: kFg38)),
                              ],
                            ),
                          ),
                          if (pdfKey != null && fileName != null)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Download PDF',
                                onPressed: () async {
                                  try {
                                    await exportBoundaryAsPdf(pdfKey, fileName);
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(content: Text('PDF error: $e')));
                                    }
                                  }
                                },
                                icon: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: kRed),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: kCyan)),
      );

  Widget _line(String label, String value, {bool muted = false, Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.5),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: muted ? kFg38 : kFg70)),
            ),
            Text(value, style: TextStyle(fontSize: 13, color: valueColor ?? (muted ? kFg38 : kFg))),
          ],
        ),
      );

  Widget _total(String label, String value, Color color) => Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.only(top: 7, bottom: 2),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: kFg12))),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color))),
            Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      );

  Widget _netBanner(String label, String value, bool positive) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: (positive ? kEmerald : kRed).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (positive ? kEmerald : kRed).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: positive ? kEmerald : kRed))),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: positive ? kEmerald : kRed)),
          ],
        ),
      );

  // ---------- Overview (original report) ----------

  Widget _overview() {
    final txs = _txs!;
    final income = txs.where((t) => t.type == 'income').fold<double>(0, (s, t) => s + t.amount);
    final expense = txs.where((t) => t.type == 'expense').fold<double>(0, (s, t) => s + t.amount);
    final expenseCats = _byCategory('expense').entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final incomeCats = _byCategory('income').entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        FadeSlideIn(
          index: 0,
          child: Row(
            children: [
              Expanded(child: _tile('Income', taka(income), kEmerald)),
              const SizedBox(width: 10),
              Expanded(child: _tile('Expense', taka(expense), kRed)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FadeSlideIn(
          index: 1,
          child: Row(
            children: [
              Expanded(child: _tile('Net Savings', taka(income - expense), kCyan)),
              const SizedBox(width: 10),
              Expanded(
                  child: _tile('Savings Rate',
                      income > 0 ? '${((income - expense) / income * 100).toStringAsFixed(1)}%' : '—', kPurple)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FadeSlideIn(index: 2, child: _breakdown('Expense by Category', expenseCats, expense, kRed)),
        const SizedBox(height: 20),
        FadeSlideIn(index: 3, child: _breakdown('Income Sources', incomeCats, income, kEmerald)),
        const SizedBox(height: 16),
        Center(
          child: Text('PDF/Excel export is available in the web app.',
              style: TextStyle(fontSize: 11, color: kFg24)),
        ),
      ],
    );
  }

  Widget _tile(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: kFg38)),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _breakdown(String title, List<MapEntry<String, double>> cats, double total, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kFg)),
            const SizedBox(height: 12),
            if (cats.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No data this month', style: TextStyle(fontSize: 12, color: kFg38)),
              )
            else
              ...cats.map((e) {
                final pct = total > 0 ? e.value / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(e.key,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: kFg)),
                          ),
                          Text('${taka(e.value)}  (${(pct * 100).toStringAsFixed(0)}%)',
                              style: TextStyle(fontSize: 12, color: kFg54)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 5,
                          backgroundColor: kFg.withValues(alpha: 0.05),
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ---------- Income Statement ----------

  Widget _incomeStatement() {
    final incomeCats = _byCategory('income').entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final expenseCats = _byCategory('expense').entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final totalIncome = incomeCats.fold<double>(0, (s, e) => s + e.value);
    final totalExpense = expenseCats.fold<double>(0, (s, e) => s + e.value);
    final net = totalIncome - totalExpense;

    return _statementCard(
      title: 'Income Statement',
      subtitle: 'For the period: ${DateFormat('MMMM yyyy').format(_month)}',
      pdfKey: _incomeKey,
      fileName: 'Income_Statement_${DateFormat('MMM_yyyy').format(_month)}.pdf',
      children: [
        _section('Income (আয়)'),
        if (incomeCats.isEmpty) _line('No income recorded', '—', muted: true),
        ...incomeCats.map((e) => _line(e.key, taka(e.value))),
        _total('Total Income', taka(totalIncome), kEmerald),
        _section('Expenses (ব্যয়)'),
        if (expenseCats.isEmpty) _line('No expenses recorded', '—', muted: true),
        ...expenseCats.map((e) => _line(e.key, taka(e.value))),
        _total('Total Expenses', taka(totalExpense), kRed),
        _netBanner(net >= 0 ? 'Net Surplus (নীট উদ্বৃত্ত)' : 'Net Deficit (নীট ঘাটতি)', taka(net.abs()), net >= 0),
        if (totalIncome > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Savings rate: ${(net / totalIncome * 100).toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 11, color: kFg38, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  // ---------- Cash Flow ----------

  Widget _cashFlow() {
    final txs = _txs!;
    final cashIncome =
        txs.where((t) => t.type == 'income' && t.accountId != null).fold<double>(0, (s, t) => s + t.amount);
    final cashExpense =
        txs.where((t) => t.type == 'expense' && t.accountId != null).fold<double>(0, (s, t) => s + t.amount);
    final creditPurchases =
        txs.where((t) => t.type == 'expense' && t.accountId == null).fold<double>(0, (s, t) => s + t.amount);

    final periodSavings = _savings.where((s) => s.accountId != null && _inMonth(s.date));
    final savingsOut = periodSavings.where((s) => s.type == 'deposit').fold<double>(0, (s, e) => s + e.amount);
    final savingsIn = periodSavings.where((s) => s.type != 'deposit').fold<double>(0, (s, e) => s + e.amount);

    final givenIds = _liabilities.where((l) => l.isReceivable).map((l) => l.id).toSet();
    final shopIds = _liabilities.where((l) => l.isShop).map((l) => l.id).toSet();
    final periodRepay = _repayments.where((r) => r.accountId != null && _inMonth(r.date)).toList();
    final collectionsIn =
        periodRepay.where((r) => givenIds.contains(r.liabilityId)).fold<double>(0, (s, r) => s + r.amount);
    final shopPayOut =
        periodRepay.where((r) => shopIds.contains(r.liabilityId)).fold<double>(0, (s, r) => s + r.amount);
    final loanPayOut = periodRepay
        .where((r) => !givenIds.contains(r.liabilityId) && !shopIds.contains(r.liabilityId))
        .fold<double>(0, (s, r) => s + r.amount);

    final transferVol = _transfers.where((t) => _inMonth(t.date)).fold<double>(0, (s, t) => s + t.amount);
    final totalBalance = widget.state.accounts.fold<double>(0, (s, a) => s + a.currentBalance);

    final operating = cashIncome - cashExpense;
    final savingsNet = savingsIn - savingsOut;
    final financing = collectionsIn - shopPayOut - loanPayOut;
    final net = operating + savingsNet + financing;

    String signed(double v) => v < 0 ? '(${taka(v.abs())})' : taka(v);

    return _statementCard(
      title: 'Cash Flow Statement',
      subtitle: 'For the period: ${DateFormat('MMMM yyyy').format(_month)}',
      pdfKey: _cashKey,
      fileName: 'Cash_Flow_${DateFormat('MMM_yyyy').format(_month)}.pdf',
      children: [
        _section('A. Operating Activities (আয়-ব্যয়)'),
        _line('Income received in cash/bank', taka(cashIncome)),
        _line('Expenses paid in cash/bank', '(${taka(cashExpense)})'),
        _total('Net Cash from Operations', signed(operating), operating >= 0 ? kEmerald : kRed),
        _section('B. Savings Activities (সঞ্চয়)'),
        _line('Withdrawn from savings', taka(savingsIn)),
        _line('Deposited to savings', '(${taka(savingsOut)})'),
        _total('Net Cash from Savings', signed(savingsNet), savingsNet >= 0 ? kEmerald : kRed),
        _section('C. Financing Activities (ঋণ ও বাকি)'),
        _line('Collections from loans given', taka(collectionsIn)),
        _line('Shop due payments (দোকান বাকি)', '(${taka(shopPayOut)})'),
        _line('Loan repayments made', '(${taka(loanPayOut)})'),
        _total('Net Cash from Financing', signed(financing), financing >= 0 ? kEmerald : kRed),
        _netBanner(net >= 0 ? 'Net Increase in Cash (নগদ বৃদ্ধি)' : 'Net Decrease in Cash (নগদ হ্রাস)',
            signed(net), net >= 0),
        const SizedBox(height: 8),
        _line('Memo: purchases on credit (no cash impact) — ${taka(creditPurchases)}', '', muted: true),
        _line('Memo: internal transfers — ${taka(transferVol)} (no net effect)', '', muted: true),
        _total('Total Cash & Bank Balance (today)', taka(totalBalance), kCyan),
      ],
    );
  }

  // ---------- Trial Balance ----------

  Widget _trialBalance() {
    final dr = <(String, double, bool)>[]; // (name, value, isBalancing)
    final cr = <(String, double, bool)>[];

    for (final a in widget.state.accounts) {
      if (a.currentBalance >= 0) {
        dr.add(('${a.name} (account)', a.currentBalance, false));
      } else {
        cr.add(('${a.name} (overdrawn)', -a.currentBalance, false));
      }
    }
    final assetTotal = _assets.fold<double>(0, (s, a) => s + (a.currentValue > 0 ? a.currentValue : a.purchaseValue));
    if (assetTotal > 0) dr.add(('Fixed & other assets', assetTotal, false));
    final invTotal =
        _investments.fold<double>(0, (s, i) => s + (i.currentValue > 0 ? i.currentValue : i.investedAmount));
    if (invTotal > 0) dr.add(('Investments', invTotal, false));
    final savingsBal = _savings.fold<double>(0, (s, e) => s + (e.type == 'deposit' ? e.amount : -e.amount));
    if (savingsBal > 0) dr.add(('Savings balance', savingsBal, false));

    for (final l in _liabilities.where((l) => l.remainingBalance > 0)) {
      if (l.isReceivable) {
        dr.add(('${l.name} (receivable)', l.remainingBalance, false));
      } else {
        cr.add(('${l.name} (${l.isShop ? 'shop due' : l.type.replaceAll('_', ' ')})', l.remainingBalance, false));
      }
    }

    final expenseCats = _byCategory('expense').entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final incomeCats = _byCategory('income').entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final e in expenseCats) {
      dr.add(('${e.key} (expense)', e.value, false));
    }
    for (final e in incomeCats) {
      cr.add(('${e.key} (income)', e.value, false));
    }

    final drTotal = dr.fold<double>(0, (s, r) => s + r.$2);
    final crTotal = cr.fold<double>(0, (s, r) => s + r.$2);
    final diff = drTotal - crTotal;
    if (diff >= 0) {
      cr.add(("Owner's equity (balancing)", diff, true));
    } else {
      dr.add(('Accumulated deficit (balancing)', -diff, true));
    }
    final total = drTotal > crTotal ? drTotal : crTotal;

    Widget rows(List<(String, double, bool)> list) => Column(
          children: list
              .map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(r.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontStyle: r.$3 ? FontStyle.italic : null,
                                  color: r.$3 ? kPurple : kFg70)),
                        ),
                        Text(taka(r.$2), style: TextStyle(fontSize: 12.5, color: r.$3 ? kPurple : kFg)),
                      ],
                    ),
                  ))
              .toList(),
        );

    return _statementCard(
      title: 'Trial Balance',
      subtitle: 'As of today · Income & expenses for: ${DateFormat('MMMM yyyy').format(_month)}',
      pdfKey: _trialKey,
      fileName: 'Trial_Balance_${DateFormat('MMM_yyyy').format(_month)}.pdf',
      children: [
        _section('Debit (ডেবিট)'),
        rows(dr),
        _total('Total Debit', taka(total), kEmerald),
        _section('Credit (ক্রেডিট)'),
        rows(cr),
        _total('Total Credit', taka(total), kRed),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            "* Balance-sheet heads are as of today; income & expense heads cover the selected month. The balancing figure represents owner's equity.",
            style: TextStyle(fontSize: 10.5, color: kFg38),
          ),
        ),
      ],
    );
  }

  // ---------- Balance Sheet ----------

  Widget _balanceSheet() {
    final assetRows = <(String, double)>[];
    final liabRows = <(String, double)>[];

    for (final a in widget.state.accounts) {
      if (a.currentBalance >= 0) {
        assetRows.add(('${a.name} (cash & bank)', a.currentBalance));
      } else {
        liabRows.add(('${a.name} (overdrawn)', -a.currentBalance));
      }
    }
    final savingsBal = _savings.fold<double>(0, (s, e) => s + (e.type == 'deposit' ? e.amount : -e.amount));
    if (savingsBal > 0) assetRows.add(('Savings', savingsBal));
    final invTotal =
        _investments.fold<double>(0, (s, i) => s + (i.currentValue > 0 ? i.currentValue : i.investedAmount));
    if (invTotal > 0) assetRows.add(('Investments', invTotal));
    final fixedTotal =
        _assets.fold<double>(0, (s, a) => s + (a.currentValue > 0 ? a.currentValue : a.purchaseValue));
    if (fixedTotal > 0) assetRows.add(('Fixed & other assets', fixedTotal));

    for (final l in _liabilities.where((l) => l.remainingBalance > 0)) {
      if (l.isReceivable) {
        assetRows.add(('${l.name} (receivable)', l.remainingBalance));
      } else {
        liabRows.add(('${l.name} (${l.isShop ? 'shop due' : l.type.replaceAll('_', ' ')})', l.remainingBalance));
      }
    }

    final totalAssets = assetRows.fold<double>(0, (s, r) => s + r.$2);
    final totalLiab = liabRows.fold<double>(0, (s, r) => s + r.$2);
    final equity = totalAssets - totalLiab;

    return _statementCard(
      title: 'Balance Sheet',
      subtitle: 'As of today · ${DateFormat('d MMM yyyy').format(DateTime.now())}',
      pdfKey: _balanceKey,
      fileName: 'Balance_Sheet_${DateFormat('d_MMM_yyyy').format(DateTime.now())}.pdf',
      children: [
        _section('Assets (সম্পদ)'),
        ...assetRows.map((r) => _line(r.$1, taka(r.$2))),
        _total('Total Assets', taka(totalAssets), kEmerald),
        _section('Liabilities (দায়)'),
        if (liabRows.isEmpty) _line('No liabilities', '—', muted: true),
        ...liabRows.map((r) => _line(r.$1, taka(r.$2))),
        _total('Total Liabilities', taka(totalLiab), kRed),
        _netBanner("Owner's Equity / Net Worth (নীট সম্পদ)", taka(equity), equity >= 0),
        _total('Total Liabilities + Equity', taka(totalLiab + equity), kCyan),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text('* Total Liabilities + Equity always equals Total Assets.',
              style: TextStyle(fontSize: 10.5, color: kFg38)),
        ),
      ],
    );
  }

  // ---------- Bazar Report (shop-wise due + monthly purchases) ----------

  Widget _bazarReport() {
    final periodPurchases = _bazarPurchases.where((p) => _inMonth(p.date)).toList();
    final periodPayments = _bazarPayments.where((p) => _inMonth(p.date)).toList();
    final total = periodPurchases.fold<double>(0, (s, p) => s + p.amount);
    final cash = periodPurchases.where((p) => p.paymentType == 'cash').fold<double>(0, (s, p) => s + p.amount);
    final paid = periodPayments.fold<double>(0, (s, p) => s + p.amount);
    final totalDue = _shops.fold<double>(0, (s, x) => s + x.remainingBalance);

    final perShop = <String, double>{};
    for (final p in periodPurchases) {
      final key = p.paymentType == 'cash' ? 'Cash bazar (নগদ)' : (p.shopName.isEmpty ? 'Deleted shop' : p.shopName);
      perShop[key] = (perShop[key] ?? 0) + p.amount;
    }
    final perShopRows = perShop.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final shownPurchases = periodPurchases.take(30).toList();

    return _statementCard(
      title: 'Bazar Report (বাজার রিপোর্ট)',
      subtitle: 'Period: ${DateFormat('MMMM yyyy').format(_month)}',
      pdfKey: _bazarKey,
      fileName: 'Bazar_Report_${DateFormat('MMM_yyyy').format(_month)}.pdf',
      children: [
        _section('Summary'),
        _line('Total bazar this month', taka(total)),
        _line('Bought with cash (নগদ)', taka(cash), valueColor: kEmerald),
        _line('Bought on due (বাকিতে)', taka(total - cash), valueColor: kOrange),
        _line('Paid to shops this month', taka(paid)),
        _total('Outstanding shop due today (মোট বাকি)', taka(totalDue), kRed),
        _section('Shop-wise Due (দোকানভিত্তিক বাকি)'),
        if (_shops.isEmpty) _line('No shops yet', '—', muted: true),
        ..._shops.map((s) => _line(
              '${s.name}${s.phone.isNotEmpty ? ' • ${s.phone}' : ''}',
              taka(s.remainingBalance),
              valueColor: s.remainingBalance > 0 ? kRed : kEmerald,
            )),
        if (_shops.isNotEmpty) _total('Total Outstanding', taka(totalDue), kRed),
        _section('This Month by Source'),
        if (perShopRows.isEmpty) _line('No bazar purchases this month', '—', muted: true),
        ...perShopRows.map((e) => _line(e.key, taka(e.value))),
        if (perShopRows.isNotEmpty) _total('Total', taka(total), kCyan),
        _section('Purchases (${periodPurchases.length}${periodPurchases.length > 30 ? ', showing 30' : ''})'),
        if (shownPurchases.isEmpty) _line('No purchases this month', '—', muted: true),
        ...shownPurchases.map((p) => _line(
              '${DateFormat('d MMM').format(p.date)} • ${p.paymentType == 'cash' ? 'Cash' : 'Due'} • ${p.description.isEmpty ? (p.paymentType == 'cash' ? p.accountName : p.shopName) : p.description}',
              taka(p.amount),
            )),
      ],
    );
  }
}
