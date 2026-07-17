import { BrowserRouter, Routes, Route } from 'react-router';
import { AuthProvider } from './context/AuthContext';
import { EntityProvider } from './context/EntityContext';
import { AccountProvider } from './context/AccountContext';
import { SubscriptionProvider } from './context/SubscriptionContext';
import PremiumGate from './components/PremiumGate';
import ProtectedRoute from './components/ProtectedRoute';
import Layout from './components/Layout';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Transactions from './pages/Transactions';
import Bazar from './pages/Bazar';
import { MealProvider } from './context/MealContext';
import MealLayout from './components/meals/MealLayout';
import {
  MealSummaryPage, MealDailyPage, MealDepositsPage, MealExpensesPage,
  MealDutyPage, MealMembersPage, MealSettingsPage, MealGroupsPage,
  MealRequestsPage, MealNoticesPage, MealShoppingPage, MealSharedBillsPage,
  MealCalendarPage, MealNotificationsPage, MealReportsPage, MealStockPage
} from './pages/meals/MealPages';
import Reports from './pages/Reports';
import Forecast from './pages/Forecast';
import Budgets from './pages/Budgets';
import Assets from './pages/Assets';
import Accounts from './pages/Accounts';
import Transfers from './pages/Transfers';
import Goals from './pages/Goals';
import Savings from './pages/Savings';
import Liabilities from './pages/Liabilities';
import Lending from './pages/Lending';
import Zakat from './pages/Zakat';
import Subscriptions from './pages/Subscriptions';
import Insurance from './pages/Insurance';
import Utility from './pages/Utility';
import Rent from './pages/Rent';
import Warranty from './pages/Warranty';
import Backup from './pages/Backup';
import Activity from './pages/Activity';
import Splitter from './pages/Splitter';
import Tax from './pages/Tax';
import Insights from './pages/Insights';
import ScanReceipt from './pages/ScanReceipt';
import Investments from './pages/Investments';
import FamilyMembers from './pages/FamilyMembers';
import Recurring from './pages/Recurring';
import Categories from './pages/Categories';
import Admin from './pages/Admin';
import Alerts from './pages/Alerts';
import ImportTransactions from './pages/ImportTransactions';

// Wrap a route element in the premium gate for its module key (v39 gating).
const g = (key, el) => <PremiumGate module={key}>{el}</PremiumGate>;

function App() {
  return (
    <AuthProvider>
      <SubscriptionProvider>
      <EntityProvider>
        <AccountProvider>
          <BrowserRouter>
            <Routes>
              <Route path="/login" element={<Login />} />
              <Route
                path="/"
                element={
                  <ProtectedRoute>
                    <Layout />
                  </ProtectedRoute>
                }
              >
                <Route index element={<Dashboard />} />
                <Route path="transactions" element={<Transactions />} />
                <Route path="import" element={g('import', <ImportTransactions />)} />
                <Route path="bazar" element={g('bazar', <Bazar />)} />
                <Route path="reports" element={g('reports', <Reports />)} />
                <Route path="forecast" element={g('forecast', <Forecast />)} />
                <Route path="budgets" element={g('budgets', <Budgets />)} />
                <Route path="assets" element={g('assets', <Assets />)} />
                <Route path="liabilities" element={g('liabilities', <Liabilities />)} />
                <Route path="lending" element={g('lending', <Lending />)} />
                <Route path="zakat" element={g('zakat', <Zakat />)} />
                <Route path="subscriptions" element={g('subscriptions', <Subscriptions />)} />
                <Route path="insurance" element={g('insurance', <Insurance />)} />
                <Route path="utility" element={g('utility', <Utility />)} />
                <Route path="rent" element={g('rent', <Rent />)} />
                <Route path="warranty" element={g('warranty', <Warranty />)} />
                <Route path="backup" element={g('backup', <Backup />)} />
                <Route path="activity" element={g('activity', <Activity />)} />
                <Route path="splitter" element={g('splitter', <Splitter />)} />
                <Route path="tax" element={g('tax', <Tax />)} />
                <Route path="insights" element={g('insights', <Insights />)} />
                <Route path="scan" element={g('scan', <ScanReceipt />)} />
                <Route path="investments" element={g('investments', <Investments />)} />
                <Route path="family" element={g('family', <FamilyMembers />)} />
                <Route path="accounts" element={<Accounts />} />
                <Route path="transfers" element={g('transfers', <Transfers />)} />
                <Route path="recurring" element={g('recurring', <Recurring />)} />
                <Route path="categories" element={g('categories', <Categories />)} />
                <Route path="goals" element={g('goals', <Goals />)} />
                <Route path="savings" element={g('savings', <Savings />)} />
                <Route path="alerts" element={<Alerts />} />
                <Route path="admin" element={<Admin />} />
              </Route>
              {/* Meal workspace: its own layout + sidebar, separate from the expense tracker */}
              <Route
                path="/meals"
                element={
                  <ProtectedRoute>
                    {g('meals',
                      <MealProvider>
                        <MealLayout />
                      </MealProvider>
                    )}
                  </ProtectedRoute>
                }
              >
                <Route index element={<MealSummaryPage />} />
                <Route path="daily" element={<MealDailyPage />} />
                <Route path="calendar" element={<MealCalendarPage />} />
                <Route path="deposits" element={<MealDepositsPage />} />
                <Route path="expenses" element={<MealExpensesPage />} />
                <Route path="shopping" element={<MealShoppingPage />} />
                <Route path="bills" element={<MealSharedBillsPage />} />
                <Route path="requests" element={<MealRequestsPage />} />
                <Route path="notices" element={<MealNoticesPage />} />
                <Route path="notifications" element={<MealNotificationsPage />} />
                <Route path="duty" element={<MealDutyPage />} />
                <Route path="stock" element={<MealStockPage />} />
                <Route path="reports" element={<MealReportsPage />} />
                <Route path="members" element={<MealMembersPage />} />
                <Route path="settings" element={<MealSettingsPage />} />
                <Route path="groups" element={<MealGroupsPage />} />
              </Route>
            </Routes>
          </BrowserRouter>
        </AccountProvider>
      </EntityProvider>
      </SubscriptionProvider>
    </AuthProvider>
  );
}

export default App;
