-- Fix function search path security issue
CREATE OR REPLACE FUNCTION public.update_next_cleaning_due()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Update next cleaning due date when equipment is updated or cleaning is logged
  IF TG_TABLE_NAME = 'equipment' THEN
    IF NEW.last_cleaned_at IS NOT NULL THEN
      NEW.next_cleaning_due = NEW.last_cleaned_at + (NEW.cleaning_frequency_days || ' days')::INTERVAL;
    ELSE
      NEW.next_cleaning_due = now() + (NEW.cleaning_frequency_days || ' days')::INTERVAL;
    END IF;
    RETURN NEW;
  ELSIF TG_TABLE_NAME = 'cleaning_logs' THEN
    -- Update equipment when a new cleaning log is added
    UPDATE public.equipment 
    SET 
      last_cleaned_at = NEW.cleaned_at,
      next_cleaning_due = NEW.cleaned_at + (cleaning_frequency_days || ' days')::INTERVAL,
      updated_at = now()
    WHERE id = NEW.equipment_id;
    RETURN NEW;
  END IF;
END;
$$;