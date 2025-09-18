-- Recalculate all equipment streaks based on the new frequency-based logic
-- This will update existing equipment to reflect proper schedule-based streaks

-- First, let's create a function to recalculate streaks for all equipment
CREATE OR REPLACE FUNCTION recalculate_all_streaks()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  equipment_row RECORD;
  log_row RECORD;
  current_streak_calc INTEGER := 0;
  best_streak_calc INTEGER := 0;
  last_cleaning_date DATE;
  expected_next_date DATE;
BEGIN
  -- Loop through all equipment
  FOR equipment_row IN 
    SELECT id, user_id, cleaning_frequency_days 
    FROM equipment 
  LOOP
    current_streak_calc := 0;
    best_streak_calc := 0;
    last_cleaning_date := NULL;
    
    -- Loop through cleaning logs for this equipment in chronological order
    FOR log_row IN 
      SELECT cleaned_at::date as cleaned_date
      FROM cleaning_logs 
      WHERE equipment_id = equipment_row.id 
      ORDER BY cleaned_at
    LOOP
      IF last_cleaning_date IS NULL THEN
        -- First cleaning always starts streak at 1
        current_streak_calc := 1;
        last_cleaning_date := log_row.cleaned_date;
      ELSE
        -- Calculate expected next cleaning date
        expected_next_date := last_cleaning_date + equipment_row.cleaning_frequency_days;
        
        IF log_row.cleaned_date <= expected_next_date THEN
          -- On schedule: increment streak
          current_streak_calc := current_streak_calc + 1;
        ELSE
          -- Missed schedule: reset streak to 1
          current_streak_calc := 1;
        END IF;
        
        last_cleaning_date := log_row.cleaned_date;
      END IF;
      
      -- Track the best streak achieved
      best_streak_calc := GREATEST(best_streak_calc, current_streak_calc);
    END LOOP;
    
    -- Update the equipment with recalculated streaks
    UPDATE equipment 
    SET 
      current_streak = current_streak_calc,
      best_streak = best_streak_calc,
      last_streak_date = last_cleaning_date,
      updated_at = now()
    WHERE id = equipment_row.id;
  END LOOP;
END;
$function$;

-- Execute the recalculation
SELECT recalculate_all_streaks();

-- Drop the temporary function
DROP FUNCTION recalculate_all_streaks();