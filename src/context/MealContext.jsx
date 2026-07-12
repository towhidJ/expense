import { createContext, useContext, useState } from 'react';
import { useAuth } from './AuthContext';
import { useMealGroups } from '../hooks/useMealGroups';
import { useMealData } from '../hooks/useMealData';

// The meal workspace's shared state: my groups, the active group, the
// selected month, and all of that group's data. Lives above the /meals/*
// routes so the group and month survive page switches within the workspace.
const MealContext = createContext(null);

export function MealProvider({ children }) {
  const { user } = useAuth();
  const now = new Date();
  const [year, setYear] = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth() + 1);

  const groups = useMealGroups();
  const groupId = groups.activeMembership?.group_id || null;
  const data = useMealData(groupId, year, month);

  const shiftMonth = (delta) => {
    let m = month + delta;
    let y = year;
    if (m < 1) { m = 12; y -= 1; }
    if (m > 12) { m = 1; y += 1; }
    setMonth(m);
    setYear(y);
  };

  const myMember = data.members.find(m => m.user_id === user?.id);
  const isManager =
    (myMember?.role || groups.activeMembership?.role) === 'manager' &&
    (myMember?.status || groups.activeMembership?.status) === 'approved';

  return (
    <MealContext.Provider value={{
      ...groups,          // memberships, approved, pending, activeMembership, switchGroup, createGroup, joinByCode, leaveGroup, fetchMemberships, loading
      groupId,
      year, month, shiftMonth,
      data,
      isManager,
      currentUserId: user?.id
    }}>
      {children}
    </MealContext.Provider>
  );
}

export function useMeal() {
  return useContext(MealContext);
}
