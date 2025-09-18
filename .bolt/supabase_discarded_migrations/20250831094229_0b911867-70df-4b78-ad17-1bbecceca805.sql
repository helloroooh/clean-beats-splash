-- Schedule cleaning reminders at 12:00 PM UTC (noon reminders)
SELECT cron.schedule(
  'cleaning-reminders-noon',
  '0 12 * * *', -- Daily at 12:00 PM UTC
  $$
  SELECT
    net.http_post(
        url:='https://zvaslazcmocjditstuxw.supabase.co/functions/v1/scheduled-cleaning-reminders',
        headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp2YXNsYXpjbW9jamRpdHN0dXh3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYzNzQ5MzIsImV4cCI6MjA3MTk1MDkzMn0.LlE4ylI-4prUzZOl5l0vNrxUC2COBOGez5hGYVCoRBc"}'::jsonb,
        body:='{"reminderType": "noon"}'::jsonb
    ) as request_id;
  $$
);

-- Schedule cleaning reminders at 11:30 PM UTC (evening reminders)
SELECT cron.schedule(
  'cleaning-reminders-evening',
  '30 23 * * *', -- Daily at 11:30 PM UTC
  $$
  SELECT
    net.http_post(
        url:='https://zvaslazcmocjditstuxw.supabase.co/functions/v1/scheduled-cleaning-reminders',
        headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp2YXNsYXpjbW9jamRpdHN0dXh3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYzNzQ5MzIsImV4cCI6MjA3MTk1MDkzMn0.LlE4ylI-4prUzZOl5l0vNrxUC2COBOGez5hGYVCoRBc"}'::jsonb,
        body:='{"reminderType": "evening"}'::jsonb
    ) as request_id;
  $$
);

-- Schedule event reminders every 5 minutes to check for upcoming events
SELECT cron.schedule(
  'event-reminders',
  '*/5 * * * *', -- Every 5 minutes
  $$
  SELECT
    net.http_post(
        url:='https://zvaslazcmocjditstuxw.supabase.co/functions/v1/scheduled-event-reminders',
        headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp2YXNsYXpjbW9jamRpdHN0dXh3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYzNzQ5MzIsImV4cCI6MjA3MTk1MDkzMn0.LlE4ylI-4prUzZOl5l0vNrxUC2COBOGez5hGYVCoRBc"}'::jsonb,
        body:='{}'::jsonb
    ) as request_id;
  $$
);