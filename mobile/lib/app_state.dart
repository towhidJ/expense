// `hide Category`: Flutter's foundation exports a `Category` annotation that
// clashes with our model class.
import 'package:flutter/foundation.dart' hide Category;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

final supabase = Supabase.instance.client;

/// Holds the signed-in user's workspaces, accounts and categories, and wraps
/// every money movement in the balance-safe Postgres RPCs (never plain
/// inserts/updates — see the web app's hooks).
class AppState extends ChangeNotifier {
  List<Entity> entities = [];
  Entity? currentEntity;
  List<Account> accounts = [];
  List<Category> categories = [];
  bool loading = true;

  String get _uid => supabase.auth.currentUser!.id;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    final rows = await supabase
        .from('entities')
        .select()
        .eq('user_id', _uid)
        .order('created_at', ascending: true);
    entities = rows.map<Entity>(Entity.fromMap).toList();
    if (entities.isNotEmpty &&
        (currentEntity == null || !entities.any((e) => e.id == currentEntity!.id))) {
      currentEntity = entities.first;
    }
    await _loadEntityData();
    loading = false;
    notifyListeners();
  }

  Future<void> _loadEntityData() async {
    if (currentEntity == null) {
      accounts = [];
      categories = [];
      return;
    }
    final results = await Future.wait([
      supabase.from('accounts').select().eq('user_id', _uid).eq('entity_id', currentEntity!.id).order('created_at'),
      supabase.from('categories').select().eq('user_id', _uid).eq('entity_id', currentEntity!.id).order('name'),
    ]);
    accounts = results[0].map<Account>(Account.fromMap).toList();
    categories = results[1].map<Category>(Category.fromMap).toList();
  }

  Future<void> switchEntity(Entity e) async {
    currentEntity = e;
    loading = true;
    notifyListeners();
    await _loadEntityData();
    loading = false;
    notifyListeners();
  }

  Future<void> refreshAccounts() async {
    if (currentEntity == null) return;
    final rows = await supabase
        .from('accounts')
        .select()
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('created_at');
    accounts = rows.map<Account>(Account.fromMap).toList();
    notifyListeners();
  }

  // ---- Transactions ----

  Future<List<Tx>> fetchTransactions({DateTime? start, DateTime? end, String? type}) async {
    if (currentEntity == null) return [];
    var q = supabase
        .from('transactions')
        .select('*, categories(name, icon, color), accounts(name)')
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id);
    if (type != null) q = q.eq('type', type);
    if (start != null) q = q.gte('date', _d(start));
    if (end != null) q = q.lte('date', _d(end));
    final rows = await q.order('date', ascending: false);
    return rows.map<Tx>(Tx.fromMap).toList();
  }

  Future<void> addTransaction({
    required String accountId,
    required String categoryId,
    required String type,
    required double amount,
    required DateTime date,
    String description = '',
  }) async {
    await supabase.rpc('process_transaction', params: {
      'p_user_id': _uid,
      'p_entity_id': currentEntity!.id,
      'p_account_id': accountId,
      'p_category_id': categoryId,
      'p_asset_id': null,
      'p_type': type,
      'p_amount': amount,
      'p_date': _d(date),
      'p_description': description,
    });
    await refreshAccounts();
  }

  Future<void> updateTransaction({
    required String id,
    required String accountId,
    required String categoryId,
    required String type,
    required double amount,
    required DateTime date,
    String description = '',
  }) async {
    await supabase.rpc('update_transaction_with_balance', params: {
      'p_user_id': _uid,
      'p_transaction_id': id,
      'p_account_id': accountId,
      'p_category_id': categoryId,
      'p_asset_id': null,
      'p_type': type,
      'p_amount': amount,
      'p_date': _d(date),
      'p_description': description,
    });
    await refreshAccounts();
  }

  Future<void> deleteTransaction(String id) async {
    await supabase.rpc('delete_transaction_with_balance', params: {
      'p_user_id': _uid,
      'p_transaction_id': id,
    });
    await refreshAccounts();
  }

  // ---- Transfers ----

  Future<List<Transfer>> fetchTransfers() async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('transfers')
        .select('*, from_account:from_account_id(name), to_account:to_account_id(name)')
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('date', ascending: false);
    return rows.map<Transfer>(Transfer.fromMap).toList();
  }

  Future<void> addTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required DateTime date,
    String notes = '',
  }) async {
    await supabase.rpc('process_transfer', params: {
      'p_user_id': _uid,
      'p_entity_id': currentEntity!.id,
      'p_from_account': fromAccountId,
      'p_to_account': toAccountId,
      'p_amount': amount,
      'p_date': _d(date),
      'p_notes': notes,
    });
    await refreshAccounts();
  }

  // ---- Accounts ----

  Future<void> addAccount({
    required String name,
    required String type,
    required double openingBalance,
    String? accountNumber,
  }) async {
    await supabase.from('accounts').insert({
      'user_id': _uid,
      'entity_id': currentEntity!.id,
      'name': name,
      'type': type,
      'opening_balance': openingBalance,
      'current_balance': openingBalance,
      'account_number': (accountNumber == null || accountNumber.isEmpty) ? null : accountNumber,
    });
    await refreshAccounts();
  }

  // ---- Categories ----

  Future<void> refreshCategories() async {
    if (currentEntity == null) return;
    final rows = await supabase
        .from('categories')
        .select()
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('name');
    categories = rows.map<Category>(Category.fromMap).toList();
    notifyListeners();
  }

  Future<void> addCategory({required String name, required String type, required String icon, required String color}) async {
    await supabase.from('categories').insert({
      'user_id': _uid,
      'entity_id': currentEntity!.id,
      'name': name,
      'type': type,
      'icon': icon,
      'color': color,
    });
    await refreshCategories();
  }

  Future<void> updateCategory(String id, {required String name, required String icon, required String color}) async {
    await supabase.from('categories').update({'name': name, 'icon': icon, 'color': color}).eq('id', id).eq('user_id', _uid);
    await refreshCategories();
  }

  Future<void> deleteCategory(String id) async {
    await supabase.from('categories').delete().eq('id', id).eq('user_id', _uid);
    await refreshCategories();
  }

  // ---- Budgets ----

  Future<List<Budget>> fetchBudgets(int month, int year) async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('budgets')
        .select('*, categories(name, icon, color)')
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .eq('month', month)
        .eq('year', year);
    return rows.map<Budget>(Budget.fromMap).toList();
  }

  Future<void> addBudget({required String categoryId, required double amount, required int month, required int year}) async {
    await supabase.from('budgets').insert({
      'user_id': _uid,
      'entity_id': currentEntity!.id,
      'category_id': categoryId,
      'amount': amount,
      'month': month,
      'year': year,
    });
  }

  Future<void> updateBudget(String id, double amount) async {
    await supabase.from('budgets').update({'amount': amount}).eq('id', id).eq('user_id', _uid);
  }

  Future<void> deleteBudget(String id) async {
    await supabase.from('budgets').delete().eq('id', id).eq('user_id', _uid);
  }

  // ---- Goals ----

  Future<List<Goal>> fetchGoals() async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('goals')
        .select()
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('created_at', ascending: false);
    return rows.map<Goal>(Goal.fromMap).toList();
  }

  Future<void> upsertGoal({String? id, required String title, required double targetAmount, required double savedAmount, DateTime? targetDate, String notes = ''}) async {
    final payload = {
      'title': title,
      'target_amount': targetAmount,
      'saved_amount': savedAmount,
      'target_date': targetDate == null ? null : _d(targetDate),
      'notes': notes,
    };
    if (id == null) {
      await supabase.from('goals').insert({...payload, 'user_id': _uid, 'entity_id': currentEntity!.id});
    } else {
      await supabase.from('goals').update(payload).eq('id', id).eq('user_id', _uid);
    }
  }

  Future<void> deleteGoal(String id) async {
    await supabase.from('goals').delete().eq('id', id).eq('user_id', _uid);
  }

  // ---- Savings ----

  Future<List<Saving>> fetchSavings() async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('savings')
        .select('*, accounts(name), saving_heads(name)')
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('date', ascending: false);
    return rows.map<Saving>(Saving.fromMap).toList();
  }

  Future<void> addSaving({String? accountId, required String type, required double amount, required DateTime date, String? purpose, String? notes, String savingType = 'general', String? institution, String? headId}) async {
    if (accountId != null) {
      // RPC inserts the entry and adjusts the account balance atomically.
      await supabase.rpc('process_saving', params: {
        'p_user_id': _uid,
        'p_entity_id': currentEntity!.id,
        'p_account_id': accountId,
        'p_type': type,
        'p_amount': amount,
        'p_date': _d(date),
        'p_purpose': purpose,
        'p_notes': notes,
        'p_saving_type': savingType,
        'p_institution': institution,
        'p_head_id': headId,
      });
      await refreshAccounts();
    } else {
      await supabase.from('savings').insert({
        'user_id': _uid,
        'entity_id': currentEntity!.id,
        'account_id': null,
        'type': type,
        'amount': amount,
        'date': _d(date),
        'purpose': purpose,
        'notes': notes,
        'saving_type': savingType,
        'institution': institution,
        'head_id': headId,
      });
    }
  }

  // ---- Saving heads ----

  Future<List<SavingHead>> fetchSavingHeads() async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('saving_heads')
        .select()
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('created_at', ascending: true);
    return rows.map<SavingHead>(SavingHead.fromMap).toList();
  }

  Future<void> upsertSavingHead({String? id, required String name, required String savingType, String? institution, String? accountNumber, String notes = ''}) async {
    final payload = {
      'name': name,
      'saving_type': savingType,
      'institution': (institution == null || institution.isEmpty) ? null : institution,
      'account_number': (accountNumber == null || accountNumber.isEmpty) ? null : accountNumber,
      'notes': notes,
    };
    if (id == null) {
      await supabase.from('saving_heads').insert({...payload, 'user_id': _uid, 'entity_id': currentEntity!.id});
    } else {
      await supabase.from('saving_heads').update(payload).eq('id', id).eq('user_id', _uid);
    }
  }

  Future<void> deleteSavingHead(String id) async {
    await supabase.from('saving_heads').delete().eq('id', id).eq('user_id', _uid);
  }

  // ---- Recurring savings ----

  Future<List<RecurringSaving>> fetchRecurringSavings() async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('recurring_savings')
        .select('*, accounts(name), saving_heads(name)')
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('next_run_date', ascending: true);
    return rows.map<RecurringSaving>(RecurringSaving.fromMap).toList();
  }

  Future<void> addRecurringSaving({required String title, required double amount, required String frequency, required DateTime nextRunDate, String? accountId, String savingType = 'general', String? institution, String? headId}) async {
    await supabase.from('recurring_savings').insert({
      'user_id': _uid,
      'entity_id': currentEntity!.id,
      'title': title,
      'amount': amount,
      'frequency': frequency,
      'next_run_date': _d(nextRunDate),
      'account_id': accountId,
      'saving_type': savingType,
      'institution': institution,
      'head_id': headId,
    });
  }

  Future<void> setRecurringSavingActive(String id, bool active) async {
    await supabase.from('recurring_savings').update({'is_active': active}).eq('id', id).eq('user_id', _uid);
  }

  Future<void> deleteRecurringSaving(String id) async {
    await supabase.from('recurring_savings').delete().eq('id', id).eq('user_id', _uid);
  }

  /// Processes all due recurring savings (catches up missed periods); returns
  /// the number of entries created.
  Future<int> runDueRecurringSavings() async {
    final count = await supabase.rpc('run_due_recurring_savings', params: {
      'p_user_id': _uid,
      'p_entity_id': currentEntity!.id,
    });
    await refreshAccounts();
    return (count as num?)?.toInt() ?? 0;
  }

  Future<void> deleteSaving(String id) async {
    // RPC restores the account balance before removing the row.
    await supabase.rpc('delete_saving_with_balance', params: {'p_user_id': _uid, 'p_saving_id': id});
    await refreshAccounts();
  }

  // ---- Family ----

  Future<List<FamilyMember>> fetchFamily() async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('family_members')
        .select()
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('created_at', ascending: false);
    return rows.map<FamilyMember>(FamilyMember.fromMap).toList();
  }

  Future<void> upsertFamilyMember({String? id, required String name, required String relationship, DateTime? dateOfBirth, String notes = ''}) async {
    final payload = {
      'name': name,
      'relationship': relationship,
      'date_of_birth': dateOfBirth == null ? null : _d(dateOfBirth),
      'notes': notes,
    };
    if (id == null) {
      await supabase.from('family_members').insert({...payload, 'user_id': _uid, 'entity_id': currentEntity!.id});
    } else {
      await supabase.from('family_members').update(payload).eq('id', id).eq('user_id', _uid);
    }
  }

  Future<void> deleteFamilyMember(String id) async {
    await supabase.from('family_members').delete().eq('id', id).eq('user_id', _uid);
  }

  // ---- Assets ----

  Future<List<Asset>> fetchAssets() async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('assets')
        .select()
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('purchase_date', ascending: false);
    return rows.map<Asset>(Asset.fromMap).toList();
  }

  Future<void> upsertAsset({String? id, required String name, required String type, required double purchaseValue, required double currentValue, double depreciation = 0, DateTime? purchaseDate, String notes = '', double? quantity, String? unit}) async {
    final payload = {
      'name': name,
      'type': type,
      'purchase_value': purchaseValue,
      'current_value': currentValue,
      'depreciation': depreciation,
      'value': currentValue, // kept in sync for older components (web parity)
      'purchase_date': purchaseDate == null ? null : _d(purchaseDate),
      'notes': notes,
      'quantity': quantity,
      'unit': (unit == null || unit.isEmpty) ? null : unit,
    };
    if (id == null) {
      await supabase.from('assets').insert({...payload, 'user_id': _uid, 'entity_id': currentEntity!.id});
    } else {
      await supabase.from('assets').update(payload).eq('id', id).eq('user_id', _uid);
    }
  }

  Future<void> deleteAsset(String id) async {
    // Unlink transactions first — the FK on transactions.asset_id blocks
    // deleting an asset that still has linked expenses.
    await supabase.from('transactions').update({'asset_id': null}).eq('asset_id', id).eq('user_id', _uid);
    await supabase.from('assets').delete().eq('id', id).eq('user_id', _uid);
  }

  // ---- Investments ----

  Future<List<Investment>> fetchInvestments() async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('investments')
        .select()
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('created_at', ascending: false);
    return rows.map<Investment>(Investment.fromMap).toList();
  }

  Future<void> upsertInvestment({String? id, required String name, required String type, required double investedAmount, required double currentValue}) async {
    final profitLoss = currentValue - investedAmount;
    final roi = investedAmount > 0 ? double.parse((profitLoss / investedAmount * 100).toStringAsFixed(2)) : 0.0;
    final payload = {
      'name': name,
      'type': type,
      'invested_amount': investedAmount,
      'current_value': currentValue,
      'profit_loss': profitLoss,
      'roi': roi,
    };
    if (id == null) {
      await supabase.from('investments').insert({...payload, 'user_id': _uid, 'entity_id': currentEntity!.id});
    } else {
      await supabase.from('investments').update(payload).eq('id', id).eq('user_id', _uid);
    }
  }

  Future<void> deleteInvestment(String id) async {
    await supabase.from('investments').delete().eq('id', id).eq('user_id', _uid);
  }

  // ---- Recurring ----

  Future<List<Recurring>> fetchRecurring() async {
    if (currentEntity == null) return [];
    final rows = await supabase
        .from('recurring_transactions')
        .select('*, categories(name, icon), accounts(name)')
        .eq('user_id', _uid)
        .eq('entity_id', currentEntity!.id)
        .order('next_run_date', ascending: true);
    return rows.map<Recurring>(Recurring.fromMap).toList();
  }

  Future<void> upsertRecurring({String? id, required String title, required String type, required String categoryId, required String accountId, required double amount, required String frequency, required DateTime nextRunDate, bool isActive = true}) async {
    final payload = {
      'title': title,
      'type': type,
      'category_id': categoryId,
      'account_id': accountId,
      'amount': amount,
      'frequency': frequency,
      'next_run_date': _d(nextRunDate),
      'is_active': isActive,
    };
    if (id == null) {
      await supabase.from('recurring_transactions').insert({...payload, 'user_id': _uid, 'entity_id': currentEntity!.id});
    } else {
      await supabase.from('recurring_transactions').update(payload).eq('id', id).eq('user_id', _uid);
    }
  }

  Future<void> setRecurringActive(String id, bool active) async {
    await supabase.from('recurring_transactions').update({'is_active': active}).eq('id', id).eq('user_id', _uid);
  }

  Future<void> deleteRecurring(String id) async {
    await supabase.from('recurring_transactions').delete().eq('id', id).eq('user_id', _uid);
  }

  // ---- Liabilities ----

  Future<(List<Liability>, List<Repayment>)> fetchLiabilities() async {
    if (currentEntity == null) return (<Liability>[], <Repayment>[]);
    final results = await Future.wait([
      supabase.from('liabilities').select().eq('user_id', _uid).eq('entity_id', currentEntity!.id).order('created_at', ascending: false),
      supabase.from('loan_repayments').select('*, accounts(name)').eq('user_id', _uid).eq('entity_id', currentEntity!.id).order('date', ascending: false),
    ]);
    return (
      results[0].map<Liability>(Liability.fromMap).toList(),
      results[1].map<Repayment>(Repayment.fromMap).toList(),
    );
  }

  Future<void> addLiability({required String name, required String type, required double principal, double interestRate = 0, DateTime? dueDate, String notes = '', String? accountId}) async {
    if (accountId != null) {
      // Money actually arrived in an account — the RPC records the loan and
      // credits the account atomically.
      await supabase.rpc('process_new_loan', params: {
        'p_user_id': _uid,
        'p_entity_id': currentEntity!.id,
        'p_name': name,
        'p_type': type,
        'p_principal': principal,
        'p_interest_rate': interestRate,
        'p_due_date': dueDate == null ? null : _d(dueDate),
        'p_notes': notes,
        'p_account_id': accountId,
      });
      await refreshAccounts();
    } else {
      await supabase.from('liabilities').insert({
        'user_id': _uid,
        'entity_id': currentEntity!.id,
        'name': name,
        'type': type,
        'principal': principal,
        'interest_rate': interestRate,
        'due_date': dueDate == null ? null : _d(dueDate),
        'remaining_balance': principal,
        'notes': notes,
      });
    }
  }

  Future<void> repayLiability({required String liabilityId, required String accountId, required double amount, required DateTime date, String notes = ''}) async {
    await supabase.rpc('process_loan_repayment', params: {
      'p_user_id': _uid,
      'p_entity_id': currentEntity!.id,
      'p_liability_id': liabilityId,
      'p_account_id': accountId,
      'p_amount': amount,
      'p_date': _d(date),
      'p_notes': notes,
    });
    await refreshAccounts();
  }

  Future<void> deleteLiability(String id) async {
    await supabase.from('liabilities').delete().eq('id', id).eq('user_id', _uid);
  }

  // ---- Bazar (shop credit ledger, migration v14) ----

  Future<(List<Liability>, List<BazarPurchase>, List<Repayment>)> fetchBazar() async {
    if (currentEntity == null) return (<Liability>[], <BazarPurchase>[], <Repayment>[]);
    final results = await Future.wait([
      supabase
          .from('liabilities')
          .select()
          .eq('user_id', _uid)
          .eq('entity_id', currentEntity!.id)
          .eq('type', 'shop_due')
          .order('created_at', ascending: true),
      supabase
          .from('bazar_purchases')
          .select('*, accounts(name), liabilities(name)')
          .eq('user_id', _uid)
          .eq('entity_id', currentEntity!.id)
          .order('date', ascending: false)
          .order('created_at', ascending: false),
    ]);
    final shops = results[0].map<Liability>(Liability.fromMap).toList();
    final purchases = results[1].map<BazarPurchase>(BazarPurchase.fromMap).toList();
    List<Repayment> payments = [];
    if (shops.isNotEmpty) {
      final payRows = await supabase
          .from('loan_repayments')
          .select('*, accounts(name)')
          .eq('user_id', _uid)
          .eq('entity_id', currentEntity!.id)
          .inFilter('liability_id', shops.map((s) => s.id).toList())
          .order('date', ascending: false);
      payments = payRows.map<Repayment>(Repayment.fromMap).toList();
    }
    return (shops, purchases, payments);
  }

  Future<void> addShop({required String name, String phone = '', String notes = ''}) async {
    await supabase.from('liabilities').insert({
      'user_id': _uid,
      'entity_id': currentEntity!.id,
      'name': name,
      'type': 'shop_due',
      'principal': 0,
      'remaining_balance': 0,
      'phone': phone.isEmpty ? null : phone,
      'notes': notes,
    });
  }

  Future<void> updateShop({required String id, required String name, String phone = '', String notes = ''}) async {
    await supabase.from('liabilities').update({
      'name': name,
      'phone': phone.isEmpty ? null : phone,
      'notes': notes,
    }).eq('id', id).eq('user_id', _uid);
  }

  /// Returns the created expense transaction's id (for attaching invoices).
  Future<String?> addBazarPurchase({
    required String categoryId,
    required double amount,
    required DateTime date,
    required String paymentType, // cash | due
    String? accountId,
    String? shopId,
    String description = '',
    List<PurchaseItem> items = const [],
  }) async {
    final purchaseId = await supabase.rpc('process_bazar_purchase', params: {
      'p_user_id': _uid,
      'p_entity_id': currentEntity!.id,
      'p_category_id': categoryId,
      'p_amount': amount,
      'p_date': _d(date),
      'p_description': description.isEmpty ? null : description,
      'p_payment_type': paymentType,
      'p_account_id': paymentType == 'cash' ? accountId : null,
      'p_liability_id': paymentType == 'due' ? shopId : null,
      'p_items': items.map((i) => i.toMap()).toList(),
    });
    await refreshAccounts();
    final row = await supabase
        .from('bazar_purchases')
        .select('transaction_id')
        .eq('id', purchaseId as String)
        .maybeSingle();
    return row?['transaction_id'] as String?;
  }

  /// Edit a bazar purchase: the balance-safe RPC reverses/reapplies account
  /// and shop-due effects and syncs the bazar_purchases row; items are synced
  /// separately (the RPC predates them). Payment type cannot change.
  Future<void> updateBazarPurchase({
    required BazarPurchase purchase,
    required double amount,
    required DateTime date,
    String description = '',
    List<PurchaseItem> items = const [],
    String? accountId, // cash purchases may move to another account
  }) async {
    if (purchase.transactionId == null) {
      throw Exception('This purchase has no linked transaction');
    }
    final txn = await supabase
        .from('transactions')
        .select('category_id, asset_id, account_id')
        .eq('id', purchase.transactionId!)
        .single();
    await supabase.rpc('update_transaction_with_balance', params: {
      'p_user_id': _uid,
      'p_transaction_id': purchase.transactionId,
      'p_account_id': purchase.paymentType == 'cash'
          ? (accountId ?? txn['account_id'])
          : null,
      'p_category_id': txn['category_id'],
      'p_asset_id': txn['asset_id'],
      'p_type': 'expense',
      'p_amount': amount,
      'p_date': _d(date),
      'p_description': description.isEmpty ? null : description,
    });
    final patch = <String, dynamic>{
      'items': items.map((i) => i.toMap()).toList(),
    };
    if (purchase.paymentType == 'cash' && accountId != null) {
      patch['account_id'] = accountId;
    }
    await supabase.from('bazar_purchases').update(patch).eq('id', purchase.id);
    await refreshAccounts();
  }

  // ---- Attachments (invoices/receipts on transactions) ----

  /// Upload a file to the documents bucket and record it in the attachments
  /// table, linked to a transaction — same flow as the web's useAttachments.
  Future<void> uploadTransactionAttachment({
    required String transactionId,
    required List<int> bytes,
    required String filename,
    String contentType = 'image/jpeg',
  }) async {
    final safe = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '$_uid/${DateTime.now().millisecondsSinceEpoch}_$safe';
    await supabase.storage.from('documents').uploadBinary(
        path, Uint8List.fromList(bytes),
        fileOptions: FileOptions(cacheControl: '3600', contentType: contentType));
    final url = supabase.storage.from('documents').getPublicUrl(path);
    await supabase.from('attachments').insert({
      'user_id': _uid,
      'entity_id': currentEntity?.id,
      'transaction_id': transactionId,
      'file_name': filename,
      'file_url': url,
      'storage_path': path,
      'file_size': bytes.length,
      'content_type': contentType,
    });
  }

  Future<List<AttachmentInfo>> fetchTransactionAttachments(String transactionId) async {
    final rows = await supabase
        .from('attachments')
        .select()
        .eq('user_id', _uid)
        .eq('transaction_id', transactionId)
        .order('created_at', ascending: false);
    return rows.map<AttachmentInfo>(AttachmentInfo.fromMap).toList();
  }

  Future<void> deleteBazarPurchase(String id) async {
    await supabase.rpc('delete_bazar_purchase', params: {
      'p_user_id': _uid,
      'p_purchase_id': id,
    });
    await refreshAccounts();
  }

  Future<void> updateAccount({required String id, required String name, required String type, String? accountNumber, required double currentBalance}) async {
    await supabase.from('accounts').update({
      'name': name,
      'type': type,
      'account_number': (accountNumber == null || accountNumber.isEmpty) ? null : accountNumber,
      'current_balance': currentBalance,
    }).eq('id', id).eq('user_id', _uid);
    await refreshAccounts();
  }

  Future<void> deleteAccount(String id) async {
    await supabase.from('accounts').delete().eq('id', id).eq('user_id', _uid);
    await refreshAccounts();
  }

  // ---- Meals (mess) ----
  // Shared across users and NOT entity-scoped: the meal group itself is the
  // scope. Membership rules are enforced by RLS + RPCs (migration v16).

  String get uid => _uid;

  Future<List<MealGroupMember>> fetchMyMealMemberships() async {
    final rows = await supabase
        .from('meal_group_members')
        .select('*, meal_groups(*)')
        .eq('user_id', _uid)
        .inFilter('status', ['pending', 'approved'])
        .order('created_at', ascending: true);
    return rows.map<MealGroupMember>(MealGroupMember.fromMap).toList();
  }

  Future<String> createMealGroup(String name, {String? displayName}) async {
    final id = await supabase.rpc('create_meal_group', params: {
      'p_name': name,
      'p_display_name': displayName,
    });
    return id as String;
  }

  Future<String> joinMealGroup(String code, {String? displayName}) async {
    final id = await supabase.rpc('join_meal_group', params: {
      'p_code': code,
      'p_display_name': displayName,
    });
    return id as String;
  }

  Future<void> respondMealJoinRequest(String memberId, bool approve) async {
    await supabase.rpc('respond_meal_join_request', params: {
      'p_member_id': memberId,
      'p_approve': approve,
    });
  }

  Future<void> removeMealMember(String memberId) async {
    await supabase.rpc('remove_meal_member', params: {'p_member_id': memberId});
  }

  Future<void> leaveMealGroup(String groupId) async {
    await supabase.rpc('leave_meal_group', params: {'p_group_id': groupId});
  }

  Future<void> setMealMemberRole(String memberId, String role) async {
    await supabase.rpc('set_meal_member_role', params: {
      'p_member_id': memberId,
      'p_role': role,
    });
  }

  Future<String> regenerateMealInviteCode(String groupId) async {
    final code = await supabase
        .rpc('regenerate_meal_invite_code', params: {'p_group_id': groupId});
    return code as String;
  }

  Future<MealGroup?> fetchMealGroup(String groupId) async {
    final row = await supabase
        .from('meal_groups')
        .select()
        .eq('id', groupId)
        .maybeSingle();
    return row == null ? null : MealGroup.fromMap(row);
  }

  Future<void> updateMealGroupSettings(
    String groupId, {
    required String name,
    required bool hasMaid,
    required double breakfastValue,
    required double lunchValue,
    required double dinnerValue,
    String? cutoffTime, // 'HH:MM' or null = no request deadline
  }) async {
    await supabase.from('meal_groups').update({
      'name': name,
      'has_maid': hasMaid,
      'breakfast_value': breakfastValue,
      'lunch_value': lunchValue,
      'dinner_value': dinnerValue,
      'cutoff_time': (cutoffTime == null || cutoffTime.isEmpty) ? null : cutoffTime,
    }).eq('id', groupId);
  }

  Future<List<MealGroupMember>> fetchMealMembers(String groupId) async {
    final rows = await supabase
        .from('meal_group_members')
        .select()
        .eq('group_id', groupId)
        .order('created_at', ascending: true);
    return rows.map<MealGroupMember>(MealGroupMember.fromMap).toList();
  }

  Future<List<MealEntry>> fetchMealEntries(
      String groupId, DateTime start, DateTime end) async {
    final rows = await supabase
        .from('meal_entries')
        .select()
        .eq('group_id', groupId)
        .gte('date', _d(start))
        .lt('date', _d(end));
    return rows.map<MealEntry>(MealEntry.fromMap).toList();
  }

  Future<void> upsertMealEntry({
    required String groupId,
    required String memberId,
    required DateTime date,
    double breakfast = 0,
    double lunch = 0,
    double dinner = 0,
    double guestBreakfast = 0,
    double guestLunch = 0,
    double guestDinner = 0,
  }) async {
    await supabase.rpc('upsert_meal_entry', params: {
      'p_group_id': groupId,
      'p_member_id': memberId,
      'p_date': _d(date),
      'p_breakfast': breakfast,
      'p_lunch': lunch,
      'p_dinner': dinner,
      'p_guest_breakfast': guestBreakfast,
      'p_guest_lunch': guestLunch,
      'p_guest_dinner': guestDinner,
    });
  }

  Future<List<MealDeposit>> fetchMealDeposits(
      String groupId, DateTime start, DateTime end) async {
    final rows = await supabase
        .from('meal_deposits')
        .select()
        .eq('group_id', groupId)
        .gte('date', _d(start))
        .lt('date', _d(end))
        .order('date', ascending: false);
    return rows.map<MealDeposit>(MealDeposit.fromMap).toList();
  }

  Future<void> addMealDeposit({
    required String groupId,
    required String memberId,
    required double amount,
    required DateTime date,
    String note = '',
  }) async {
    await supabase.from('meal_deposits').insert({
      'group_id': groupId,
      'member_id': memberId,
      'amount': amount,
      'date': _d(date),
      'note': note.isEmpty ? null : note,
      'added_by': _uid,
    });
  }

  Future<void> updateMealDeposit(
    String id, {
    required String memberId,
    required double amount,
    required DateTime date,
    String note = '',
  }) async {
    await supabase.from('meal_deposits').update({
      'member_id': memberId,
      'amount': amount,
      'date': _d(date),
      'note': note.isEmpty ? null : note,
    }).eq('id', id);
  }

  Future<void> deleteMealDeposit(String id) async {
    await supabase.from('meal_deposits').delete().eq('id', id);
  }

  Future<List<MealExpense>> fetchMealExpenses(
      String groupId, DateTime start, DateTime end) async {
    final rows = await supabase
        .from('meal_expenses')
        .select()
        .eq('group_id', groupId)
        .gte('date', _d(start))
        .lt('date', _d(end))
        .order('date', ascending: false);
    return rows.map<MealExpense>(MealExpense.fromMap).toList();
  }

  Future<void> addMealExpense({
    required String groupId,
    required String expenseType,
    required double amount,
    required DateTime date,
    String note = '',
    String? spentBy,
    List<PurchaseItem> items = const [],
    String? attachmentUrl,
    String? attachmentPath,
  }) async {
    await supabase.from('meal_expenses').insert({
      'group_id': groupId,
      'expense_type': expenseType,
      'amount': amount,
      'date': _d(date),
      'note': note.isEmpty ? null : note,
      'spent_by': spentBy,
      'added_by': _uid,
      'items': items.map((i) => i.toMap()).toList(),
      'attachment_url': attachmentUrl,
      'attachment_path': attachmentPath,
    });
  }

  Future<void> updateMealExpense(
    String id, {
    required String expenseType,
    required double amount,
    required DateTime date,
    String note = '',
    String? spentBy,
    List<PurchaseItem> items = const [],
    String? attachmentUrl,
    String? attachmentPath,
    bool keepAttachment = true,
  }) async {
    final patch = <String, dynamic>{
      'expense_type': expenseType,
      'amount': amount,
      'date': _d(date),
      'note': note.isEmpty ? null : note,
      'spent_by': spentBy,
      'items': items.map((i) => i.toMap()).toList(),
    };
    if (!keepAttachment || attachmentUrl != null) {
      patch['attachment_url'] = attachmentUrl;
      patch['attachment_path'] = attachmentPath;
    }
    await supabase.from('meal_expenses').update(patch).eq('id', id);
  }

  /// Upload a receipt photo to the public documents bucket under the group's
  /// folder; returns (url, path) to store on the expense row.
  Future<(String, String)> uploadMealReceipt(
      String groupId, List<int> bytes, String filename) async {
    final safe = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = 'meal/$groupId/${DateTime.now().millisecondsSinceEpoch}_$safe';
    await supabase.storage.from('documents').uploadBinary(
        path, Uint8List.fromList(bytes),
        fileOptions: const FileOptions(cacheControl: '3600'));
    final url = supabase.storage.from('documents').getPublicUrl(path);
    return (url, path);
  }

  // Advances (জামানত) — lifetime, manager-only writes (RLS enforced)

  Future<List<MealAdvance>> fetchMealAdvances(String groupId) async {
    final rows = await supabase
        .from('meal_advances')
        .select()
        .eq('group_id', groupId)
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return rows.map<MealAdvance>(MealAdvance.fromMap).toList();
  }

  Future<void> addMealAdvance({
    required String groupId,
    required String memberId,
    required String type, // taken | returned
    required double amount,
    required DateTime date,
    String note = '',
  }) async {
    await supabase.from('meal_advances').insert({
      'group_id': groupId,
      'member_id': memberId,
      'type': type,
      'amount': amount,
      'date': _d(date),
      'note': note.isEmpty ? null : note,
      'added_by': _uid,
    });
  }

  /// Pay a member's dues from their advance: advance down, deposit up.
  Future<void> adjustMealAdvance({
    required String memberId,
    required double amount,
    required DateTime date,
    String note = '',
  }) async {
    await supabase.rpc('adjust_meal_advance', params: {
      'p_member_id': memberId,
      'p_amount': amount,
      'p_date': _d(date),
      'p_note': note.isEmpty ? null : note,
    });
  }

  Future<void> deleteMealAdvance(String id) async {
    await supabase.from('meal_advances').delete().eq('id', id);
  }

  // Meal holidays / feast days

  Future<List<MealHoliday>> fetchMealHolidays(
      String groupId, DateTime start, DateTime end) async {
    final rows = await supabase
        .from('meal_holidays')
        .select()
        .eq('group_id', groupId)
        .gte('date', _d(start))
        .lt('date', _d(end))
        .order('date', ascending: true);
    return rows.map<MealHoliday>(MealHoliday.fromMap).toList();
  }

  Future<void> upsertMealHoliday({
    required String groupId,
    required DateTime date,
    required String title,
    String menu = '',
  }) async {
    await supabase.from('meal_holidays').upsert({
      'group_id': groupId,
      'date': _d(date),
      'title': title.isEmpty ? 'Meal Holiday' : title,
      'menu': menu.isEmpty ? null : menu,
    }, onConflict: 'group_id,date');
  }

  Future<void> deleteMealHoliday(String id) async {
    await supabase.from('meal_holidays').delete().eq('id', id);
  }

  Future<void> deleteMealExpense(String id) async {
    await supabase.from('meal_expenses').delete().eq('id', id);
  }

  Future<List<MealDutyType>> fetchMealDutyTypes(String groupId) async {
    final rows = await supabase
        .from('meal_duty_types')
        .select()
        .eq('group_id', groupId)
        .order('sort_order', ascending: true);
    return rows.map<MealDutyType>(MealDutyType.fromMap).toList();
  }

  Future<void> addMealDutyType(String groupId, String name, int sortOrder) async {
    await supabase.from('meal_duty_types').insert({
      'group_id': groupId,
      'name': name,
      'is_builtin': false,
      'sort_order': sortOrder,
    });
  }

  Future<void> updateMealDutyType(String id, {bool? isActive, String? name}) async {
    final patch = <String, dynamic>{};
    if (isActive != null) patch['is_active'] = isActive;
    if (name != null) patch['name'] = name;
    if (patch.isEmpty) return;
    await supabase.from('meal_duty_types').update(patch).eq('id', id);
  }

  Future<void> deleteMealDutyType(String id) async {
    await supabase.from('meal_duty_types').delete().eq('id', id);
  }

  Future<List<MealDutyAssignment>> fetchMealDutyAssignments(
      String groupId, DateTime start, DateTime end) async {
    final rows = await supabase
        .from('meal_duty_assignments')
        .select()
        .eq('group_id', groupId)
        .gte('date', _d(start))
        .lt('date', _d(end));
    return rows.map<MealDutyAssignment>(MealDutyAssignment.fromMap).toList();
  }

  Future<void> assignMealDuty({
    required String groupId,
    required String dutyTypeId,
    required String memberId,
    required DateTime date,
  }) async {
    await supabase.from('meal_duty_assignments').insert({
      'group_id': groupId,
      'duty_type_id': dutyTypeId,
      'member_id': memberId,
      'date': _d(date),
    });
  }

  Future<void> removeMealDutyAssignment(String id) async {
    await supabase.from('meal_duty_assignments').delete().eq('id', id);
  }

  Future<MealMonthSummary> fetchMealMonthSummary(
      String groupId, int year, int month) async {
    final data = await supabase.rpc('get_meal_month_summary', params: {
      'p_group_id': groupId,
      'p_year': year,
      'p_month': month,
    });
    return MealMonthSummary.fromMap(Map<String, dynamic>.from(data));
  }

  // ---- Meals v18: month close + carry-forward ----

  Future<void> closeMealMonth(String groupId, int year, int month) async {
    await supabase.rpc('close_meal_month', params: {
      'p_group_id': groupId,
      'p_year': year,
      'p_month': month,
    });
  }

  Future<void> reopenMealMonth(String groupId, int year, int month) async {
    await supabase.rpc('reopen_meal_month', params: {
      'p_group_id': groupId,
      'p_year': year,
      'p_month': month,
    });
  }

  // ---- Meals v18: meal off / guest requests ----

  Future<List<MealRequest>> fetchMealRequests(
      String groupId, DateTime start, DateTime end) async {
    final rows = await supabase
        .from('meal_requests')
        .select()
        .eq('group_id', groupId)
        .gte('date', _d(start))
        .lt('date', _d(end))
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return rows.map<MealRequest>(MealRequest.fromMap).toList();
  }

  Future<void> submitMealRequest({
    required String groupId,
    required DateTime date,
    required String type, // off | guest
    double breakfast = 0,
    double lunch = 0,
    double dinner = 0,
    String? note,
  }) async {
    await supabase.rpc('submit_meal_request', params: {
      'p_group_id': groupId,
      'p_date': _d(date),
      'p_type': type,
      'p_breakfast': breakfast,
      'p_lunch': lunch,
      'p_dinner': dinner,
      'p_note': note,
    });
  }

  Future<void> cancelMealRequest(String requestId) async {
    await supabase
        .rpc('cancel_meal_request', params: {'p_request_id': requestId});
  }

  /// Approving writes the meal entry (off → slots 0, guest → counts added).
  Future<void> respondMealRequest(String requestId, bool approve) async {
    await supabase.rpc('respond_meal_request', params: {
      'p_request_id': requestId,
      'p_approve': approve,
    });
  }

  // ---- Meals v18: notice board ----

  Future<List<MealNotice>> fetchMealNotices(String groupId) async {
    final rows = await supabase
        .from('meal_notices')
        .select()
        .eq('group_id', groupId)
        .order('pinned', ascending: false)
        .order('created_at', ascending: false);
    return rows.map<MealNotice>(MealNotice.fromMap).toList();
  }

  Future<void> addMealNotice(String groupId,
      {required String title, String? body, bool pinned = false}) async {
    await supabase.from('meal_notices').insert({
      'group_id': groupId,
      'title': title,
      'body': (body == null || body.isEmpty) ? null : body,
      'pinned': pinned,
      'created_by': _uid,
    });
  }

  Future<void> updateMealNotice(String id,
      {required String title, String? body, required bool pinned}) async {
    await supabase.from('meal_notices').update({
      'title': title,
      'body': (body == null || body.isEmpty) ? null : body,
      'pinned': pinned,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteMealNotice(String id) async {
    await supabase.from('meal_notices').delete().eq('id', id);
  }

  // ---- Meals v19: shopping list ----

  /// Active list only — rows already converted into an expense are hidden.
  Future<List<MealShoppingItem>> fetchMealShoppingItems(String groupId) async {
    final rows = await supabase
        .from('meal_shopping_items')
        .select()
        .eq('group_id', groupId)
        .isFilter('expense_id', null)
        .order('created_at', ascending: true);
    return rows.map<MealShoppingItem>(MealShoppingItem.fromMap).toList();
  }

  Future<void> addMealShoppingItem(String groupId,
      {required String name, String? qty}) async {
    await supabase.from('meal_shopping_items').insert({
      'group_id': groupId,
      'name': name,
      'qty': (qty == null || qty.isEmpty) ? null : qty,
      'added_by': _uid,
    });
  }

  Future<void> toggleMealShoppingItem(String id, bool bought) async {
    await supabase.from('meal_shopping_items').update({
      'is_bought': bought,
      'bought_by': bought ? _uid : null,
      'bought_at': bought ? DateTime.now().toIso8601String() : null,
    }).eq('id', id);
  }

  Future<void> deleteMealShoppingItem(String id) async {
    await supabase.from('meal_shopping_items').delete().eq('id', id);
  }

  /// Turn ticked-off items into one itemized bazar expense, then archive them
  /// from the active list by stamping expense_id.
  Future<void> convertMealShoppingToExpense({
    required String groupId,
    required List<MealShoppingItem> items,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    final expense = await supabase
        .from('meal_expenses')
        .insert({
          'group_id': groupId,
          'expense_type': 'bazar',
          'amount': amount,
          'date': _d(date),
          'note': (note == null || note.isEmpty) ? 'From shopping list' : note,
          'added_by': _uid,
          'items': items
              .map((it) => {
                    'name': it.qty.isEmpty ? it.name : '${it.name} (${it.qty})',
                    'amount': null,
                  })
              .toList(),
        })
        .select('id')
        .single();
    await supabase
        .from('meal_shopping_items')
        .update({'expense_id': expense['id']}).inFilter(
            'id', items.map((it) => it.id).toList());
  }

  // ---- Meals v19: shared bills (rent/wifi/gas splitter) ----

  Future<List<MealSharedExpense>> fetchMealSharedExpenses(
      String groupId, DateTime start, DateTime end) async {
    final rows = await supabase
        .from('meal_shared_expenses')
        .select('*, meal_shared_expense_shares(*)')
        .eq('group_id', groupId)
        .gte('date', _d(start))
        .lt('date', _d(end))
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return rows.map<MealSharedExpense>(MealSharedExpense.fromMap).toList();
  }

  /// shares: [{'member_id': ..., 'amount': ...}] — must sum to [amount] (±1).
  Future<void> createMealSharedExpense({
    required String groupId,
    required String title,
    required double amount,
    required DateTime date,
    required String splitType, // equal | custom
    required List<Map<String, dynamic>> shares,
    String? note,
  }) async {
    await supabase.rpc('create_shared_expense', params: {
      'p_group_id': groupId,
      'p_title': title,
      'p_amount': amount,
      'p_date': _d(date),
      'p_split_type': splitType,
      'p_shares': shares,
      'p_note': note,
    });
  }

  Future<void> toggleMealSharePaid(String shareId, bool paid) async {
    await supabase.from('meal_shared_expense_shares').update({
      'paid': paid,
      'paid_at': paid ? DateTime.now().toIso8601String() : null,
    }).eq('id', shareId);
  }

  Future<void> deleteMealSharedExpense(String id) async {
    await supabase.from('meal_shared_expenses').delete().eq('id', id);
  }

  // ---- Meals v19: in-app notifications ----

  Future<List<MealNotification>> fetchMealNotifications(String groupId) async {
    final rows = await supabase
        .from('meal_notifications')
        .select()
        .eq('group_id', groupId)
        .eq('user_id', _uid)
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map<MealNotification>(MealNotification.fromMap).toList();
  }

  Future<void> markMealNotificationsRead(String groupId) async {
    await supabase
        .from('meal_notifications')
        .update({'is_read': true})
        .eq('group_id', groupId)
        .eq('user_id', _uid)
        .eq('is_read', false);
  }

  Future<void> deleteMealNotification(String id) async {
    await supabase.from('meal_notifications').delete().eq('id', id);
  }

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
