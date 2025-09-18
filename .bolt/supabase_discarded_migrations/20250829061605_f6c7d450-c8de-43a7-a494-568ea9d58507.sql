-- Create storage bucket for equipment photos
INSERT INTO storage.buckets (id, name, public) VALUES ('equipment-photos', 'equipment-photos', true);

-- Create RLS policies for equipment photos bucket
CREATE POLICY "Users can view equipment photos" 
ON storage.objects 
FOR SELECT 
USING (bucket_id = 'equipment-photos');

CREATE POLICY "Users can upload their own equipment photos" 
ON storage.objects 
FOR INSERT 
WITH CHECK (bucket_id = 'equipment-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can update their own equipment photos" 
ON storage.objects 
FOR UPDATE 
USING (bucket_id = 'equipment-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete their own equipment photos" 
ON storage.objects 
FOR DELETE 
USING (bucket_id = 'equipment-photos' AND auth.uid()::text = (storage.foldername(name))[1]);