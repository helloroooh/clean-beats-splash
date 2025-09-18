-- Fix the search_path for the newly created functions
-- Function to create notification for event likes
CREATE OR REPLACE FUNCTION public.create_event_like_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Only create notification if the liker is not the event owner
  IF NEW.user_id != (SELECT user_id FROM public.events WHERE id = NEW.event_id) THEN
    INSERT INTO public.notifications (user_id, type, title, message, data)
    SELECT 
      e.user_id,
      'event_like',
      'Event Liked',
      (SELECT COALESCE(display_name, username) FROM public.profiles WHERE user_id = NEW.user_id) || ' liked your event',
      jsonb_build_object(
        'event_id', NEW.event_id,
        'liker_id', NEW.user_id,
        'liker_username', (SELECT username FROM public.profiles WHERE user_id = NEW.user_id),
        'liker_display_name', (SELECT display_name FROM public.profiles WHERE user_id = NEW.user_id),
        'liker_avatar_url', (SELECT avatar_url FROM public.profiles WHERE user_id = NEW.user_id)
      )
    FROM public.events e 
    WHERE e.id = NEW.event_id;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Function to create notification for event comments
CREATE OR REPLACE FUNCTION public.create_event_comment_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Only create notification if the commenter is not the event owner
  IF NEW.user_id != (SELECT user_id FROM public.events WHERE id = NEW.event_id) AND NEW.parent_comment_id IS NULL THEN
    INSERT INTO public.notifications (user_id, type, title, message, data)
    SELECT 
      e.user_id,
      'event_comment',
      'New Comment on Event',
      (SELECT COALESCE(display_name, username) FROM public.profiles WHERE user_id = NEW.user_id) || ' commented on your event',
      jsonb_build_object(
        'event_id', NEW.event_id,
        'comment_id', NEW.id,
        'commenter_id', NEW.user_id,
        'commenter_username', (SELECT username FROM public.profiles WHERE user_id = NEW.user_id),
        'commenter_display_name', (SELECT display_name FROM public.profiles WHERE user_id = NEW.user_id),
        'commenter_avatar_url', (SELECT avatar_url FROM public.profiles WHERE user_id = NEW.user_id),
        'comment_content', NEW.content
      )
    FROM public.events e 
    WHERE e.id = NEW.event_id;
  END IF;
  
  RETURN NEW;
END;
$$;