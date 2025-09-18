-- Ensure new equipment starts with streak 0 by setting proper defaults
ALTER TABLE equipment ALTER COLUMN current_streak SET DEFAULT 0;
ALTER TABLE equipment ALTER COLUMN best_streak SET DEFAULT 0;

-- The trigger logic is already correct - it sets streak to 1 on first cleaning
-- Just need to make sure any existing equipment without cleanings has streak 0
UPDATE equipment 
SET current_streak = 0, best_streak = 0 
WHERE id NOT IN (
  SELECT DISTINCT equipment_id 
  FROM cleaning_logs
);