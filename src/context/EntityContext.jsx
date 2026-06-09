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
        if (data.length > 0 && !currentEntity) {
          // Default to the first entity (usually 'Personal')
          setCurrentEntity(data[0]);
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

  return (
    <EntityContext.Provider value={{ entities, currentEntity, loading, switchEntity, addEntity }}>
      {children}
    </EntityContext.Provider>
  );
}
