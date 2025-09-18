-- Fix the streak reset logic - missed deadline should reset to 0, not 1
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
  previous_cleaning_count INTEGER;
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
  
  -- Count previous cleaning logs for this equipment (excluding current one)
  SELECT COUNT(*) INTO previous_cleaning_count 
  FROM public.cleaning_logs 
  WHERE equipment_id = NEW.equipment_id 
  AND id != NEW.id;
  
  -- If this is the very first cleaning, start streak at 1
  IF previous_cleaning_count = 0 THEN
    new_streak := 1;
    is_on_schedule := true;
  ELSE
    -- Calculate if this cleaning is on schedule
    IF equipment_record.last_cleaned_at IS NOT NULL THEN
      -- Calculate expected next cleaning date based on last cleaning + frequency
      expected_next_date := DATE(equipment_record.last_cleaned_at) + equipment_record.cleaning_frequency_days;
      -- Check if cleaning is done on or before the expected date
      is_on_schedule := cleaned_date <= expected_next_date;
    ELSE
      -- If no previous cleaning recorded, this is effectively the first - start at 1
      is_on_schedule := true;
    END IF;
    
    -- Calculate new streak based on schedule adherence
    IF is_on_schedule THEN
      -- On schedule: increment streak
      new_streak := equipment_record.current_streak + 1;
    ELSE
      -- Missed schedule: reset streak to 0, then this cleaning makes it 1
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
    next_cleaning_due = (cleaned_date + cleaning_frequency_days)::timestamp + interval '23 hours 59 minutes',
    updated_at = now()
  WHERE id = NEW.equipment_id;
  
  RETURN NEW;
END;
$function$;

-- Also need a function to reset streaks when deadlines are missed without cleaning
-- This should run periodically to reset overdue equipment streaks to 0
CREATE OR REPLACE FUNCTION public.reset_overdue_streaks()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- Reset current_streak to 0 for equipment that is overdue
  UPDATE public.equipment
  SET current_streak = 0
  WHERE next_cleaning_due < NOW()
  AND current_streak > 0;
END;
$function$;