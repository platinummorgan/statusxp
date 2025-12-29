-- Count achievements by platform

SELECT 
    CASE 
        WHEN array_length(required_platforms, 1) = 1 AND 'psn' = ANY(required_platforms) THEN 'PSN Only'
        WHEN array_length(required_platforms, 1) = 1 AND 'xbox' = ANY(required_platforms) THEN 'Xbox Only'
        WHEN array_length(required_platforms, 1) = 1 AND 'steam' = ANY(required_platforms) THEN 'Steam Only'
        WHEN array_length(required_platforms, 1) = 3 THEN 'Cross-Platform'
        ELSE 'Other'
    END as platform_type,
    COUNT(*) as achievement_count
FROM meta_achievements
GROUP BY platform_type
ORDER BY platform_type;

-- Total count
SELECT COUNT(*) as total_achievements FROM meta_achievements;
