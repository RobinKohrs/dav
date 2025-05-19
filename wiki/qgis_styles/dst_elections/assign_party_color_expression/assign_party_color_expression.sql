CASE
  WHEN "winner" = 'SPÖ' THEN '#e31a0b'  -- Red
  WHEN "winner" = 'ÖVP' THEN '#343434'  -- Black
  WHEN "winner" = 'FPÖ' THEN '#0098d4'  -- Blue
  WHEN "winner" = 'GRÜNE' THEN '#78a300' -- Green
  WHEN "winner" = 'NEOS' THEN '#e5338a' -- Pink
  ELSE '#c4c4c4'                      -- Default Grey for all others
END