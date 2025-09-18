-- Create FCM tokens table for managing user notification tokens
CREATE TABLE public.fcm_tokens (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('web', 'ios', 'android')),
  device_info JSONB,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  last_used_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  -- Ensure one active token per platform per user
  UNIQUE(user_id, platform, token)
);

-- Enable Row Level Security
ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Create policies for FCM tokens
CREATE POLICY "Users can view their own FCM tokens" 
ON public.fcm_tokens 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own FCM tokens" 
ON public.fcm_tokens 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own FCM tokens" 
ON public.fcm_tokens 
FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own FCM tokens" 
ON public.fcm_tokens 
FOR DELETE 
USING (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX idx_fcm_tokens_user_id ON public.fcm_tokens(user_id);
CREATE INDEX idx_fcm_tokens_platform ON public.fcm_tokens(platform);
CREATE INDEX idx_fcm_tokens_active ON public.fcm_tokens(is_active) WHERE is_active = true;

-- Create function to clean up old/duplicate tokens
CREATE OR REPLACE FUNCTION public.cleanup_fcm_tokens()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  -- Mark tokens as inactive if they haven't been used in 30 days
  UPDATE public.fcm_tokens 
  SET is_active = false 
  WHERE last_used_at < now() - interval '30 days' 
  AND is_active = true;
  
  -- Delete old inactive tokens (older than 90 days)
  DELETE FROM public.fcm_tokens 
  WHERE is_active = false 
  AND updated_at < now() - interval '90 days';
END;
$$;

-- Add updated_at trigger
CREATE TRIGGER update_fcm_tokens_updated_at
BEFORE UPDATE ON public.fcm_tokens
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Create notification delivery tracking table
CREATE TABLE public.notification_deliveries (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  notification_type TEXT NOT NULL,
  fcm_message_id TEXT,
  platform TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('sent', 'delivered', 'failed', 'clicked')),
  error_message TEXT,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS for notification deliveries
ALTER TABLE public.notification_deliveries ENABLE ROW LEVEL SECURITY;

-- Create policies for notification deliveries (system can insert, users can view their own)
CREATE POLICY "System can create notification deliveries" 
ON public.notification_deliveries 
FOR INSERT 
WITH CHECK (true);

CREATE POLICY "Users can view their own notification deliveries" 
ON public.notification_deliveries 
FOR SELECT 
USING (auth.uid() = user_id);

-- Create indexes for notification deliveries
CREATE INDEX idx_notification_deliveries_user_id ON public.notification_deliveries(user_id);
CREATE INDEX idx_notification_deliveries_type ON public.notification_deliveries(notification_type);
CREATE INDEX idx_notification_deliveries_status ON public.notification_deliveries(status);