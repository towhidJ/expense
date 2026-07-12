import { createContext, useContext, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from './AuthContext';

const EntityContext = createContext();

export const useEntity = () => useContext(EntityContext);

export function EntityProvider({ children }) {
  const { user } = useAuth();
  const [entities, setEntities] = useState([]);
  const [currentEntity, setCurrentEntity] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!user) {
      setEntities([]);
      setCurrentEntity(null);
      setLoading(false);
      return;
    }

    const fetchEntities = async () => {
      setLoading(true);
      const { data, error } = await supabase
        .from('entities')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', { ascending: true });

      if (error) {
        console.error('Error fetching entities:', error);
      } else if (data) {
        setEntities(data);
        if (data.length > 0) {
          setCurrentEntity(prev => {
            if (prev && data.some(e => e.id === prev.id)) return prev;
            const savedId = localStorage.getItem('currentEntityId');
            return data.find(e => e.id === savedId) || data[0];
          });
        }
      }
      setLoading(false);
    };

    fetchEntities();
  }, [user]);

  const switchEntity = (entityId) => {
    const entity = entities.find(e => e.id === entityId);
    if (entity) {
      setCurrentEntity(entity);
      localStorage.setItem('currentEntityId', entity.id);
    }
  };

  const addEntity = async (entity) => {
    const { data, error } = await supabase
      .from('entities')
      .insert({ ...entity, user_id: user.id })
      .select()
      .single();

    if (error) throw error;
    setEntities([...entities, data]);
    return data;
  };

  const updateEntity = async (id, patch) => {
    const { data, error } = await supabase
      .from('entities')
      .update(patch)
      .eq('id', id)
      .eq('user_id', user.id)
      .select()
      .single();
    if (error) throw error;
    setEntities(prev => prev.map(e => (e.id === id ? data : e)));
    setCurrentEntity(prev => (prev?.id === id ? data : prev));
    return data;
  };

  // Wipes the workspace and everything in it via the delete_entity RPC
  // (child tables have no ON DELETE CASCADE). Refuses to delete the last one.
  const deleteEntity = async (id) => {
    const { error } = await supabase.rpc('delete_entity', { p_entity_id: id });
    if (error) throw error;
    const remaining = entities.filter(e => e.id !== id);
    setEntities(remaining);
    setCurrentEntity(prev => {
      if (prev?.id !== id) return prev;
      const next = remaining[0] || null;
      if (next) localStorage.setItem('currentEntityId', next.id);
      return next;
    });
  };

  return (
    <EntityContext.Provider value={{ entities, currentEntity, loading, switchEntity, addEntity, updateEntity, deleteEntity }}>
      {children}
    </EntityContext.Provider>
  );
}
