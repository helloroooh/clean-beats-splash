-- Add streak tracking to equipment table
ALTER TABLE public.equipment 
ADD COLUMN current_streak INTEGER NOT NULL DEFAULT 0,
ADD COLUMN best_streak INTEGER NOT NULL DEFAULT 0,
ADD COLUMN last_streak_date DATE;

-- Add streak tracking to cleaning_logs
ALTER TABLE public.cleaning_logs 
ADD COLUMN streak_before_cleaning INTEGER DEFAULT 0,
ADD COLUMN streak_after_cleaning INTEGER DEFAULT 0;

-- Create function to calculate and update streaks
CREATE OR REPLACE FUNCTION public.update_equipment_streak()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = public
AS $$
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
    days_between := EXTRACT(DAY FROM (CURRENT_DATE - equipment_record.last_streak_date));
    
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
$$;

-- Create trigger for streak updates
DROP TRIGGER IF EXISTS on_cleaning_logged ON public.cleaning_logs;
CREATE TRIGGER on_cleaning_logged
  BEFORE INSERT ON public.cleaning_logs
  FOR EACH ROW EXECUTE FUNCTION public.update_equipment_streak();

-- Create function to get user's best streak
CREATE OR REPLACE FUNCTION public.get_user_best_streak(p_user_id UUID)
RETURNS INTEGER 
LANGUAGE sql 
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(MAX(best_streak), 0)
  FROM public.equipment 
  WHERE user_id = p_user_id;
$$;

-- Create function to get top streaks from followed users
CREATE OR REPLACE FUNCTION public.get_following_top_streaks(p_user_id UUID, p_limit INTEGER DEFAULT 5)
RETURNS TABLE(
  user_id UUID,
  username TEXT,
  display_name TEXT,
  avatar_url TEXT,
  best_streak INTEGER,
  equipment_name TEXT
) 
LANGUAGE sql 
SECURITY DEFINER
SET search_path = public
AS $$
  WITH following_users AS (
    SELECT following_id 
    FROM public.followers 
    WHERE follower_id = p_user_id
    UNION
    SELECT p_user_id -- Include the user themselves
  ),
  user_streaks AS (
    SELECT 
      e.user_id,
      p.username,
      p.display_name,
      p.avatar_url,
      e.best_streak,
      e.name as equipment_name,
      ROW_NUMBER() OVER (PARTITION BY e.user_id ORDER BY e.best_streak DESC) as rn
    FROM public.equipment e
    JOIN public.profiles p ON e.user_id = p.user_id
    WHERE e.user_id IN (SELECT following_id FROM following_users)
    AND e.best_streak > 0
  )
  SELECT 
    us.user_id,
    us.username,
    us.display_name,
    us.avatar_url,
    us.best_streak,
    us.equipment_name
  FROM user_streaks us
  WHERE us.rn = 1
  ORDER BY us.best_streak DESC
  LIMIT p_limit;
$$;