# VirtueBingo

## Functions:

1. create_game
   - Takes in variables: 
     - game_name: String,
       start_time: u64,
       mint_price: u64,
       interval: u64,
       collection_name: String,
       collection_desc: String,
       collection_uri: String,
       royalty_numerator: u64
   - Called by any user

2. join_game
   - Takes in variables:
     - game_id: u64, 
     - token_uri: String, 
     - r0: vector<u64>, 
     - r1: vector<u64>, 
     - r2: vector<u64>
   - Called by any user 

3. start_game
   - Takes in variables: game_id: u64
   - Called by anyone

4. draw_number
    - Takes in variables: game_id: u64
    - Called by anyone
    - distribute prizes(if any)in claim list 
    - ends game if FullHouse prize is claimed or last number gets drawn

5. claim_prize
    - Takes in variables: game_id: u64, prize: String, card_obj_add: address
    - Called by winning user
    - stores winning user address to a list
