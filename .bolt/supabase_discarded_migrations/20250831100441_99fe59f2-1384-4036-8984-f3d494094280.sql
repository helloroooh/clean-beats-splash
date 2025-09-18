-- Update the cleaning reminder cron jobs to use user timezones
-- First, let's create a function that will calculate the correct time for each user

-- Update the scheduled cleaning reminders edge function to be timezone-aware
-- The edge function will need to check each user's timezone and send reminders accordingly

-- For now, let's create a more sophisticated cron setup that checks multiple times per day
-- and the edge function will handle timezone calculations

-- Remove existing cron jobs
SELECT cron.unschedule('cleaning-reminders-noon');
SELECT cron.unschedule('cleaning-reminders-evening');

-- Create new cron jobs that run every hour to check for users in different timezones
SELECT cron.schedule(
  'cleaning-reminders-hourly-noon',
  '0 * * * *', -- every hour
  $$
  SELECT
    net.http_post(
        url:='https://zvaslazcmocjditstuxw.supabase.co/functions/v1/scheduled-cleaning-reminders',
        headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp2YXNsYXpjbW9jamRpdHN0dXh3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYzNzQ5MzIsImV4cCI6MjA3MTk1MDkzMn0.LlE4ylI-4prUzZOl5l0vNrxUC2COBOGez5hGYVCoRBc"}'::jsonb,
        body:='{"reminderType": "noon", "checkHour": true}'::jsonb
    ) as request_id;
  $$
);

SELECT cron.schedule(
  'cleaning-reminders-hourly-evening',
  '30 * * * *', -- every hour at 30 minutes past
  $$
  SELECT
    net.http_post(
        url:='https://zvaslazcmocjditstuxw.supabase.co/functions/v1/scheduled-cleaning-reminders',
        headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp2YXNsYXpjbW9jamRpdHN0dXh3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYzNzQ5MzIsImV4cCI6MjA3MTk1MDkzMn0.LlE4ylI-4prUzZOl5l0vNrxUC2COBOGez5hGYVCoRBc"}'::jsonb,
        body:='{"reminderType": "evening", "checkHour": true}'::jsonb
    ) as request_id;
  $$
);