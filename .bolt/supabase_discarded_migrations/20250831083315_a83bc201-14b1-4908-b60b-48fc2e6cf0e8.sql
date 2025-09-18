-- Fix the drums equipment streak to be correct (should be 2, not 3)
-- Based on the cleaning logs, there are 2 cleanings within the frequency schedule

UPDATE equipment 
SET 
  current_streak = 2,
  best_streak = GREATEST(best_streak, 2),
  updated_at = now()
WHERE name = 'Drums';

-- Also update the cleaning log that shows incorrect streak_after_cleaning
UPDATE cleaning_logs 
SET streak_after_cleaning = 2
WHERE cleaned_at = '2025-08-31 06:28:00+00' 
AND equipment_id = (SELECT id FROM equipment WHERE name = 'Drums');