-- Fix the streak calculation logic to be based on cleaning frequency schedules
-- The streak should increase when equipment is cleaned within its due schedule

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
  next_due_date DATE;
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
  IF equipment_record.next_cleaning_due IS NOT NULL THEN
    -- Check if cleaning is done on or before the due date
    is_on_schedule := cleaned_date <= DATE(equipment_record.next_cleaning_due);
  ELSE
    -- If no previous due date, this is the first cleaning - always on schedule
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
  
  -- Calculate next cleaning due date
  next_due_date := cleaned_date + equipment_record.cleaning_frequency_days;
  
  -- Update equipment table
  UPDATE public.equipment 
  SET 
    current_streak = new_streak,
    best_streak = GREATEST(best_streak, new_streak),
    last_streak_date = cleaned_date,
    last_cleaned_at = NEW.cleaned_at,
    next_cleaning_due = (cleaned_date + equipment_record.cleaning_frequency_days)::timestamp + interval '23 hours 59 minutes',
    updated_at = now()
  WHERE id = NEW.equipment_id;
  
  RETURN NEW;
END;
$function$;