-- Fix: "What Remains of Edith Finch" - "All Done" should be Gold, not Platinum
-- Achievement ID: 66303

UPDATE achievements
SET 
    is_platinum = false,
    psn_trophy_type = 'gold'
WHERE id = 66303;

-- Verify the fix
SELECT 
    a.id,
    a.name,
    a.psn_trophy_type,
    a.is_platinum,
    gt.name as game_name
FROM achievements a
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE a.id = 66303;
