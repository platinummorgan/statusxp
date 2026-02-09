-- Check if game-covers storage bucket exists
SELECT * FROM storage.buckets WHERE name = 'game-covers';

-- If it doesn't exist, create it with this SQL:
-- INSERT INTO storage.buckets (id, name, public) 
-- VALUES ('game-covers', 'game-covers', true);
