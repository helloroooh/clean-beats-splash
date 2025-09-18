-- Create cleaning_equipment table
CREATE TABLE public.cleaning_equipment (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  name text NOT NULL,
  type text NOT NULL,
  description text,
  photo_url text,
  icon text,
  quantity integer NOT NULL DEFAULT 1,
  purchase_date timestamp with time zone,
  replacement_frequency_days integer,
  next_replacement_due timestamp with time zone,
  last_restocked_at timestamp with time zone,
  cost_per_unit decimal(10,2),
  supplier text,
  notes text,
  show_on_profile boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.cleaning_equipment ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for cleaning_equipment
CREATE POLICY "Users can view their own cleaning equipment" 
ON public.cleaning_equipment 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own cleaning equipment" 
ON public.cleaning_equipment 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own cleaning equipment" 
ON public.cleaning_equipment 
FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own cleaning equipment" 
ON public.cleaning_equipment 
FOR DELETE 
USING (auth.uid() = user_id);

-- Create trigger for automatic timestamp updates
CREATE TRIGGER update_cleaning_equipment_updated_at
BEFORE UPDATE ON public.cleaning_equipment
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Create function to update next replacement due date
CREATE OR REPLACE FUNCTION public.update_next_replacement_due()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  -- Update next replacement due date when cleaning equipment is updated
  IF NEW.replacement_frequency_days IS NOT NULL THEN
    IF NEW.last_restocked_at IS NOT NULL THEN
      NEW.next_replacement_due = NEW.last_restocked_at + (NEW.replacement_frequency_days || ' days')::INTERVAL;
    ELSE
      NEW.next_replacement_due = now() + (NEW.replacement_frequency_days || ' days')::INTERVAL;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- Create trigger for automatic next replacement due date updates
CREATE TRIGGER update_cleaning_equipment_replacement_due
BEFORE INSERT OR UPDATE ON public.cleaning_equipment
FOR EACH ROW
EXECUTE FUNCTION public.update_next_replacement_due();