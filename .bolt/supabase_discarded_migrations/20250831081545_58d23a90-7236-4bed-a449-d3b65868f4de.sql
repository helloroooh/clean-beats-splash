-- Create a function to get the global top streaks from all users
CREATE OR REPLACE FUNCTION public.get_global_top_streaks(p_limit integer DEFAULT 10)
RETURNS TABLE(user_id uuid, username text, display_name text, avatar_url text, best_streak integer, equipment_name text)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  WITH user_streaks AS (
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
    WHERE e.best_streak > 0
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
  ORDER BY us.best_streak DESC, us.user_id
  LIMIT p_limit;
$function$;