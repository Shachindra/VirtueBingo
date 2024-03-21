# Snakes and Ladder

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
        - token_uri: String
    - Called by any user

3. start_game
    - Takes in variables: game_id: u64
    - Called by anyone

4. roll_dice
    - Takes in variables: game_id: u64, avatar_obj_add: address
    - Called by owner of avatar
    - distribute prizes(if any)in claim list
    - ends game if FullHouse prize is claimed or last number gets drawn

5. game_won
    - Takes in variables: game_id: u64, user: address, avatar_obj_add: address, snakes: u64, ladders: u64
    - Called by admin
    - edit winning nft metadata

6. cancel_game
    - Takes in variables: game_id: u64
    - Called by game creator
    - Can only be called if game not started
