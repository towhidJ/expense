import { createContext, useContext, useEffect, useState, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from './AuthContext';
import { useEntity } from './EntityContext';

const AccountContext = createContext();

export const useAccounts = () => useContext(AccountContext);

export function AccountProvider({ children }) {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [accounts, setAccounts] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchAccounts = useCallback(async () => {
    if (!user || !currentEntity) {
      setAccounts([]);
      setLoading(false);
      return;
    }
    
    setLoading(true);
    const { data, error } = await supabase
      .from('accounts')
      .select('*')
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .order('name', { ascending: true });

    if (error) {
      console.error('Error fetching accounts:', error);
    } else {
      setAccounts(data || []);
    }
    setLoading(false);
  }, [user, currentEntity]);

  useEffect(() => {
    fetchAccounts();
  }, [fetchAccounts]);

  const addAccount = async (account) => {
    const { data, error } = await supabase
      .from('accounts')
      .insert({ 
        ...account, 
        user_id: user.id,
        entity_id: currentEntity.id 
      })
      .select()
      .single();
    
    if (error) throw error;
    setAccounts([...accounts, data]);
    return data;
  };

  const updateAccount = async (id, updates) => {
    const { data, error } = await supabase
      .from('accounts')
      .update(updates)
      .eq('id', id)
      .eq('user_id', user.id)
      .select()
      .single();
      
    if (error) throw error;
    setAccounts(accounts.map(a => a.id === id ? data : a));
    return data;
  };

  const deleteAccount = async (id) => {
    const { error } = await supabase
      .from('accounts')
      .delete()
      .eq('id', id)
      .eq('user_id', user.id);
      
    if (error) throw error;
    setAccounts(accounts.filter(a => a.id !== id));
  };

  return (
    <AccountContext.Provider value={{ accounts, loading, fetchAccounts, addAccount, updateAccount, deleteAccount }}>
      {children}
    </AccountContext.Provider>
  );
}
