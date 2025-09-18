-- Create event_comments table for commenting on events
CREATE TABLE public.event_comments (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID NOT NULL,
  user_id UUID NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.event_comments ENABLE ROW LEVEL SECURITY;

-- Create policies for event comments
CREATE POLICY "Users can view all event comments" 
ON public.event_comments 
FOR SELECT 
USING (true);

CREATE POLICY "Users can create their own event comments" 
ON public.event_comments 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own event comments" 
ON public.event_comments 
FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own event comments" 
ON public.event_comments 
FOR DELETE 
USING (auth.uid() = user_id);

-- Create trigger for automatic timestamp updates
CREATE TRIGGER update_event_comments_updated_at
BEFORE UPDATE ON public.event_comments
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Add share_with_followers column to events table
ALTER TABLE public.events 
ADD COLUMN share_with_followers BOOLEAN NOT NULL DEFAULT false;