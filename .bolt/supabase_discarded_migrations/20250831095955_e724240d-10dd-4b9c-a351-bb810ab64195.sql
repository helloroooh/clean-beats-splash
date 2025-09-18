-- Add cleaning_reminder to the allowed notification types
ALTER TABLE public.notifications DROP CONSTRAINT notifications_type_check;

ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check 
CHECK (type IN ('follow', 'like', 'comment', 'comment_reply', 'event_like', 'event_comment', 'cleaning_reminder'));