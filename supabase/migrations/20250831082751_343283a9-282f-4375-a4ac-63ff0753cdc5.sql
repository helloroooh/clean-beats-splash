-- Fix streak calculation logic for ALL equipment across ALL users
-- This will properly recalculate streaks based on cleaning frequency schedules

CREATE OR REPLACE FUNCTION recalculate_all_equipment_streaks()
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
  is_on_schedule BOOLEAN;
BEGIN
  -- Loop through ALL equipment for ALL users
  FOR equipment_row IN 
    SELECT id, user_id, cleaning_frequency_days, name
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
        -- Calculate expected next cleaning date (last cleaning + frequency)
        expected_next_date := last_cleaning_date + equipment_row.cleaning_frequency_days;
        
        -- Check if current cleaning is on or before the expected date
        is_on_schedule := log_row.cleaned_date <= expected_next_date;
        
        IF is_on_schedule THEN
          -- On schedule: increment streak
          current_streak_calc := current_streak_calc + 1;
        ELSE
          -- Missed schedule: reset streak to 1 (this cleaning starts a new streak)
          current_streak_calc := 1;
        END IF;
        
        last_cleaning_date := log_row.cleaned_date;
      END IF;
      
      -- Track the best streak achieved so far
      best_streak_calc := GREATEST(best_streak_calc, current_streak_calc);
    END LOOP;
    
    -- Check if current streak should be reset to 0 due to missed cleaning
    IF last_cleaning_date IS NOT NULL THEN
      expected_next_date := last_cleaning_date + equipment_row.cleaning_frequency_days;
      -- If we're past the expected next cleaning date, reset current streak to 0
      IF CURRENT_DATE > expected_next_date THEN
        current_streak_calc := 0;
      END IF;
    END IF;
    
    -- Update the equipment with recalculated streaks
    UPDATE equipment 
    SET 
      current_streak = current_streak_calc,
      best_streak = best_streak_calc,
      last_streak_date = last_cleaning_date,
      next_cleaning_due = CASE 
        WHEN last_cleaning_date IS NOT NULL 
        THEN (last_cleaning_date + equipment_row.cleaning_frequency_days)::timestamp + interval '23 hours 59 minutes'
        ELSE NULL 
      END,
      updated_at = now()
    WHERE id = equipment_row.id;
    
    RAISE NOTICE 'Updated equipment %: current_streak=%, best_streak=%', equipment_row.name, current_streak_calc, best_streak_calc;
  END LOOP;
END;
$function$;

-- Execute the recalculation for ALL equipment
SELECT recalculate_all_equipment_streaks();

-- Update the trigger to use the same logic for future cleanings
CREATE OR REPLACE FUNCTION public.update_equipment_streak()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  equipment_record RECORD;
  new_streak INTEGER;
  cleaned_date DATE;
  expected_next_date DATE;
  is_on_schedule BOOLEAN := false;
BEGIN
  -- Get the equipment record
  SELECT * INTO equipment_record 
  FROM public.equipment 
  WHERE id = NEW.equipment_id;
  
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;
  
  -- Store current streak before cleaning
  NEW.streak_before_cleaning := equipment_record.current_streak;
  
  -- Get the date part of the cleaned_at timestamp
  cleaned_date := DATE(NEW.cleaned_at);
  
  -- Calculate if this cleaning is on schedule
  IF equipment_record.last_cleaned_at IS NOT NULL THEN
    -- Calculate expected next cleaning date based on last cleaning + frequency
    expected_next_date := DATE(equipment_record.last_cleaned_at) + equipment_record.cleaning_frequency_days;
    -- Check if cleaning is done on or before the expected date
    is_on_schedule := cleaned_date <= expected_next_date;
  ELSE
    -- If no previous cleaning, this is the first cleaning - always on schedule
    is_on_schedule := true;
  END IF;
  
  -- Calculate new streak based on schedule adherence
  IF is_on_schedule THEN
    -- On schedule: increment streak
    new_streak := equipment_record.current_streak + 1;
  ELSE
    -- Missed schedule: reset streak to 1 (this cleaning starts a new streak)
    new_streak := 1;
  END IF;
  
  -- Store new streak after cleaning
  NEW.streak_after_cleaning := new_streak;
  
  -- Update equipment table
  UPDATE public.equipment 
  SET 
    current_streak = new_streak,
    best_streak = GREATEST(best_streak, new_streak),
    last_streak_date = cleaned_date,
    last_cleaned_at = NEW.cleaned_at,
    next_cleaning_due = (cleaned_date + cleaning_frequency_days)::timestamp + interval '23 hours 59 minutes',
    updated_at = now()
  WHERE id = NEW.equipment_id;
  
  RETURN NEW;
END;
$function$;

-- Drop the temporary function
DROP FUNCTION recalculate_all_equipment_streaks();