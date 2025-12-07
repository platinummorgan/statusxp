-- Calculate actual StatusXP breakdown
SELECT * FROM user_statusxp_summary 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Breakdown by platform
SELECT * FROM user_statusxp_totals
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
