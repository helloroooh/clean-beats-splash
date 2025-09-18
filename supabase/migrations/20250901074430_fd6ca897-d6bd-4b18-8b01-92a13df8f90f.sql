-- Fix search path security warnings by updating existing functions
-- Update all functions to have explicit search_path set to 'public'

-- Fix reset_overdue_streaks function
CREATE OR REPLACE FUNCTION public.reset_overdue_streaks()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  -- Reset current_streak to 0 for equipment that is overdue
  UPDATE public.equipment
  SET current_streak = 0
  WHERE next_cleaning_due < NOW()
  AND current_streak > 0;
END;
$$;

-- Fix update_updated_at_column function  
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;