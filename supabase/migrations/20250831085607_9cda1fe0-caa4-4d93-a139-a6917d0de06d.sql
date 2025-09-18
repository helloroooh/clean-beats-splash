-- Fix the incorrect streak for the Xyrcos equipment
UPDATE equipment 
SET current_streak = 1, best_streak = 1 
WHERE name = 'Xyrcos' AND user_id = '3bece720-79ac-4f99-b3b4-327054a117ed';