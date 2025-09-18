-- Fix the Fender equipment streak calculation
-- Clean up duplicate logs and set correct streak

-- First, let's clean up any duplicate cleaning logs for the same day
WITH ranked_logs AS (
  SELECT cl.id, cl.equipment_id, cl.cleaned_at,
         ROW_NUMBER() OVER (PARTITION BY cl.equipment_id, DATE(cl.cleaned_at) ORDER BY cl.cleaned_at DESC) as rn
  FROM cleaning_logs cl
  JOIN equipment e ON cl.equipment_id = e.id  
  WHERE e.name = 'Fender'
)
DELETE FROM cleaning_logs 
WHERE id IN (
  SELECT id FROM ranked_logs WHERE rn > 1
);

-- Set the correct streak for Fender: cleaned on 29th and 31st with 2-day frequency = streak of 2
UPDATE equipment 
SET 
  current_streak = 2,
  best_streak = GREATEST(best_streak, 2),
  last_streak_date = '2025-08-31',
  next_cleaning_due = '2025-09-02 23:59:59',
  updated_at = now()
WHERE name = 'Fender';