import { useMeal } from '../../context/MealContext';
import { Pin } from 'lucide-react';
import MonthSummary from '../../components/meals/MonthSummary';
import MonthCloseCard from '../../components/meals/MonthCloseCard';
import RequestsTab from '../../components/meals/RequestsTab';
import NoticeBoard from '../../components/meals/NoticeBoard';
import ShoppingListTab from '../../components/meals/ShoppingListTab';
import SharedBillsTab from '../../components/meals/SharedBillsTab';
import MealCalendar from '../../components/meals/MealCalendar';
import NotificationsList from '../../components/meals/NotificationsList';
import MealEntryGrid from '../../components/meals/MealEntryGrid';
import DepositsTab from '../../components/meals/DepositsTab';
import AdvancesSection from '../../components/meals/AdvancesSection';
import ExpensesTab from '../../components/meals/ExpensesTab';
import DutyRoster from '../../components/meals/DutyRoster';
import MembersTab from '../../components/meals/MembersTab';
import GroupSettings from '../../components/meals/GroupSettings';
import Onboarding from '../../components/meals/Onboarding';

// Thin pages for the /meals/* workspace routes. All state comes from
// MealContext (group, month, data) so it survives page switches.

function PageHeader({ title, subtitle }) {
  return (
    <div className="mb-6">
      <h1 className="text-2xl font-bold text-white">{title}</h1>
      {subtitle && <p className="text-white/40 text-sm mt-1">{subtitle}</p>}
    </div>
  );
}

function Loading() {
  return <div className="text-white/50 p-6">Loading...</div>;
}

const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'];

export function MealSummaryPage() {
  const { data, currentUserId, isManager, year, month } = useMeal();
  if (data.loading && !data.summary) return <Loading />;
  const pinned = (data.notices || []).filter(n => n.pinned);
  return (
    <div className="animate-in space-y-4">
      <PageHeader title="Summary" subtitle="This month's meal rate, costs and member balances." />
      {pinned.map(n => (
        <div key={n.id} className="bg-amber-500/10 border border-amber-500/20 rounded-2xl p-4 flex items-start gap-3">
          <Pin size={16} className="text-amber-400 shrink-0 mt-0.5" />
          <div>
            <p className="text-amber-400 text-sm font-medium">{n.title}</p>
            {n.body && <p className="text-white/60 text-xs mt-0.5 whitespace-pre-wrap">{n.body}</p>}
          </div>
        </div>
      ))}
      <MonthCloseCard
        summary={data.summary} isManager={isManager}
        closeMonth={data.closeMonth} reopenMonth={data.reopenMonth}
        monthLabel={`${MONTHS[month - 1]} ${year}`}
      />
      <MonthSummary summary={data.summary} currentUserId={currentUserId} />
    </div>
  );
}

export function MealDailyPage() {
  const { data, isManager, currentUserId, year, month } = useMeal();
  if (data.loading && data.members.length === 0) return <Loading />;
  return (
    <div className="animate-in">
      <PageHeader title="Daily Meals" subtitle="Record breakfast, lunch and dinner per member." />
      <MealEntryGrid
        members={data.members} entries={data.entries} upsertEntry={data.upsertEntry}
        isManager={isManager} currentUserId={currentUserId} year={year} month={month}
        holidays={data.holidays} upsertHoliday={data.upsertHoliday} deleteHoliday={data.deleteHoliday}
      />
    </div>
  );
}

export function MealDepositsPage() {
  const { data, isManager } = useMeal();
  if (data.loading && data.members.length === 0) return <Loading />;
  return (
    <div className="animate-in space-y-6">
      <PageHeader title="Deposits & Advance" subtitle="Member deposits (jama) and the জামানত the mess is holding." />
      <AdvancesSection
        advances={data.advances} members={data.members} isManager={isManager}
        addAdvance={data.addAdvance} adjustAdvance={data.adjustAdvance} deleteAdvance={data.deleteAdvance}
      />
      <DepositsTab
        deposits={data.deposits} members={data.members} isManager={isManager}
        addDeposit={data.addDeposit} updateDeposit={data.updateDeposit} deleteDeposit={data.deleteDeposit}
      />
    </div>
  );
}

export function MealExpensesPage() {
  const { data, isManager, currentUserId } = useMeal();
  if (data.loading && data.members.length === 0) return <Loading />;
  return (
    <div className="animate-in">
      <PageHeader title="Expenses" subtitle="Bazar and fixed costs, with itemized lists and receipts." />
      <ExpensesTab
        expenses={data.expenses} members={data.members} isManager={isManager} currentUserId={currentUserId}
        addExpense={data.addExpense} updateExpense={data.updateExpense} deleteExpense={data.deleteExpense}
        uploadReceipt={data.uploadReceipt}
      />
    </div>
  );
}

export function MealDutyPage() {
  const { data, isManager, year, month } = useMeal();
  if (data.loading && data.dutyTypes.length === 0) return <Loading />;
  return (
    <div className="animate-in">
      <PageHeader title="Duty Roster" subtitle="Who does bazar, cooking and cleaning on which day." />
      <DutyRoster
        group={data.group} dutyTypes={data.dutyTypes} dutyAssignments={data.dutyAssignments}
        members={data.members} isManager={isManager} year={year} month={month}
        assignDuty={data.assignDuty} removeDutyAssignment={data.removeDutyAssignment}
        addDutyType={data.addDutyType} updateDutyType={data.updateDutyType} deleteDutyType={data.deleteDutyType}
      />
    </div>
  );
}

export function MealMembersPage() {
  const { data, isManager, currentUserId, activeMembership, leaveGroup } = useMeal();
  if (data.loading && data.members.length === 0) return <Loading />;
  return (
    <div className="animate-in">
      <PageHeader title="Members" subtitle="Approve requests, manage roles, share the invite code." />
      <MembersTab
        members={data.members} isManager={isManager} currentUserId={currentUserId}
        respondJoinRequest={data.respondJoinRequest} removeMember={data.removeMember}
        setMemberRole={data.setMemberRole}
        onLeave={() => leaveGroup(activeMembership.group_id).catch(err => alert(err.message))}
      />
    </div>
  );
}

export function MealSettingsPage() {
  const { data, isManager } = useMeal();
  if (data.loading && !data.group) return <Loading />;
  return (
    <div className="animate-in">
      <PageHeader title="Settings" subtitle="Meal values, maid (kajer bua) and the invite code." />
      <GroupSettings
        group={data.group} isManager={isManager}
        updateGroup={data.updateGroup} regenerateCode={data.regenerateCode}
      />
    </div>
  );
}

export function MealRequestsPage() {
  const { data, isManager, currentUserId } = useMeal();
  if (data.loading && data.members.length === 0) return <Loading />;
  return (
    <div className="animate-in">
      <PageHeader title="Meal Requests" subtitle="Request a meal off or a guest meal — the manager approves it." />
      <RequestsTab
        group={data.group} requests={data.requests} members={data.members}
        isManager={isManager} currentUserId={currentUserId}
        submitRequest={data.submitRequest} cancelRequest={data.cancelRequest}
        respondRequest={data.respondRequest}
      />
    </div>
  );
}

export function MealNoticesPage() {
  const { data, isManager } = useMeal();
  if (data.loading && data.notices.length === 0) return <Loading />;
  return (
    <div className="animate-in">
      <PageHeader title="Notice Board" subtitle="Announcements for everyone in the mess." />
      <NoticeBoard
        notices={data.notices} isManager={isManager}
        addNotice={data.addNotice} updateNotice={data.updateNotice} deleteNotice={data.deleteNotice}
      />
    </div>
  );
}

export function MealShoppingPage() {
  const { data, isManager, currentUserId } = useMeal();
  if (data.loading && data.members.length === 0) return <Loading />;
  return (
    <div className="animate-in">
      <PageHeader title="Shopping List" subtitle="What the mess needs before the next bazar — tick off what you buy." />
      <ShoppingListTab
        items={data.shoppingItems} members={data.members}
        isManager={isManager} currentUserId={currentUserId}
        addShoppingItem={data.addShoppingItem} toggleShoppingItem={data.toggleShoppingItem}
        deleteShoppingItem={data.deleteShoppingItem} convertShoppingToExpense={data.convertShoppingToExpense}
      />
    </div>
  );
}

export function MealSharedBillsPage() {
  const { data, isManager, currentUserId } = useMeal();
  if (data.loading && data.members.length === 0) return <Loading />;
  return (
    <div className="animate-in">
      <PageHeader title="Shared Bills" subtitle="Rent, wifi, gas — split equally or custom, with paid ticks." />
      <SharedBillsTab
        sharedExpenses={data.sharedExpenses} members={data.members}
        isManager={isManager} currentUserId={currentUserId}
        createSharedExpense={data.createSharedExpense}
        toggleSharePaid={data.toggleSharePaid} deleteSharedExpense={data.deleteSharedExpense}
      />
    </div>
  );
}

export function MealCalendarPage() {
  const { data, currentUserId, year, month } = useMeal();
  if (data.loading && data.members.length === 0) return <Loading />;
  return (
    <div className="animate-in">
      <PageHeader title="Meal Calendar" subtitle="The whole month at a glance — who ate how much on which day." />
      <MealCalendar
        members={data.members} entries={data.entries} holidays={data.holidays}
        year={year} month={month} currentUserId={currentUserId}
      />
    </div>
  );
}

export function MealNotificationsPage() {
  const { data } = useMeal();
  if (data.loading && data.notifications.length === 0) return <Loading />;
  return (
    <div className="animate-in">
      <PageHeader title="Notifications" subtitle="Requests, notices and join alerts for this mess." />
      <NotificationsList
        notifications={data.notifications}
        markNotificationsRead={data.markNotificationsRead}
        deleteNotification={data.deleteNotification}
      />
    </div>
  );
}

export function MealGroupsPage() {
  return <Onboarding />;
}
