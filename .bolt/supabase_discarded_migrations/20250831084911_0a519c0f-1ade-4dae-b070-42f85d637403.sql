-- Add 'test' to the allowed notification types
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check 
  CHECK (type IN ('follow', 'like', 'comment', 'cleaning_reminder', 'test', 'general'));