-- Create event_likes table for event likes functionality
CREATE TABLE public.event_likes (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(event_id, user_id)
);

-- Create event_attendees table for event attendance functionality
CREATE TABLE public.event_attendees (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(event_id, user_id)
);

-- Enable RLS on both tables
ALTER TABLE public.event_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_attendees ENABLE ROW LEVEL SECURITY;

-- Create policies for event_likes
CREATE POLICY "Users can view all event likes" 
ON public.event_likes 
FOR SELECT 
USING (true);

CREATE POLICY "Users can create their own event likes" 
ON public.event_likes 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own event likes" 
ON public.event_likes 
FOR DELETE 
USING (auth.uid() = user_id);

-- Create policies for event_attendees
CREATE POLICY "Users can view all event attendees" 
ON public.event_attendees 
FOR SELECT 
USING (true);

CREATE POLICY "Users can create their own event attendance" 
ON public.event_attendees 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own event attendance" 
ON public.event_attendees 
FOR DELETE 
USING (auth.uid() = user_id);