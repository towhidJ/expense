import { BrowserRouter, Routes, Route } from 'react-router';
import { AuthProvider } from './context/AuthContext';
import { EntityProvider } from './context/EntityContext';
import { AccountProvider } from './context/AccountContext';
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

function App() {
  return (
    <AuthProvider>
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
                <Route path="import" element={<ImportTransactions />} />
                <Route path="bazar" element={<Bazar />} />
                <Route path="reports" element={<Reports />} />
                <Route path="forecast" element={<Forecast />} />
                <Route path="budgets" element={<Budgets />} />
                <Route path="assets" element={<Assets />} />
                <Route path="liabilities" element={<Liabilities />} />
                <Route path="lending" element={<Lending />} />
                <Route path="zakat" element={<Zakat />} />
                <Route path="subscriptions" element={<Subscriptions />} />
                <Route path="insurance" element={<Insurance />} />
                <Route path="utility" element={<Utility />} />
                <Route path="rent" element={<Rent />} />
                <Route path="warranty" element={<Warranty />} />
                <Route path="backup" element={<Backup />} />
                <Route path="activity" element={<Activity />} />
                <Route path="splitter" element={<Splitter />} />
                <Route path="tax" element={<Tax />} />
                <Route path="insights" element={<Insights />} />
                <Route path="scan" element={<ScanReceipt />} />
                <Route path="investments" element={<Investments />} />
                <Route path="family" element={<FamilyMembers />} />
                <Route path="accounts" element={<Accounts />} />
                <Route path="transfers" element={<Transfers />} />
                <Route path="recurring" element={<Recurring />} />
                <Route path="categories" element={<Categories />} />
                <Route path="goals" element={<Goals />} />
                <Route path="savings" element={<Savings />} />
                <Route path="alerts" element={<Alerts />} />
                <Route path="admin" element={<Admin />} />
              </Route>
              {/* Meal workspace: its own layout + sidebar, separate from the expense tracker */}
              <Route
                path="/meals"
                element={
                  <ProtectedRoute>
                    <MealProvider>
                      <MealLayout />
                    </MealProvider>
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
    </AuthProvider>
  );
}

export default App;
