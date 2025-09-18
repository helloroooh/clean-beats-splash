-- Drop and recreate the trigger to ensure it uses the updated function
DROP TRIGGER IF EXISTS trigger_update_equipment_streak ON cleaning_logs;

-- Recreate the update_equipment_streak function with better date handling
CREATE OR REPLACE FUNCTION public.update_equipment_streak()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  equipment_record RECORD;
  days_between INTEGER;
  new_streak INTEGER;
  cleaned_date DATE;
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
  
  -- Calculate new streak
  IF equipment_record.last_streak_date IS NULL THEN
    -- First time cleaning, start streak at 1
    new_streak := 1;
  ELSE
    -- Calculate days between last streak date and cleaning date
    days_between := cleaned_date - equipment_record.last_streak_date;
    
    IF days_between = 1 THEN
      -- Consecutive day, increment streak
      new_streak := equipment_record.current_streak + 1;
    ELSIF days_between = 0 THEN
      -- Same day, maintain streak
      new_streak := equipment_record.current_streak;
    ELSE
      -- Gap in days, reset streak to 1
      new_streak := 1;
    END IF;
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
    next_cleaning_due = NEW.cleaned_at + (cleaning_frequency_days || ' days')::INTERVAL,
    updated_at = now()
  WHERE id = NEW.equipment_id;
  
  RETURN NEW;
END;
$function$;

-- Recreate the trigger
CREATE TRIGGER trigger_update_equipment_streak
    BEFORE INSERT ON cleaning_logs
    FOR EACH ROW
    EXECUTE FUNCTION update_equipment_streak();