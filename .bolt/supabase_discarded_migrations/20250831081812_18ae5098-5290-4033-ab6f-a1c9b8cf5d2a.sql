-- Let's test the streak calculation with a manual cleaning log for consecutive days
-- This will help verify the streak logic is working

-- First, let's see what happens if we manually insert a consecutive day cleaning
-- Insert a cleaning for today for testing purposes
INSERT INTO cleaning_logs (equipment_id, user_id, cleaned_at, notes)
SELECT 
  id as equipment_id,
  user_id,
  CURRENT_DATE::timestamp + interval '12 hours' as cleaned_at,
  'Test consecutive day cleaning'
FROM equipment 
WHERE name = 'Fender' 
LIMIT 1;