import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useEntity } from '../context/EntityContext';

const DEFAULT_CATEGORIES = [
  { name: 'Salary', type: 'income', icon: '💰', color: '#10b981' },
  { name: 'Freelance', type: 'income', icon: '💻', color: '#06b6d4' },
  { name: 'Investment', type: 'income', icon: '📈', color: '#8b5cf6' },
  { name: 'Gift', type: 'income', icon: '🎁', color: '#f59e0b' },
  { name: 'Other Income', type: 'income', icon: '💵', color: '#6366f1' },
  { name: 'Food', type: 'expense', icon: '🍔', color: '#ef4444' },
  { name: 'Transport', type: 'expense', icon: '🚗', color: '#f97316' },
  { name: 'Shopping', type: 'expense', icon: '🛍️', color: '#ec4899' },
  { name: 'Bills', type: 'expense', icon: '📄', color: '#f59e0b' },
  { name: 'Entertainment', type: 'expense', icon: '🎮', color: '#8b5cf6' },
  { name: 'Health', type: 'expense', icon: '🏥', color: '#14b8a6' },
  { name: 'Education', type: 'expense', icon: '📚', color: '#6366f1' },
  { name: 'Rent', type: 'expense', icon: '🏠', color: '#0ea5e9' },
  { name: 'Other Expense', type: 'expense', icon: '💸', color: '#64748b' },
];

// Entities that already had defaults seeded in this session (module-level so
// every component instance of the hook shares it)
const seededEntities = new Set();

export function useCategories() {
  const { user } = useAuth();
  const { currentEntity } = useEntity();
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchCategories = useCallback(async () => {
    if (!user || !currentEntity) return;
    setLoading(true);
    const { data, error } = await supabase
      .from('categories')
      .select('*')
      .eq('user_id', user.id)
      .eq('entity_id', currentEntity.id)
      .order('name');
    
    if (error) {
      console.error('Error fetching categories:', error);
    } else {
      setCategories(data || []);
    }
    setLoading(false);
  }, [user, currentEntity]);

  const seedDefaults = useCallback(async () => {
    if (!user || !currentEntity) return;
    // Guard against concurrent mounts (Dashboard + Transactions both use this
    // hook) racing to seed the same entity twice
    if (seededEntities.has(currentEntity.id)) return;
    seededEntities.add(currentEntity.id);
    const inserts = DEFAULT_CATEGORIES.map(c => ({
      ...c,
      user_id: user.id,
      entity_id: currentEntity.id,
      is_default: true
    }));
    const { error } = await supabase.from('categories').insert(inserts);
    if (!error) await fetchCategories();
  }, [user, currentEntity, fetchCategories]);

  useEffect(() => {
    if (user) fetchCategories();
  }, [user, fetchCategories]);

  useEffect(() => {
    if (!loading && categories.length === 0 && user) {
      seedDefaults();
    }
  }, [loading, categories.length, user, seedDefaults]);

  const addCategory = async (category) => {
    const { data, error } = await supabase
      .from('categories')
      .insert({ ...category, user_id: user.id, entity_id: currentEntity.id })
      .select()
      .single();
    if (error) throw error;
    setCategories(prev => [...prev, data]);
    return data;
  };

  const updateCategory = async (id, updates) => {
    const { data, error } = await supabase
      .from('categories')
      .update(updates)
      .eq('id', id)
      .eq('user_id', user.id)
      .select()
      .single();
    if (error) throw error;
    setCategories(prev => prev.map(c => c.id === id ? data : c));
    return data;
  };

  const deleteCategory = async (id) => {
    const { error } = await supabase
      .from('categories')
      .delete()
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) throw error;
    setCategories(prev => prev.filter(c => c.id !== id));
  };

  return { categories, loading, fetchCategories, addCategory, updateCategory, deleteCategory };
}
