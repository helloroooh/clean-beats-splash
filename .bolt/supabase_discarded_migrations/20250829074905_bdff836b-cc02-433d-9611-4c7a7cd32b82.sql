-- Fix security warnings by setting search_path for functions
CREATE OR REPLACE FUNCTION public.create_follow_notification()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Get follower's profile info
  INSERT INTO public.notifications (user_id, type, title, message, data)
  SELECT 
    NEW.following_id,
    'follow',
    'New Follower',
    (SELECT COALESCE(display_name, username) FROM public.profiles WHERE user_id = NEW.follower_id) || ' started following you',
    jsonb_build_object(
      'follower_id', NEW.follower_id,
      'follower_username', (SELECT username FROM public.profiles WHERE user_id = NEW.follower_id),
      'follower_display_name', (SELECT display_name FROM public.profiles WHERE user_id = NEW.follower_id),
      'follower_avatar_url', (SELECT avatar_url FROM public.profiles WHERE user_id = NEW.follower_id)
    );
  
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_like_notification()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only create notification if the liker is not the post owner
  IF NEW.user_id != (SELECT user_id FROM public.posts WHERE id = NEW.post_id) THEN
    INSERT INTO public.notifications (user_id, type, title, message, data)
    SELECT 
      p.user_id,
      'like',
      'Post Liked',
      (SELECT COALESCE(display_name, username) FROM public.profiles WHERE user_id = NEW.user_id) || ' liked your post',
      jsonb_build_object(
        'post_id', NEW.post_id,
        'liker_id', NEW.user_id,
        'liker_username', (SELECT username FROM public.profiles WHERE user_id = NEW.user_id),
        'liker_display_name', (SELECT display_name FROM public.profiles WHERE user_id = NEW.user_id),
        'liker_avatar_url', (SELECT avatar_url FROM public.profiles WHERE user_id = NEW.user_id)
      )
    FROM public.posts p 
    WHERE p.id = NEW.post_id;
  END IF;
  
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_comment_notification()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only create notification if the commenter is not the post owner
  IF NEW.user_id != (SELECT user_id FROM public.posts WHERE id = NEW.post_id) THEN
    INSERT INTO public.notifications (user_id, type, title, message, data)
    SELECT 
      p.user_id,
      'comment',
      'New Comment',
      (SELECT COALESCE(display_name, username) FROM public.profiles WHERE user_id = NEW.user_id) || ' commented on your post',
      jsonb_build_object(
        'post_id', NEW.post_id,
        'comment_id', NEW.id,
        'commenter_id', NEW.user_id,
        'commenter_username', (SELECT username FROM public.profiles WHERE user_id = NEW.user_id),
        'commenter_display_name', (SELECT display_name FROM public.profiles WHERE user_id = NEW.user_id),
        'commenter_avatar_url', (SELECT avatar_url FROM public.profiles WHERE user_id = NEW.user_id),
        'comment_content', NEW.content
      )
    FROM public.posts p 
    WHERE p.id = NEW.post_id;
  END IF;
  
  RETURN NEW;
END;
$$;