class Entity {
  Entity.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'] ?? '',
        type = m['type'] ?? 'personal';
  final String id;
  final String name;
  final String type;
}

class Account {
  Account.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'] ?? '',
        type = m['type'] ?? 'cash',
        currentBalance = (m['current_balance'] as num?)?.toDouble() ?? 0,
        currency = m['currency'] ?? '৳',
        accountNumber = m['account_number'] ?? '';
  final String id;
  final String name;
  final String type;
  final double currentBalance;
  final String currency;
  final String accountNumber; // bank a/c no, bKash number, etc.
}

class SavingHead {
  SavingHead.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'] ?? '',
        savingType = m['saving_type'] ?? 'general',
        institution = m['institution'] ?? '',
        accountNumber = m['account_number'] ?? '',
        notes = m['notes'] ?? '';
  final String id;
  final String name;
  final String savingType;
  final String institution;
  final String accountNumber;
  final String notes;
}

class Category {
  Category.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'] ?? '',
        type = m['type'] ?? 'expense',
        icon = m['icon'] ?? '💰',
        color = m['color'] ?? '#6366f1';
  final String id;
  final String name;
  final String type; // income | expense
  final String icon;
  final String color;
}

class Tx {
  Tx.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        type = m['type'] ?? 'expense',
        categoryId = m['category_id'],
        accountId = m['account_id'],
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        description = m['description'] ?? '',
        date = DateTime.parse(m['date']),
        categoryName = m['categories']?['name'] ?? '',
        categoryIcon = m['categories']?['icon'] ?? '💰',
        accountName = m['accounts']?['name'] ?? '';
  final String id;
  final String type;
  final String? categoryId;
  final String? accountId;
  final double amount;
  final String description;
  final DateTime date;
  final String categoryName;
  final String categoryIcon;
  final String accountName;
}

class Budget {
  Budget.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        categoryId = m['category_id'],
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        month = m['month'] ?? 1,
        year = m['year'] ?? 2026,
        categoryName = m['categories']?['name'] ?? '',
        categoryIcon = m['categories']?['icon'] ?? '💰';
  final String id;
  final String? categoryId;
  final double amount;
  final int month;
  final int year;
  final String categoryName;
  final String categoryIcon;
}

class Goal {
  Goal.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        title = m['title'] ?? '',
        targetAmount = (m['target_amount'] as num?)?.toDouble() ?? 0,
        savedAmount = (m['saved_amount'] as num?)?.toDouble() ?? 0,
        targetDate = m['target_date'] != null ? DateTime.parse(m['target_date']) : null,
        notes = m['notes'] ?? '';
  final String id;
  final String title;
  final double targetAmount;
  final double savedAmount;
  final DateTime? targetDate;
  final String notes;
}

class Saving {
  Saving.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        type = m['type'] ?? 'deposit',
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        date = DateTime.parse(m['date']),
        purpose = m['purpose'] ?? '',
        notes = m['notes'] ?? '',
        savingType = m['saving_type'] ?? 'general',
        institution = m['institution'] ?? '',
        headId = m['head_id'],
        headName = m['saving_heads']?['name'] ?? '',
        accountId = m['account_id'],
        accountName = m['accounts']?['name'] ?? '';
  final String id;
  final String type; // deposit | withdraw
  final double amount;
  final DateTime date;
  final String purpose;
  final String notes;
  final String savingType; // general | bank | dps | fdr | cash | other
  final String institution; // bank/place where the money is kept
  final String? headId;
  final String headName;
  final String? accountId;
  final String accountName;
}

class RecurringSaving {
  RecurringSaving.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        title = m['title'] ?? '',
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        frequency = m['frequency'] ?? 'monthly',
        nextRunDate = DateTime.parse(m['next_run_date']),
        isActive = m['is_active'] ?? true,
        savingType = m['saving_type'] ?? 'general',
        institution = m['institution'] ?? '',
        headId = m['head_id'],
        headName = m['saving_heads']?['name'] ?? '',
        accountId = m['account_id'],
        accountName = m['accounts']?['name'] ?? '';
  final String id;
  final String title;
  final double amount;
  final String frequency;
  final DateTime nextRunDate;
  final bool isActive;
  final String savingType;
  final String institution;
  final String? headId;
  final String headName;
  final String? accountId;
  final String accountName;
}

class FamilyMember {
  FamilyMember.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'] ?? '',
        relationship = m['relationship'] ?? '',
        dateOfBirth = m['date_of_birth'] != null ? DateTime.parse(m['date_of_birth']) : null,
        notes = m['notes'] ?? '';
  final String id;
  final String name;
  final String relationship;
  final DateTime? dateOfBirth;
  final String notes;
}

class Asset {
  Asset.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'] ?? '',
        type = m['type'] ?? 'Other',
        purchaseValue = (m['purchase_value'] as num?)?.toDouble() ?? 0,
        currentValue = (m['current_value'] as num?)?.toDouble() ?? 0,
        depreciation = (m['depreciation'] as num?)?.toDouble() ?? 0,
        purchaseDate = m['purchase_date'] != null ? DateTime.parse(m['purchase_date']) : null,
        quantity = (m['quantity'] as num?)?.toDouble(),
        unit = m['unit'] ?? '',
        notes = m['notes'] ?? '';
  final String id;
  final String name;
  final String type;
  final double purchaseValue;
  final double currentValue;
  final double depreciation;
  final DateTime? purchaseDate;
  final double? quantity; // e.g. 5.5 bhori of gold, 10 katha of land
  final String unit;
  final String notes;
}

class Investment {
  Investment.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'] ?? '',
        type = m['type'] ?? 'stocks',
        investedAmount = (m['invested_amount'] as num?)?.toDouble() ?? 0,
        currentValue = (m['current_value'] as num?)?.toDouble() ?? 0,
        roi = (m['roi'] as num?)?.toDouble() ?? 0,
        profitLoss = (m['profit_loss'] as num?)?.toDouble() ?? 0;
  final String id;
  final String name;
  final String type;
  final double investedAmount;
  final double currentValue;
  final double roi;
  final double profitLoss;
}

class Liability {
  Liability.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'] ?? '',
        type = m['type'] ?? 'loan_taken',
        principal = (m['principal'] as num?)?.toDouble() ?? 0,
        interestRate = (m['interest_rate'] as num?)?.toDouble() ?? 0,
        dueDate = m['due_date'] != null ? DateTime.parse(m['due_date']) : null,
        remainingBalance = (m['remaining_balance'] as num?)?.toDouble() ?? 0,
        phone = m['phone'] ?? '',
        notes = m['notes'] ?? '';
  final String id;
  final String name;
  final String type;
  final double principal;
  final double interestRate;
  final DateTime? dueDate;
  final double remainingBalance;
  final String phone; // shop contact for type shop_due
  final String notes;

  /// loan_given is money owed TO the user (a receivable), not a debt.
  bool get isReceivable => type == 'loan_given';

  /// shop_due rows are the Bazar page's shop khatas.
  bool get isShop => type == 'shop_due';
}

class BazarPurchase {
  BazarPurchase.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        liabilityId = m['liability_id'],
        accountId = m['account_id'],
        transactionId = m['transaction_id'],
        paymentType = m['payment_type'] ?? 'cash',
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        date = DateTime.parse(m['date']),
        description = m['description'] ?? '',
        items = PurchaseItem.listFrom(m['items']),
        shopName = m['liabilities']?['name'] ?? '',
        accountName = m['accounts']?['name'] ?? '';
  final String id;
  final String? liabilityId;
  final String? accountId;
  final String? transactionId;
  final String paymentType; // cash | due
  final double amount;
  final DateTime date;
  final String description;
  final List<PurchaseItem> items;
  final String shopName;
  final String accountName;
}

class Repayment {
  Repayment.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        liabilityId = m['liability_id'],
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        date = DateTime.parse(m['date']),
        notes = m['notes'] ?? '',
        accountId = m['account_id'],
        accountName = m['accounts']?['name'] ?? '';
  final String id;
  final String? liabilityId;
  final double amount;
  final DateTime date;
  final String notes;
  final String? accountId;
  final String accountName;
}

class Recurring {
  Recurring.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        title = m['title'] ?? '',
        type = m['type'] ?? 'expense',
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        frequency = m['frequency'] ?? 'monthly',
        nextRunDate = DateTime.parse(m['next_run_date']),
        isActive = m['is_active'] ?? true,
        categoryId = m['category_id'],
        accountId = m['account_id'],
        categoryName = m['categories']?['name'] ?? '',
        categoryIcon = m['categories']?['icon'] ?? '💰',
        accountName = m['accounts']?['name'] ?? '';
  final String id;
  final String title;
  final String type;
  final double amount;
  final String frequency;
  final DateTime nextRunDate;
  final bool isActive;
  final String? categoryId;
  final String? accountId;
  final String categoryName;
  final String categoryIcon;
  final String accountName;
}

class Transfer {
  Transfer.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        date = DateTime.parse(m['date']),
        notes = m['notes'] ?? '',
        fromName = m['from_account']?['name'] ?? '?',
        toName = m['to_account']?['name'] ?? '?';
  final String id;
  final double amount;
  final DateTime date;
  final String notes;
  final String fromName;
  final String toName;
}

/// A file in the attachments table (invoice/receipt linked to a transaction).
class AttachmentInfo {
  AttachmentInfo.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        fileName = m['file_name'] ?? '',
        fileUrl = m['file_url'] ?? '',
        contentType = m['content_type'] ?? '';
  final String id;
  final String fileName;
  final String fileUrl;
  final String contentType;

  bool get isImage => contentType.startsWith('image/');
}

// ---- Meals (mess) — see migration v16 ----

class MealGroup {
  MealGroup.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'] ?? '',
        inviteCode = m['invite_code'] ?? '',
        createdBy = m['created_by'] ?? '',
        hasMaid = m['has_maid'] ?? false,
        breakfastValue = (m['breakfast_value'] as num?)?.toDouble() ?? 0.5,
        lunchValue = (m['lunch_value'] as num?)?.toDouble() ?? 1,
        dinnerValue = (m['dinner_value'] as num?)?.toDouble() ?? 1,
        cutoffTime = m['cutoff_time'];
  final String id;
  final String name;
  final String inviteCode;
  final String createdBy;
  final bool hasMaid; // when true, cooking duty is hidden from the roster
  final double breakfastValue;
  final double lunchValue;
  final double dinnerValue;
  final String? cutoffTime; // 'HH:MM:SS' — meal request deadline, null = none

  /// 'HH:MM' for display / time inputs.
  String? get cutoffHHmm => cutoffTime?.substring(0, 5);
}

class MealGroupMember {
  MealGroupMember.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        groupId = m['group_id'],
        userId = m['user_id'],
        displayName = m['display_name'] ?? '',
        role = m['role'] ?? 'member',
        status = m['status'] ?? 'pending',
        group = m['meal_groups'] != null ? MealGroup.fromMap(m['meal_groups']) : null;
  final String id;
  final String groupId;
  final String userId;
  final String displayName;
  final String role; // manager | member
  final String status; // pending | approved | rejected | left | removed
  final MealGroup? group; // joined meal_groups row, when selected
}

class MealEntry {
  MealEntry.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        memberId = m['member_id'],
        date = DateTime.parse(m['date']),
        breakfast = (m['breakfast'] as num?)?.toDouble() ?? 0,
        lunch = (m['lunch'] as num?)?.toDouble() ?? 0,
        dinner = (m['dinner'] as num?)?.toDouble() ?? 0,
        guestBreakfast = (m['guest_breakfast'] as num?)?.toDouble() ?? 0,
        guestLunch = (m['guest_lunch'] as num?)?.toDouble() ?? 0,
        guestDinner = (m['guest_dinner'] as num?)?.toDouble() ?? 0;
  final String id;
  final String memberId;
  final DateTime date;
  final double breakfast;
  final double lunch;
  final double dinner;
  final double guestBreakfast;
  final double guestLunch;
  final double guestDinner;
}

class MealDeposit {
  MealDeposit.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        memberId = m['member_id'],
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        date = DateTime.parse(m['date']),
        note = m['note'] ?? '';
  final String id;
  final String memberId;
  final double amount;
  final DateTime date;
  final String note;
}

/// One "ki ki kinlam" line: name + optional amount.
class PurchaseItem {
  PurchaseItem({required this.name, this.amount});
  PurchaseItem.fromMap(Map<String, dynamic> m)
      : name = m['name'] ?? '',
        amount = (m['amount'] as num?)?.toDouble();
  final String name;
  final double? amount;

  Map<String, dynamic> toMap() => {'name': name, 'amount': amount};

  static List<PurchaseItem> listFrom(dynamic raw) => ((raw ?? []) as List)
      .map((e) => PurchaseItem.fromMap(Map<String, dynamic>.from(e)))
      .toList();
}

class MealExpense {
  MealExpense.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        expenseType = m['expense_type'] ?? 'bazar',
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        date = DateTime.parse(m['date']),
        note = m['note'] ?? '',
        spentBy = m['spent_by'],
        addedBy = m['added_by'] ?? '',
        items = PurchaseItem.listFrom(m['items']),
        attachmentUrl = m['attachment_url'];
  final String id;
  final String expenseType; // bazar | utility | maid | feast | other
  final double amount;
  final DateTime date;
  final String note;
  final String? spentBy; // member who did the bazar
  final String addedBy; // auth user who recorded it
  final List<PurchaseItem> items;
  final String? attachmentUrl; // receipt photo in the documents bucket
}

class MealAdvance {
  MealAdvance.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        memberId = m['member_id'],
        type = m['type'] ?? 'taken',
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        date = DateTime.parse(m['date']),
        note = m['note'] ?? '';
  final String id;
  final String memberId;
  final String type; // taken | returned | adjusted
  final double amount;
  final DateTime date;
  final String note;

  /// Signed effect on the advance balance the mess is holding.
  double get signed => type == 'taken' ? amount : -amount;
}

class MealHoliday {
  MealHoliday.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        date = DateTime.parse(m['date']),
        title = m['title'] ?? 'Meal Holiday',
        menu = m['menu'] ?? '';
  final String id;
  final DateTime date;
  final String title;
  final String menu; // special khabar / nasta plan
}

class MealDutyType {
  MealDutyType.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'] ?? '',
        isBuiltin = m['is_builtin'] ?? false,
        excludedWhenMaid = m['excluded_when_maid'] ?? false,
        isActive = m['is_active'] ?? true,
        sortOrder = m['sort_order'] ?? 0;
  final String id;
  final String name;
  final bool isBuiltin;
  final bool excludedWhenMaid; // true for Cooking
  final bool isActive;
  final int sortOrder;
}

class MealDutyAssignment {
  MealDutyAssignment.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        dutyTypeId = m['duty_type_id'],
        memberId = m['member_id'],
        date = DateTime.parse(m['date']),
        note = m['note'] ?? '';
  final String id;
  final String dutyTypeId;
  final String memberId;
  final DateTime date;
  final String note;
}

class MealMemberSummary {
  MealMemberSummary.fromMap(Map<String, dynamic> m)
      : memberId = m['member_id'],
        userId = m['user_id'],
        displayName = m['display_name'] ?? '',
        status = m['status'] ?? 'approved',
        role = m['role'] ?? 'member',
        meals = (m['meals'] as num?)?.toDouble() ?? 0,
        deposits = (m['deposits'] as num?)?.toDouble() ?? 0,
        advance = (m['advance'] as num?)?.toDouble() ?? 0,
        openingBalance = (m['opening_balance'] as num?)?.toDouble() ?? 0,
        mealCost = (m['meal_cost'] as num?)?.toDouble() ?? 0,
        fixedShare = (m['fixed_share'] as num?)?.toDouble() ?? 0,
        totalCost = (m['total_cost'] as num?)?.toDouble() ?? 0,
        balance = (m['balance'] as num?)?.toDouble() ?? 0;
  final String memberId;
  final String userId;
  final String displayName;
  final String status;
  final String role;
  final double meals;
  final double deposits;
  final double advance; // জামানত held by the mess (lifetime)
  final double openingBalance; // carry from the previous closed month (v18)
  final double mealCost;
  final double fixedShare;
  final double totalCost;
  final double balance; // negative = owes money (includes openingBalance)
}

class MealMonthSummary {
  MealMonthSummary.fromMap(Map<String, dynamic> m)
      : year = m['year'] ?? 0,
        month = m['month'] ?? 0,
        totalMeals = (m['total_meals'] as num?)?.toDouble() ?? 0,
        totalBazar = (m['total_bazar'] as num?)?.toDouble() ?? 0,
        totalFixed = (m['total_fixed'] as num?)?.toDouble() ?? 0,
        totalDeposits = (m['total_deposits'] as num?)?.toDouble() ?? 0,
        totalAdvance = (m['total_advance'] as num?)?.toDouble() ?? 0,
        totalOpening = (m['total_opening'] as num?)?.toDouble() ?? 0,
        mealRate = (m['meal_rate'] as num?)?.toDouble() ?? 0,
        isClosed = m['is_closed'] ?? false,
        closedAt = m['closed_at'] != null ? DateTime.tryParse(m['closed_at']) : null,
        prevMonthClosed = m['prev_month_closed'] ?? false,
        members = ((m['members'] ?? []) as List)
            .map((e) => MealMemberSummary.fromMap(Map<String, dynamic>.from(e)))
            .toList();
  final int year;
  final int month;
  final double totalMeals;
  final double totalBazar;
  final double totalFixed;
  final double totalDeposits;
  final double totalAdvance; // জামানত the mess is holding (lifetime)
  final double totalOpening; // carry-forward total from the last closed month
  final double mealRate;
  final bool isClosed; // month closed → read-only until reopened (v18)
  final DateTime? closedAt;
  final bool prevMonthClosed;
  final List<MealMemberSummary> members;
}

// ---- Meals v18/v19 additions ----

class MealRequest {
  MealRequest.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        memberId = m['member_id'],
        date = DateTime.parse(m['date']),
        type = m['type'] ?? 'off',
        breakfast = (m['breakfast'] as num?)?.toDouble() ?? 0,
        lunch = (m['lunch'] as num?)?.toDouble() ?? 0,
        dinner = (m['dinner'] as num?)?.toDouble() ?? 0,
        note = m['note'] ?? '',
        status = m['status'] ?? 'pending';
  final String id;
  final String memberId;
  final DateTime date;
  final String type; // off | guest
  final double breakfast; // off: 1 = that slot off; guest: guest count
  final double lunch;
  final double dinner;
  final String note;
  final String status; // pending | approved | rejected | cancelled
}

class MealNotice {
  MealNotice.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        title = m['title'] ?? '',
        body = m['body'] ?? '',
        pinned = m['pinned'] ?? false,
        createdBy = m['created_by'] ?? '',
        createdAt = DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now();
  final String id;
  final String title;
  final String body;
  final bool pinned; // pinned notices banner on the summary
  final String createdBy;
  final DateTime createdAt;
}

class MealShoppingItem {
  MealShoppingItem.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        name = m['name'] ?? '',
        qty = m['qty'] ?? '',
        isBought = m['is_bought'] ?? false,
        boughtBy = m['bought_by'],
        addedBy = m['added_by'] ?? '';
  final String id;
  final String name;
  final String qty; // free text: "2 kg"
  final bool isBought;
  final String? boughtBy; // auth user who ticked it
  final String addedBy;
}

class MealSharedExpenseShare {
  MealSharedExpenseShare.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        memberId = m['member_id'],
        shareAmount = (m['share_amount'] as num?)?.toDouble() ?? 0,
        paid = m['paid'] ?? false;
  final String id;
  final String memberId;
  final double shareAmount;
  final bool paid;
}

class MealSharedExpense {
  MealSharedExpense.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        title = m['title'] ?? '',
        amount = (m['amount'] as num?)?.toDouble() ?? 0,
        date = DateTime.parse(m['date']),
        splitType = m['split_type'] ?? 'equal',
        note = m['note'] ?? '',
        shares = ((m['meal_shared_expense_shares'] ?? []) as List)
            .map((e) =>
                MealSharedExpenseShare.fromMap(Map<String, dynamic>.from(e)))
            .toList();
  final String id;
  final String title; // "Basha bhara July", "Wifi bill"
  final double amount;
  final DateTime date;
  final String splitType; // equal | custom
  final String note;
  final List<MealSharedExpenseShare> shares;
}

class MealNotification {
  MealNotification.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        type = m['type'] ?? '',
        title = m['title'] ?? '',
        body = m['body'] ?? '',
        link = m['link'] ?? '',
        isRead = m['is_read'] ?? false,
        createdAt = DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now();
  final String id;
  final String type; // request_new | request_response | notice | join_request
  final String title;
  final String body;
  final String link; // web route hint, unused on mobile
  final bool isRead;
  final DateTime createdAt;
}
