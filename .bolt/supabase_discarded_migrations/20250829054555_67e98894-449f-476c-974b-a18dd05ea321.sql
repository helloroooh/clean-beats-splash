-- Create equipment table
CREATE TABLE public.equipment (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL, -- e.g., 'guitar', 'drums', 'microphone', 'speaker'
  cleaning_frequency_days INTEGER NOT NULL DEFAULT 30, -- Days between cleanings
  notifications_enabled BOOLEAN NOT NULL DEFAULT true,
  show_on_profile BOOLEAN NOT NULL DEFAULT false,
  photo_url TEXT,
  icon TEXT, -- Icon identifier for equipment type
  last_cleaned_at TIMESTAMP WITH TIME ZONE,
  next_cleaning_due TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create cleaning logs table
CREATE TABLE public.cleaning_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  equipment_id UUID NOT NULL REFERENCES public.equipment(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  cleaned_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  notes TEXT,
  photo_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cleaning_logs ENABLE ROW LEVEL SECURITY;

-- Create policies for equipment
CREATE POLICY "Users can view their own equipment" 
ON public.equipment 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own equipment" 
ON public.equipment 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own equipment" 
ON public.equipment 
FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own equipment" 
ON public.equipment 
FOR DELETE 
USING (auth.uid() = user_id);

-- Create policies for cleaning logs
CREATE POLICY "Users can view their own cleaning logs" 
ON public.cleaning_logs 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own cleaning logs" 
ON public.cleaning_logs 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own cleaning logs" 
ON public.cleaning_logs 
FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own cleaning logs" 
ON public.cleaning_logs 
FOR DELETE 
USING (auth.uid() = user_id);

-- Create function to update timestamps
CREATE TRIGGER update_equipment_updated_at
BEFORE UPDATE ON public.equipment
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Create function to update next cleaning due date
CREATE OR REPLACE FUNCTION public.update_next_cleaning_due()
RETURNS TRIGGER AS $$
BEGIN
  -- Update next cleaning due date when equipment is updated or cleaning is logged
  IF TG_TABLE_NAME = 'equipment' THEN
    IF NEW.last_cleaned_at IS NOT NULL THEN
      NEW.next_cleaning_due = NEW.last_cleaned_at + (NEW.cleaning_frequency_days || ' days')::INTERVAL;
    ELSE
      NEW.next_cleaning_due = now() + (NEW.cleaning_frequency_days || ' days')::INTERVAL;
    END IF;
    RETURN NEW;
  ELSIF TG_TABLE_NAME = 'cleaning_logs' THEN
    -- Update equipment when a new cleaning log is added
    UPDATE public.equipment 
    SET 
      last_cleaned_at = NEW.cleaned_at,
      next_cleaning_due = NEW.cleaned_at + (cleaning_frequency_days || ' days')::INTERVAL,
      updated_at = now()
    WHERE id = NEW.equipment_id;
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for automatic date updates
CREATE TRIGGER update_equipment_next_cleaning
BEFORE INSERT OR UPDATE ON public.equipment
FOR EACH ROW
EXECUTE FUNCTION public.update_next_cleaning_due();

CREATE TRIGGER update_equipment_on_cleaning_log
AFTER INSERT ON public.cleaning_logs
FOR EACH ROW
EXECUTE FUNCTION public.update_next_cleaning_due();

-- Create indexes for better performance
CREATE INDEX idx_equipment_user_id ON public.equipment(user_id);
CREATE INDEX idx_equipment_next_cleaning_due ON public.equipment(next_cleaning_due);
CREATE INDEX idx_cleaning_logs_equipment_id ON public.cleaning_logs(equipment_id);
CREATE INDEX idx_cleaning_logs_user_id ON public.cleaning_logs(user_id);
CREATE INDEX idx_cleaning_logs_cleaned_at ON public.cleaning_logs(cleaned_at DESC);