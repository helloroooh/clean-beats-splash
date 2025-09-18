-- Add RLS policy to allow users to see events from people they follow
CREATE POLICY "Users can view events from followed users" 
ON public.events 
FOR SELECT 
USING (
  user_id IN (
    SELECT following_id 
    FROM public.followers 
    WHERE follower_id = auth.uid()
  )
);