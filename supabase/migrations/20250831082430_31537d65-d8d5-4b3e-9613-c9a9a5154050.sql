-- Fix the Fender equipment streak to 2 (cleaned on 29th and 31st with 2-day frequency)
UPDATE equipment 
SET 
  current_streak = 2,
  best_streak = GREATEST(best_streak, 2),
  last_streak_date = '2025-08-31',
  next_cleaning_due = '2025-09-02 23:59:59',
  updated_at = now()
WHERE name = 'Fender';