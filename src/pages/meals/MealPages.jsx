import { useMeal } from '../../context/MealContext';
import MonthSummary from '../../components/meals/MonthSummary';
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

export function MealSummaryPage() {
  const { data, currentUserId } = useMeal();
  if (data.loading && !data.summary) return <Loading />;
  return (
    <div className="animate-in">
      <PageHeader title="Summary" subtitle="This month's meal rate, costs and member balances." />
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

export function MealGroupsPage() {
  return <Onboarding />;
}
