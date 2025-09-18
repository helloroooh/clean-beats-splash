-- Fix the update_equipment_streak function to handle date extraction properly
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
  
  -- Calculate new streak
  IF equipment_record.last_streak_date IS NULL THEN
    -- First time cleaning, start streak at 1
    new_streak := 1;
  ELSE
    -- Calculate days between last streak date and today
    -- Fix the type casting issue by explicitly casting to date
    days_between := EXTRACT(DAY FROM (CURRENT_DATE::date - equipment_record.last_streak_date::date));
    
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
    last_streak_date = CURRENT_DATE,
    last_cleaned_at = NEW.cleaned_at,
    next_cleaning_due = NEW.cleaned_at + (cleaning_frequency_days || ' days')::INTERVAL,
    updated_at = now()
  WHERE id = NEW.equipment_id;
  
  RETURN NEW;
END;
$function$;