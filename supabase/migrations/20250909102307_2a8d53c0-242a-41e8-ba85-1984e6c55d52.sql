-- Add triggers for automatic push notifications

-- Trigger for post likes
CREATE OR REPLACE FUNCTION public.send_like_push_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- Only send push notification if the liker is not the post owner
  IF NEW.user_id != (SELECT user_id FROM public.posts WHERE id = NEW.post_id) THEN
    -- Insert into notifications table first (this will trigger the existing notification)
    -- Then send push notification via edge function
    PERFORM pg_notify('push_notification', json_build_object(
      'user_id', (SELECT user_id FROM public.posts WHERE id = NEW.post_id),
      'title', 'Post Liked',
      'body', (SELECT COALESCE(display_name, username) FROM public.profiles WHERE user_id = NEW.user_id) || ' liked your post',
      'data', json_build_object(
        'type', 'like',
        'post_id', NEW.post_id,
        'liker_id', NEW.user_id
      )
    )::text);
  END IF;
  
  RETURN NEW;
END;
$function$;

-- Trigger for post comments
CREATE OR REPLACE FUNCTION public.send_comment_push_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- Only send push notification if the commenter is not the post owner
  IF NEW.user_id != (SELECT user_id FROM public.posts WHERE id = NEW.post_id) THEN
    PERFORM pg_notify('push_notification', json_build_object(
      'user_id', (SELECT user_id FROM public.posts WHERE id = NEW.post_id),
      'title', 'New Comment',
      'body', (SELECT COALESCE(display_name, username) FROM public.profiles WHERE user_id = NEW.user_id) || ' commented on your post',
      'data', json_build_object(
        'type', 'comment',
        'post_id', NEW.post_id,
        'comment_id', NEW.id,
        'commenter_id', NEW.user_id
      )
    )::text);
  END IF;
  
  RETURN NEW;
END;
$function$;

-- Trigger for follows
CREATE OR REPLACE FUNCTION public.send_follow_push_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM pg_notify('push_notification', json_build_object(
    'user_id', NEW.following_id,
    'title', 'New Follower',
    'body', (SELECT COALESCE(display_name, username) FROM public.profiles WHERE user_id = NEW.follower_id) || ' started following you',
    'data', json_build_object(
      'type', 'follow',
      'follower_id', NEW.follower_id
    )
  )::text);
  
  RETURN NEW;
END;
$function$;

-- Trigger for event likes
CREATE OR REPLACE FUNCTION public.send_event_like_push_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- Only send push notification if the liker is not the event owner
  IF NEW.user_id != (SELECT user_id FROM public.events WHERE id = NEW.event_id) THEN
    PERFORM pg_notify('push_notification', json_build_object(
      'user_id', (SELECT user_id FROM public.events WHERE id = NEW.event_id),
      'title', 'Event Liked',
      'body', (SELECT COALESCE(display_name, username) FROM public.profiles WHERE user_id = NEW.user_id) || ' liked your event',
      'data', json_build_object(
        'type', 'event_like',
        'event_id', NEW.event_id,
        'liker_id', NEW.user_id
      )
    )::text);
  END IF;
  
  RETURN NEW;
END;
$function$;

-- Create the actual triggers
DROP TRIGGER IF EXISTS send_like_push_notification_trigger ON public.post_likes;
CREATE TRIGGER send_like_push_notification_trigger
  AFTER INSERT ON public.post_likes
  FOR EACH ROW
  EXECUTE FUNCTION public.send_like_push_notification();

DROP TRIGGER IF EXISTS send_comment_push_notification_trigger ON public.post_comments;
CREATE TRIGGER send_comment_push_notification_trigger
  AFTER INSERT ON public.post_comments
  FOR EACH ROW
  EXECUTE FUNCTION public.send_comment_push_notification();

DROP TRIGGER IF EXISTS send_follow_push_notification_trigger ON public.followers;
CREATE TRIGGER send_follow_push_notification_trigger
  AFTER INSERT ON public.followers
  FOR EACH ROW
  EXECUTE FUNCTION public.send_follow_push_notification();

DROP TRIGGER IF EXISTS send_event_like_push_notification_trigger ON public.event_likes;
CREATE TRIGGER send_event_like_push_notification_trigger
  AFTER INSERT ON public.event_likes
  FOR EACH ROW
  EXECUTE FUNCTION public.send_event_like_push_notification();