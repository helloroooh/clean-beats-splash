-- Fix the get_following_top_streaks function to include the user themselves
CREATE OR REPLACE FUNCTION public.get_following_top_streaks(p_user_id uuid, p_limit integer DEFAULT 5)
 RETURNS TABLE(user_id uuid, username text, display_name text, avatar_url text, best_streak integer, equipment_name text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  WITH following_users AS (
    SELECT following_id 
    FROM public.followers 
    WHERE follower_id = p_user_id
    UNION
    SELECT follower_id
    FROM public.followers 
    WHERE following_id = p_user_id
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
$function$;

-- Create a function to get global rank for a user
CREATE OR REPLACE FUNCTION public.get_user_global_rank(p_user_id uuid)
 RETURNS TABLE(rank_position integer, total_users integer)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  WITH user_best_streaks AS (
    SELECT 
      e.user_id,
      MAX(e.best_streak) as best_streak
    FROM public.equipment e
    GROUP BY e.user_id
  ),
  ranked_users AS (
    SELECT 
      user_id,
      best_streak,
      ROW_NUMBER() OVER (ORDER BY best_streak DESC, user_id) as rank
    FROM user_best_streaks
  )
  SELECT 
    COALESCE(r.rank, (SELECT COUNT(*) FROM public.profiles) + 1)::integer as rank_position,
    (SELECT COUNT(*) FROM public.profiles)::integer as total_users
  FROM ranked_users r
  WHERE r.user_id = p_user_id
  UNION ALL
  SELECT 
    (SELECT COUNT(*) FROM public.profiles)::integer as rank_position,
    (SELECT COUNT(*) FROM public.profiles)::integer as total_users
  WHERE NOT EXISTS (SELECT 1 FROM ranked_users WHERE user_id = p_user_id)
  LIMIT 1;
$function$;