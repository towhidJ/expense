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
  MealDutyPage, MealMembersPage, MealSettingsPage, MealGroupsPage
} from './pages/meals/MealPages';
import Reports from './pages/Reports';
import Budgets from './pages/Budgets';
import Assets from './pages/Assets';
import Accounts from './pages/Accounts';
import Transfers from './pages/Transfers';
import Goals from './pages/Goals';
import Savings from './pages/Savings';
import Liabilities from './pages/Liabilities';
import Investments from './pages/Investments';
import FamilyMembers from './pages/FamilyMembers';
import Recurring from './pages/Recurring';
import Categories from './pages/Categories';
import Admin from './pages/Admin';

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
                <Route path="bazar" element={<Bazar />} />
                <Route path="reports" element={<Reports />} />
                <Route path="budgets" element={<Budgets />} />
                <Route path="assets" element={<Assets />} />
                <Route path="liabilities" element={<Liabilities />} />
                <Route path="investments" element={<Investments />} />
                <Route path="family" element={<FamilyMembers />} />
                <Route path="accounts" element={<Accounts />} />
                <Route path="transfers" element={<Transfers />} />
                <Route path="recurring" element={<Recurring />} />
                <Route path="categories" element={<Categories />} />
                <Route path="goals" element={<Goals />} />
                <Route path="savings" element={<Savings />} />
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
                <Route path="deposits" element={<MealDepositsPage />} />
                <Route path="expenses" element={<MealExpensesPage />} />
                <Route path="duty" element={<MealDutyPage />} />
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
