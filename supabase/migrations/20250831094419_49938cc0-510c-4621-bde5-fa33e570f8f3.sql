-- Add reply support to post_comments table
ALTER TABLE public.post_comments 
ADD COLUMN parent_comment_id UUID REFERENCES public.post_comments(id) ON DELETE CASCADE;

-- Add reply support to event_comments table  
ALTER TABLE public.event_comments 
ADD COLUMN parent_comment_id UUID REFERENCES public.event_comments(id) ON DELETE CASCADE;

-- Create function to handle post comment replies notifications
CREATE OR REPLACE FUNCTION public.create_post_comment_reply_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Only create notification if this is a reply (has parent_comment_id)
  -- and the replier is not the original commenter
  IF NEW.parent_comment_id IS NOT NULL THEN
    -- Get the original commenter's user_id
    DECLARE
      original_commenter_id UUID;
    BEGIN
      SELECT user_id INTO original_commenter_id 
      FROM public.post_comments 
      WHERE id = NEW.parent_comment_id;
      
      -- Only notify if the replier is different from the original commenter
      IF NEW.user_id != original_commenter_id THEN
        INSERT INTO public.notifications (user_id, type, title, message, data)
        SELECT 
          original_commenter_id,
          'comment_reply',
          'Reply to Your Comment',
          (SELECT COALESCE(display_name, username) FROM public.profiles WHERE user_id = NEW.user_id) || ' replied to your comment',
          jsonb_build_object(
            'post_id', NEW.post_id,
            'comment_id', NEW.id,
            'parent_comment_id', NEW.parent_comment_id,
            'replier_id', NEW.user_id,
            'replier_username', (SELECT username FROM public.profiles WHERE user_id = NEW.user_id),
            'replier_display_name', (SELECT display_name FROM public.profiles WHERE user_id = NEW.user_id),
            'replier_avatar_url', (SELECT avatar_url FROM public.profiles WHERE user_id = NEW.user_id),
            'reply_content', NEW.content
          );
      END IF;
    END;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to handle event comment replies notifications
CREATE OR REPLACE FUNCTION public.create_event_comment_reply_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Only create notification if this is a reply (has parent_comment_id)
  -- and the replier is not the original commenter
  IF NEW.parent_comment_id IS NOT NULL THEN
    -- Get the original commenter's user_id
    DECLARE
      original_commenter_id UUID;
    BEGIN
      SELECT user_id INTO original_commenter_id 
      FROM public.event_comments 
      WHERE id = NEW.parent_comment_id;
      
      -- Only notify if the replier is different from the original commenter
      IF NEW.user_id != original_commenter_id THEN
        INSERT INTO public.notifications (user_id, type, title, message, data)
        SELECT 
          original_commenter_id,
          'comment_reply',
          'Reply to Your Comment',
          (SELECT COALESCE(display_name, username) FROM public.profiles WHERE user_id = NEW.user_id) || ' replied to your comment',
          jsonb_build_object(
            'event_id', NEW.event_id,
            'comment_id', NEW.id,
            'parent_comment_id', NEW.parent_comment_id,
            'replier_id', NEW.user_id,
            'replier_username', (SELECT username FROM public.profiles WHERE user_id = NEW.user_id),
            'replier_display_name', (SELECT display_name FROM public.profiles WHERE user_id = NEW.user_id),
            'replier_avatar_url', (SELECT avatar_url FROM public.profiles WHERE user_id = NEW.user_id),
            'reply_content', NEW.content
          );
      END IF;
    END;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers for comment reply notifications
CREATE TRIGGER post_comment_reply_notification_trigger
  AFTER INSERT ON public.post_comments
  FOR EACH ROW
  EXECUTE FUNCTION public.create_post_comment_reply_notification();

CREATE TRIGGER event_comment_reply_notification_trigger
  AFTER INSERT ON public.event_comments
  FOR EACH ROW
  EXECUTE FUNCTION public.create_event_comment_reply_notification();