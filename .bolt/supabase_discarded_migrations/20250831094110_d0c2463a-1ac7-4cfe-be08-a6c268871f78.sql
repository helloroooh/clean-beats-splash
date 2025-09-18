-- Enable pg_cron and pg_net extensions for scheduled notifications
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Create a user_timezones table to store user timezone preferences
CREATE TABLE IF NOT EXISTS public.user_timezones (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE,
  timezone TEXT NOT NULL DEFAULT 'UTC',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.user_timezones ENABLE ROW LEVEL SECURITY;

-- Create policies for user_timezones
CREATE POLICY "Users can view their own timezone" 
ON public.user_timezones 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own timezone" 
ON public.user_timezones 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own timezone" 
ON public.user_timezones 
FOR UPDATE 
USING (auth.uid() = user_id);

-- Create trigger for automatic timestamp updates
CREATE TRIGGER update_user_timezones_updated_at
BEFORE UPDATE ON public.user_timezones
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();