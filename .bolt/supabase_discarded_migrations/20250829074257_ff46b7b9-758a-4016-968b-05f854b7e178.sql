-- Create notifications table
CREATE TABLE public.notifications (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('follow', 'like', 'comment', 'cleaning_reminder')),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  data JSONB,
  read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Create policies for notifications
CREATE POLICY "Users can view their own notifications" 
ON public.notifications 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications" 
ON public.notifications 
FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "System can create notifications" 
ON public.notifications 
FOR INSERT 
WITH CHECK (true);

-- Create function to create follow notification
CREATE OR REPLACE FUNCTION public.create_follow_notification()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to create like notification
CREATE OR REPLACE FUNCTION public.create_like_notification()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to create comment notification
CREATE OR REPLACE FUNCTION public.create_comment_notification()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
CREATE TRIGGER on_follow_created
  AFTER INSERT ON public.followers
  FOR EACH ROW EXECUTE FUNCTION public.create_follow_notification();

CREATE TRIGGER on_like_created
  AFTER INSERT ON public.post_likes
  FOR EACH ROW EXECUTE FUNCTION public.create_like_notification();

CREATE TRIGGER on_comment_created
  AFTER INSERT ON public.post_comments
  FOR EACH ROW EXECUTE FUNCTION public.create_comment_notification();

-- Create index for better performance
CREATE INDEX idx_notifications_user_id_created_at ON public.notifications (user_id, created_at DESC);
CREATE INDEX idx_notifications_read ON public.notifications (user_id, read);