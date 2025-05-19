-- ========================================================
-- Find Winning Party Using get_feature (No Join)
-- SIMPLIFIED: Assumes Column Names == Output Party Names
-- ========================================================

-- ***** START: DEFINE YOUR VARIABLES ***** --
-- !! MODIFY THESE VALUES TO MATCH YOUR DATA !! --

with_variable('election_layer_name',        'gebiete',    -- <<< CHANGE THIS: Exact name of election layer in Layers Panel
with_variable('election_district_id_field', 'gkz', -- <<< CHANGE THIS: Column name in election table with district ID
with_variable('district_layer_id_field',    'g_id',                              -- <<< CHANGE THIS: Column name in *this* districts layer with the ID to match

  -- Define the list of party names (used BOTH as column names and output names)
  with_variable('party_list',
    array(
      'SPÖ',     -- <<< CHANGE THESE: List all party column names / output names
      'ÖVP',
      'FPÖ',
      'GRÜNE',
      'NEOS',
	  'KPÖ'
      -- Add more party names here
    ),

-- ***** END: DEFINE YOUR VARIABLES ***** --
-- ***** START: MAIN LOGIC ***** --

      -- Get the feature (row) from the election table that matches the current district's ID
      with_variable('election_feature',
        get_feature(
          @election_layer_name,
          @election_district_id_field,
          attribute($currentfeature, @district_layer_id_field) -- Gets the ID from the current district feature
        ),

        -- Check if a matching feature was found in the election table
        if(
          @election_feature IS NULL,

          -- Value if no match found for the district ID
          'No Election Data Found',

          -- If a match was found, proceed to find the winning party
          -- Create an array of the vote values by looking up each party column in the found election feature
          with_variable('vote_values',
            array_foreach(
              @party_list, -- Use the single list to get column names
              attribute(@election_feature, @element)
            ),

            -- Find the maximum vote value
            with_variable('max_vote',
              array_max(@vote_values),

              -- Find the index (position) of the maximum value in the values array
              -- array_find returns the index of the *first* match if there are ties
              with_variable('max_index',
                array_find(@vote_values, @max_vote),

                -- Get the party name from the *same* list using the found index
                if (
                  @max_index > -1, -- Check if a max value was actually found (index is not -1)
                  array_get(@party_list, @max_index), -- Use the single list to get the output name
                  'Tie/Error/All Zero' -- Handle cases like all votes being zero, ties, or errors
                ) -- End inner if check
              ) -- End with_variable max_index
            ) -- End with_variable max_vote
          ) -- End with_variable vote_values
        ) -- End outer if election_feature is NULL check
      ) -- End with_variable election_feature
-- ***** END: MAIN LOGIC ***** --
    ) -- End with_variable party_list
  ) -- End with_variable district_layer_id_field
)) -- End with_variable election_district_id_field & election_layer_name