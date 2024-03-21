module deployer::bingov2 {

    //==============================================================================================
    // Dependencies
    //==============================================================================================

    use aptos_framework::randomness;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::account::{Self, SignerCapability};
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    use aptos_token_objects::token;
    use aptos_token_objects::royalty::{Self};
    use aptos_token_objects::collection;
    use aptos_framework::option;
    use aptos_framework::event::{Self, EventHandle};
    use std::string_utils;

    use aptos_framework::timestamp;
    use aptos_std::simple_map::{Self, SimpleMap};
    use std::debug;

    #[test_only]
    use aptos_framework::aptos_coin::{Self};
    use std::object;

    //==============================================================================================
    // Errors
    //==============================================================================================

    const ERROR_SIGNER_NOT_ADMIN: u64 = 0;
    const ERROR_INVALID_START_TIMESTAMP: u64 = 1;
    const ERROR_INSUFFICIENT_BALANCE: u64 = 2;
    const ERROR_GAME_NOT_INITIALIZED: u64 = 3;
    const ERROR_GAME_HAS_STARTED: u64 = 4;
    const ERROR_GAME_NOT_STARTED: u64 = 5;
    const ERROR_CANT_START_GAME_YET: u64 = 6;
    const ERROR_INVALID_PRIZE_NAME: u64 = 7;
    const ERROR_GAME_HAS_ENDED: u64 = 8;
    const ERROR_NOT_WINNING_TICKET: u64 = 9;
    const ERROR_NEED_TO_WAIT_INTERVAL_TIME: u64 = 10;
    const ERROR_DUPLICATED_TICKET: u64 = 11;
    const ERROR_USER_ALREADY_BOUGHT_ONE: u64 = 12;
    const ERROR_NOT_GAME_CREATOR: u64 = 13;
    const ERROR_OTHER: u64 = 14;

    //==============================================================================================
    // Constants
    //==============================================================================================

    // // Seed for resource account creation
    // const SEED: vector<u8> = b"bingo";
    //
    // //The minimum price of a reading, in APT.
    // const MINT_PRICE: u64 = 10000000; //0.1
    //
    // //Wait interval between each randomizer call
    // const INTERVAL: u64 = 60000; //1 min
    //
    // // NFT collection information
    // const COLLECTION_NAME: vector<u8> = b"Virtue Bingo";
    // const COLLECTION_DESCRIPTION: vector<u8> = b"Virtue Bingo, powered by Aptos Randomnet";
    // const COLLECTION_URI: vector<u8> = b"ipfs://bafybeibywuazdl7r6zo7c5qiardnln5xheisiprn3gtcorr4ed4yuenmcm"; //replace
    //
    const PRIZE_POOL: vector<u64> = vector[18, 18, 18, 36, 10]; // top line, mid line, bottom line, full house, treasury
    const NUMS: vector<u64> = vector[
        1,2,3,4,5,6,7,8,9,10,
        11,12,13,14,15,16,17,18,19,20,
        21,22,23,24,25,26,27,28,29,30,
        31,32,33,34,35,36,37,38,39,40,
        41,42,43,44,45,46,47,48,49,50,
        51,52,53,54,55,56,57,58,59,60,
        61,62,63,64,65,66,67,68,69,70,
        71,72,73,74,75,76,77,78,79,80,
        81,82,83,84,85,86,87,88,89,90
    ];
    //==============================================================================================
    // Module Structs
    //==============================================================================================

    /*
    Struct holding data about a single card
    */
    struct Card has store, key{
        // Used for editing the token data
        mutator_ref: token::MutatorRef,
        // Used for burning the token
        burn_ref: token::BurnRef,
        // Every inner vector of the value represents a single row of a bingo sheet.
        card: vector<vector<u64>>
    }

    /*
        Struct holding data about a single game
    */
    struct Game has store {
        // resource cap of game treasury
        res_cap: SignerCapability,
        game_creator: address,
        game_name: String,
        customs: Customs,
        // List of players participating in a game.
        // Every inner inner vector of the value represents a single row of a bingo sheet.
        // i.e. vector<Card>
        cards: vector<vector<vector<u64>>>,
        //card obj address
        card_obj_add: vector<address>,
        //address of buyers to make sure each user can only buy 1 ticket
        buyers: vector<address>,
        // Timestamp of game's start
        /// also works as last drawn timestamp after game started
        start_lastdrawn_timestamp: u64,
        // Numbers drawn by the admin for a game
        undrawn_numbers: vector<u64>,
        // Boolean flag indicating if a game has started
        is_started: bool,
        // Boolean flag indicating if a game is ongoing or has finished
        is_finished: bool,
        //claim prize pending
        claim_pending: Claims,
        // Events
        draw_number_events: EventHandle<DrawNumberEvent>,
        join_game_events: EventHandle<JoinGameEvent>,
        bingo_events: EventHandle<BingoEvent>
    }

    /*
        Struct holding data about pending claims
    */
    struct Claims has store {
        pendings: u64,
        //store claimer add
        row0: vector<address>,
        row1: vector<address>,
        row2: vector<address>,
        fh: vector<address>,
        //store full house winning card(s) obj add
        winning_cards: vector<address>
    }

    /*
    Custom Information to be used in the game
*/
    struct Customs has store {
        mint_price: u64,
        //Wait interval between each randomizer call
        interval: u64,
        collection_name: String,
        collection_desc: String,
        collection_uri: String,
        royalty_numerator: u64
    }

    /*
    Information to be used in the module
*/
    struct State has key {
        // List of games
        // <game_id, Game>
        games: SimpleMap<u64, Game>,
        // number of games
        game_count: u64,
        // Events
        create_game_events: EventHandle<CreateGameEvent>,
        cancel_game_events: EventHandle<CancelGameEvent>,
        game_started_events: EventHandle<GameStartedEvent>,
        game_ended_events: EventHandle<GameEndedEvent>
    }

    //==============================================================================================
    // Event structs
    //==============================================================================================
    struct CreateGameEvent has store, drop {
        creator: address,
        game_name: String,
        game_id: u64,
        start_timestamp: u64,
        timestamp: u64
    }

    struct DrawNumberEvent has store, drop {
        game_id: u64,
        number: u64,
        timestamp: u64
    }

    struct JoinGameEvent has store, drop {
        game_id: u64,
        player: address,
        timestamp: u64
    }

    struct BingoEvent has store, drop {
        game_id: u64,
        player: address,
        timestamp: u64
    }

    struct CancelGameEvent has store, drop {
        game_id: u64,
        timestamp: u64
    }

    struct GameStartedEvent has store, drop {
        game_id: u64,
        timestamp: u64
    }

    struct GameEndedEvent has store, drop {
        game_id: u64,
        timestamp: u64
    }
    //==============================================================================================
    // Functions
    //==============================================================================================

    fun init_module(deployer: &signer) {
        // Create the State global resource and move it to the admin account
        let state = State{
            games: simple_map::new(),
            game_count: 0,
            create_game_events: account::new_event_handle<CreateGameEvent>(deployer),
            cancel_game_events: account::new_event_handle<CancelGameEvent>(deployer),
            game_started_events: account::new_event_handle<GameStartedEvent>(deployer),
            game_ended_events: account::new_event_handle<GameEndedEvent>(deployer)
        };
        move_to<State>(deployer, state);
    }

    /// create game.
    public entry fun create_game(
        user: &signer,
        game_name: String,
        start_time: u64, //how many seconds after this function call can this game start
        mint_price: u64,
        interval: u64,
        collection_name: String,
        collection_desc: String,
        collection_uri: String,
        royalty_numerator: u64
    ) acquires State {
        assert_start_timestamp_is_valid(start_time);
        let state = borrow_global_mut<State>(@deployer);
        let game_id = state.game_count;
        let claims = Claims{
            pendings: 0,
            row0: vector::empty(),
            row1: vector::empty(),
            row2: vector::empty(),
            fh: vector::empty(),
            winning_cards: vector::empty()
        };

        let customs = Customs{
            mint_price,
            interval,
            collection_name,
            collection_desc,
            collection_uri,
            royalty_numerator
        };

        let seed = string_utils::format1(&b"Bingo#{}", game_id);
        let (res_signer, res_cap) = account::create_resource_account(user, *string::bytes(&seed));
        coin::register<AptosCoin>(&res_signer);

        let royalty = royalty::create(royalty_numerator,100,@treasury);

        // Create an NFT collection with an unlimited supply and the following aspects:
        collection::create_unlimited_collection(
            &res_signer,
            collection_desc,
            collection_name,
            option::some(royalty),
            collection_uri
        );


        let new_game = Game{
            res_cap,
            game_creator: signer::address_of(user),
            game_name,
            customs,
            cards: vector::empty(),
            card_obj_add: vector::empty(),
            buyers: vector::empty(),
            start_lastdrawn_timestamp: start_time,
            undrawn_numbers: NUMS,
            is_started: false,
            is_finished: false,
            claim_pending: claims,
            draw_number_events: account::new_event_handle<DrawNumberEvent>(&res_signer),
            join_game_events: account::new_event_handle<JoinGameEvent>(&res_signer),
            bingo_events: account::new_event_handle<BingoEvent>(&res_signer)
        };

        simple_map::add(&mut state.games, game_id, new_game);

        event::emit_event<CreateGameEvent>(
            &mut state.create_game_events,
            CreateGameEvent{
                creator: signer::address_of(user),
                game_name,
                game_id,
                start_timestamp: start_time,
                timestamp: timestamp::now_seconds()
            }
        );
        state.game_count = state.game_count + 1;
    }

    // Every inner inner vector of the card represents a single row of a bingo sheet.
    public entry fun join_game(
        user: &signer,
        game_id: u64,
        token_uri: String,
        r0: vector<u64>,
        r1: vector<u64>,
        r2: vector<u64>
    ) acquires State {
        assert_game_initialized(game_id);
        let state = borrow_global_mut<State>(@deployer);
        let game = simple_map::borrow_mut(&mut state.games, &game_id);
        assert_game_not_started(game.is_started);
        let card = vector[r0,r1,r2];
        assert_card_not_duplicated(card, game.cards);
        let user_add = signer::address_of(user);
        assert_one_user_one_card_purchase(game.buyers, user_add);
        let user_add = signer::address_of(user);
        assert_enough_apt(user_add, game.customs.mint_price);
        // Payment
        coin::transfer<AptosCoin>(user, signer::address_of(&account::create_signer_with_capability(&game.res_cap)), game.customs.mint_price);

        let token_name = game.game_name;
        let royalty = royalty::create(game.customs.royalty_numerator,100,@treasury);
        string::append(&mut token_name, string_utils::format1(&b" #{}",vector::length(&game.cards)));
        let status = string_utils::format1(&b"Status: {}",b"-");
        let res_signer = account::create_signer_with_capability(&game.res_cap);
        // Create a new named token:
        let token_const_ref = token::create_named_token(
            &res_signer,
            game.customs.collection_name,
            status,
            token_name,
            option::some(royalty),
            token_uri
        );
        let obj_signer = object::generate_signer(&token_const_ref);
        let obj_add = object::address_from_constructor_ref(&token_const_ref);

        // Transfer the token to the user account
        object::transfer_raw(&res_signer, obj_add, user_add);

        // Create the ErebrusToken object and move it to the new token object signer
        let new_nft_token = Card {
            mutator_ref: token::generate_mutator_ref(&token_const_ref),
            burn_ref: token::generate_burn_ref(&token_const_ref),
            card
        };
        move_to<Card>(&obj_signer, new_nft_token);

        vector::push_back(&mut game.cards, card);
        vector::push_back(&mut game.buyers, user_add);
        vector::push_back(&mut game.card_obj_add, obj_add);

        event::emit_event<JoinGameEvent>(
            &mut game.join_game_events,
            JoinGameEvent{
                game_id,
                player: user_add,
                timestamp: timestamp::now_seconds()
            }
        );
    }

    public entry fun start_game(game_id: u64) acquires State{
        {
            assert_game_initialized(game_id);
            let state = borrow_global_mut<State>(@deployer);
            let game = simple_map::borrow_mut(&mut state.games, &game_id);
            assert_game_not_started(game.is_started);
            assert_pass_set_start_time(game.start_lastdrawn_timestamp);
            game.is_started = true;
            let now = timestamp::now_seconds();
            event::emit_event<GameStartedEvent>(
                &mut state.game_started_events,
                GameStartedEvent {
                    game_id,
                    timestamp: now
                }
            );
            game.start_lastdrawn_timestamp = now;
        };
    }

    public entry fun draw_number(game_id: u64) acquires State, Card{
        assert_game_initialized(game_id);
        let fh_claimed = 0;
        {
            let state = borrow_global_mut<State>(@deployer);
            let game = simple_map::borrow_mut(&mut state.games, &game_id);
            assert_game_has_started(game.is_started);
            assert_game_not_finished(game.is_finished);
            assert_passed_interval_timeframe(game.start_lastdrawn_timestamp, game.customs.interval);
            //check claim prize in game.claim_pending
            fh_claimed = vector::length(&game.claim_pending.fh);
        };

        {
          distribute_prize(game_id);
        };

        let state = borrow_global_mut<State>(@deployer);
        let game = simple_map::borrow_mut(&mut state.games, &game_id);
        let res_signer = account::create_signer_with_capability(&game.res_cap);
        let pool = coin::balance<AptosCoin>(signer::address_of(&res_signer));
        //fh claimed
        if(fh_claimed != 0){
            game.is_finished = true;
            event::emit_event<GameEndedEvent>(
                &mut state.game_ended_events,
                GameEndedEvent{
                    game_id,
                    timestamp: timestamp::now_seconds()
                }
            );
            coin::transfer<AptosCoin>(&res_signer, @treasury, pool);
        }else{ //fh not claimed
            let (number, new_vec) = get_new_number(game.undrawn_numbers);
            game.undrawn_numbers = new_vec;
            //todo: how to use vector::destroy()
            let now = timestamp::now_seconds();
            event::emit_event<DrawNumberEvent>(
                &mut game.draw_number_events,
                DrawNumberEvent{
                    game_id,
                    number,
                    timestamp: now
                }
            );
            game.start_lastdrawn_timestamp = now;
            //last number was drawn
            if(vector::length(&game.undrawn_numbers) == 0){
                game.is_finished = true;
                event::emit_event<GameEndedEvent>(
                    &mut state.game_ended_events,
                    GameEndedEvent{
                        game_id,
                        timestamp: timestamp::now_seconds()
                    }
                );
                coin::transfer<AptosCoin>(&res_signer, @treasury, pool);
            };
        };
    }

    //prize entry: row0/row1/row2/FH
    // Every inner inner vector of the card represents a single row of a bingo sheet.
    public entry fun claim_prize(
        user: &signer,
        game_id: u64,
        prize: String,
        card_obj_add: address
    ) acquires State, Card {
        assert_game_initialized(game_id);
        assert_valid_prize_name(prize);
        let user_add = signer::address_of(user);
        let state = borrow_global_mut<State>(@deployer);
        let game = simple_map::borrow_mut(&mut state.games, &game_id);
        assert_game_has_started(game.is_started);
        let card = borrow_global<Card>(card_obj_add).card;
        let check = false;
        if(prize == string::utf8(b"row0")){
            check = check_prize(game.undrawn_numbers, *vector::borrow(&card, 0));
            if(check){
                vector::push_back(&mut game.claim_pending.row0, user_add);
                game.claim_pending.pendings = game.claim_pending.pendings + 1;
            };
        }else if(prize == string::utf8(b"row1")){
            check = check_prize(game.undrawn_numbers, *vector::borrow(&card, 1));
            if(check){
                vector::push_back(&mut game.claim_pending.row1, user_add);
                game.claim_pending.pendings = game.claim_pending.pendings + 1;
            };
        }else if(prize == string::utf8(b"row2")){
            check = check_prize(game.undrawn_numbers, *vector::borrow(&card, 2));
            if(check){
                vector::push_back(&mut game.claim_pending.row2, user_add);
                game.claim_pending.pendings = game.claim_pending.pendings + 1;
            };
        }else{
            let check =
                check_prize(game.undrawn_numbers, *vector::borrow(&card, 0)) &&
                check_prize(game.undrawn_numbers, *vector::borrow(&card, 1)) &&
                check_prize(game.undrawn_numbers, *vector::borrow(&card, 2));
            if(check){ //won fh
                vector::push_back(&mut game.claim_pending.fh, user_add);
                game.claim_pending.pendings = game.claim_pending.pendings + 1;
                vector::push_back(&mut game.claim_pending.winning_cards, card_obj_add);
            };
        };
        assert_winning_ticket(check);
    }

    //todo: cancel_game

    public entry fun cancel_game(user: &signer, game_id: u64) acquires State{
        assert_game_initialized(game_id);
        let user_add = signer::address_of(user);
        let state = borrow_global_mut<State>(@deployer);
        let game = simple_map::borrow_mut(&mut state.games, &game_id);
        assert_game_creator(user_add, game.game_creator);
        assert_game_not_started(game.is_started);
        let res_signer = account::create_signer_with_capability(&game.res_cap);
        let pool = coin::balance<AptosCoin>(signer::address_of(&res_signer));
        let split = vector::length(&game.card_obj_add);
        if(pool != 0){
            while(vector::length(&game.card_obj_add) != 0){
                let owner = object::owner(object::address_to_object<Card>(*vector::borrow(&game.card_obj_add,0)));
                coin::transfer<AptosCoin>(&res_signer, owner, pool/split);
                vector::remove(&mut game.card_obj_add, 0);
            };

        };
        game.is_finished = true;
        event::emit_event<CancelGameEvent>(
            &mut state.cancel_game_events,
            CancelGameEvent{
                game_id,
                timestamp: timestamp::now_seconds()
            }
        );
    }

    //==============================================================================================
    // Helper functions
    //==============================================================================================

    inline fun get_new_number(undrawn_numbers: vector<u64>): (u64, vector<u64>) {
        let index = randomness::u64_range(0, vector::length(&undrawn_numbers));
        (vector::remove(&mut undrawn_numbers, index) , undrawn_numbers)
    }

    inline fun check_prize(undrawn_numbers: vector<u64>, row: vector<u64>): bool{
        let check = true;
        let i = 0;
        while(i < 4){
            vector::remove_value(&mut row, &0);
            i = i + 1;
        };
        i = 0;
        while(check && i < 5){
            if(vector::contains(&undrawn_numbers, vector::borrow(&row, (i as u64)))){
                check = false;
            }else{
                i = i + 1;
            };
        };
        check
    }

    inline fun edit_nft(nft: address, new_status: String){
        assert_admin(@admin);
        let status = string::utf8(b"Status: ");
        string::append(&mut status, new_status);
        let card = borrow_global<Card>(nft);
        token::set_description(&card.mutator_ref, status);
    }

    inline fun distribute_prize(game_id: u64) acquires State{
        let state = borrow_global_mut<State>(@deployer);
        let game = simple_map::borrow_mut(&mut state.games, &game_id);
        let res_signer = account::create_signer_with_capability(&game.res_cap);
        let pool = coin::balance<AptosCoin>(signer::address_of(&res_signer));
        if(game.claim_pending.pendings > 0){
            let split = vector::length(&game.claim_pending.row0);
            while(vector::length(&game.claim_pending.row0) >0){
                coin::transfer<AptosCoin>(&res_signer, *vector::borrow(&game.claim_pending.row0, 0), pool*(*vector::borrow(&PRIZE_POOL, 0))/split/100);
                vector::remove(&mut game.claim_pending.row0, 0);
                game.claim_pending.pendings = game.claim_pending.pendings - 1;
            };
            split = vector::length(&game.claim_pending.row1);
            while(vector::length(&game.claim_pending.row1) >0){
                coin::transfer<AptosCoin>(&res_signer, *vector::borrow(&game.claim_pending.row1, 0), pool*(*vector::borrow(&PRIZE_POOL, 1))/split/100);
                vector::remove(&mut game.claim_pending.row1, 0);
                game.claim_pending.pendings = game.claim_pending.pendings - 1;
            };
            split = vector::length(&game.claim_pending.row2);
            while(vector::length(&game.claim_pending.row2) >0){
                coin::transfer<AptosCoin>(&res_signer, *vector::borrow(&game.claim_pending.row2, 0), pool*(*vector::borrow(&PRIZE_POOL, 2))/split/100);
                vector::remove(&mut game.claim_pending.row2, 0);
                game.claim_pending.pendings = game.claim_pending.pendings - 1;
            };
            split = vector::length(&game.claim_pending.fh);
            while(vector::length(&game.claim_pending.fh) >0){
                coin::transfer<AptosCoin>(&res_signer, *vector::borrow(&game.claim_pending.row1, 0), pool*(*vector::borrow(&PRIZE_POOL, 3))/split/100);
                vector::remove(&mut game.claim_pending.fh, 0);
                game.claim_pending.pendings = game.claim_pending.pendings - 1;
                //change winning ticket description
                edit_nft(*vector::borrow(&game.claim_pending.winning_cards, 0), string::utf8(b"Won"));
                vector::remove(&mut game.claim_pending.winning_cards, 0);
            };
        };
    }

    //==============================================================================================
    // View functions
    //==============================================================================================

    #[view]
    public fun get_collection_address(game_id: u64): address acquires State {
        let state = borrow_global_mut<State>(@deployer);
        let game = simple_map::borrow_mut(&mut state.games, &game_id);
        collection::create_collection_address(
            &signer::address_of(&account::create_signer_with_capability(&game.res_cap)),
            &game.customs.collection_name
        )
    }

    #[view]
    public fun get_number_of_cards_sold(game_id: u64): u64 acquires State {
        let state = borrow_global_mut<State>(@deployer);
        let game = simple_map::borrow_mut(&mut state.games, &game_id);
        vector::length(&game.cards)
    }

    //==============================================================================================
    // Validation functions
    //==============================================================================================

    inline fun assert_admin(admin: address) {
        assert!(admin == @admin, ERROR_SIGNER_NOT_ADMIN);
    }

    inline fun assert_start_timestamp_is_valid(start_timestamp: u64) {
        assert!(start_timestamp >= timestamp::now_seconds(),ERROR_INVALID_START_TIMESTAMP);
    }

    inline fun assert_game_initialized(game_id: u64) acquires State {
        assert!(exists<State>(@deployer),ERROR_GAME_NOT_INITIALIZED);
        let state = borrow_global<State>(@deployer);
        assert!(simple_map::contains_key(&state.games, &game_id),ERROR_GAME_NOT_INITIALIZED);
    }

    inline fun assert_enough_apt(user: address, mint_price: u64) {
        assert!(coin::balance<AptosCoin>(user) >= mint_price, ERROR_INSUFFICIENT_BALANCE);
    }

    inline fun assert_game_not_started(is_started: bool){
        assert!(!is_started, ERROR_GAME_HAS_STARTED);
    }

    inline fun assert_game_has_started(is_started: bool){
        assert!(is_started, ERROR_GAME_NOT_STARTED);
    }

    inline fun assert_game_not_finished(is_finished: bool){
        assert!(!is_finished, ERROR_GAME_HAS_ENDED);
    }

    inline fun assert_pass_set_start_time(start_timestamp: u64){
        assert!(timestamp::now_seconds() >= start_timestamp, ERROR_CANT_START_GAME_YET);
    }

    inline fun assert_valid_prize_name(prize: String){
        let names = vector[
            string::utf8(b"row0"),
            string::utf8(b"row1"),
            string::utf8(b"row2"),
            string::utf8(b"fh")
        ];
        assert!(vector::contains(&names, &prize), ERROR_INVALID_PRIZE_NAME);
    }

    inline fun assert_winning_ticket(check: bool){
        assert!(check, ERROR_NOT_WINNING_TICKET);
    }

    inline fun assert_passed_interval_timeframe(start_timestamp: u64, interval: u64) {
        assert!(timestamp::now_seconds() >= start_timestamp + interval, ERROR_NEED_TO_WAIT_INTERVAL_TIME);
    }

    inline fun assert_card_not_duplicated(card: vector<vector<u64>>, cards: vector<vector<vector<u64>>>){
        assert!(!vector::contains(&cards, &card), ERROR_DUPLICATED_TICKET);
    }

    inline fun assert_one_user_one_card_purchase(buyers: vector<address>, user: address){
        assert!(!vector::contains(&buyers, &user), ERROR_USER_ALREADY_BOUGHT_ONE);
    }

    inline fun assert_game_creator(user: address, creator: address){
        assert!(user == creator, ERROR_NOT_GAME_CREATOR);
    }

    //==============================================================================================
    // Test functions
    //==============================================================================================

    #[test(deployer = @deployer)]
    fun test_init_module_success(
        deployer: &signer
    ) {
        let deployer_address = signer::address_of(deployer);
        account::create_account_for_test(deployer_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(deployer);

        assert!(exists<State>(deployer_address),0);
    }

    #[test(deployer = @deployer, user = @0xA)]
    fun test_create_game_success(
        deployer: &signer,
        user: &signer,
    ) acquires State {
        let deployer_address = signer::address_of(deployer);
        account::create_account_for_test(deployer_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        init_module(deployer);

        let game_name = string::utf8(b"test");
        let mint_price = 10000000; //0.1APT
        let interval = 60000; //1min
        let collection_name = string::utf8(b"test_collection");
        let collection_desc = string::utf8(b"test_collection_desc");
        let collection_uri = string::utf8(b"test_collection_uri");
        let royalty_numerator = 5;
        create_game(
            user,
            game_name,
            timestamp::now_seconds(),
            mint_price,
            interval,
            collection_name,
            collection_desc,
            collection_uri,
            royalty_numerator
        );

        let state = borrow_global<State>(deployer_address);

        assert!(state.game_count == 1, 14);
        let game = simple_map::borrow(&state.games, &0);
        assert!(game.game_name == game_name, 14);
        assert!(event::counter(&state.create_game_events) == 1, 14);
    }

    #[test(deployer = @deployer, game_creator = @0xA, joiner = @0xB)]
    fun test_join_game_success(
        deployer: &signer,
        game_creator: &signer,
        joiner: &signer
    ) acquires State {
        let deployer_address = signer::address_of(deployer);
        let game_creator_address = signer::address_of(game_creator);
        let joiner_address = signer::address_of(joiner);
        account::create_account_for_test(deployer_address);
        account::create_account_for_test(game_creator_address);
        account::create_account_for_test(joiner_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);
        coin::register<AptosCoin>(joiner);
        init_module(deployer);
        let mint_price = 10000000; //0.1APT
        aptos_coin::mint(&aptos_framework, joiner_address, mint_price);

        let game_name = string::utf8(b"test");
        let interval = 60000; //1min
        let collection_name = string::utf8(b"test_collection");
        let collection_desc = string::utf8(b"test_collection_desc");
        let collection_uri = string::utf8(b"test_collection_uri");
        let royalty_numerator = 5;
        create_game(
            game_creator,
            game_name,
            timestamp::now_seconds(),
            mint_price,
            interval,
            collection_name,
            collection_desc,
            collection_uri,
            royalty_numerator
        );

        let token_uri= string::utf8(b"test_token_uri");
        let r0 = vector[1,2,3,4,5,0,0,0,0];
        let r1 = vector[1,2,3,4,5,0,0,0,0];
        let r2 = vector[1,2,3,4,5,0,0,0,0];
        join_game(joiner, 0, token_uri, r0,r1,r2);

        let state = borrow_global<State>(deployer_address);
        let game = simple_map::borrow(&state.games, &0);
        assert!(vector::length(&game.buyers) == 1, 14);
        assert!(vector::length(&game.cards) == 1, 14);
        assert!(event::counter(&state.create_game_events) == 1, 14);
        assert!(event::counter(&game.join_game_events) == 1, 14);

        let seed = string_utils::format1(&b"Bingo#{}", 0);
        let resource_account_address = account::create_resource_address(&game_creator_address, *string::bytes(&seed));
        let token_name = game.game_name;
        string::append(&mut token_name, string_utils::format1(&b" #{}",0));

        let expected_nft_token_address = token::create_token_address(
            &resource_account_address,
            &collection_name,
            &token_name
        );

        let nft_token_object = object::address_to_object<token::Token>(expected_nft_token_address);
        assert!(
            object::is_owner(nft_token_object, joiner_address) == true,
            1
        );
        assert!(
            token::creator(nft_token_object) == resource_account_address,
            12
        );

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test(deployer = @deployer, game_creator = @0xA, joiner = @0xB)]
    fun test_claim_prize_success(
        deployer: &signer,
        game_creator: &signer,
        joiner: &signer
    ) acquires State, Card {
        let deployer_address = signer::address_of(deployer);
        let game_creator_address = signer::address_of(game_creator);
        let joiner_address = signer::address_of(joiner);
        account::create_account_for_test(deployer_address);
        account::create_account_for_test(game_creator_address);
        account::create_account_for_test(joiner_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        randomness::initialize_for_testing(&aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);
        coin::register<AptosCoin>(joiner);
        init_module(deployer);
        let mint_price = 10000000; //0.1APT
        aptos_coin::mint(&aptos_framework, joiner_address, mint_price);

        let game_name = string::utf8(b"test");
        let interval = 1; //1min
        let collection_name = string::utf8(b"test_collection");
        let collection_desc = string::utf8(b"test_collection_desc");
        let collection_uri = string::utf8(b"test_collection_uri");
        let royalty_numerator = 5;
        create_game(
            game_creator,
            game_name,
            5,
            mint_price,
            interval,
            collection_name,
            collection_desc,
            collection_uri,
            royalty_numerator
        );
        let token_uri= string::utf8(b"test_token_uri");
        let r0 = vector[1,2,3,4,5,0,0,0,0];
        let r1 = vector[1,2,3,4,5,0,0,0,0];
        let r2 = vector[1,2,3,4,5,0,0,0,0];
        join_game(joiner, 0, token_uri, r0,r1,r2);

        timestamp::fast_forward_seconds(5);
        start_game(0);

        let expected_nft_token_address;
        {
            let state = borrow_global_mut<State>(deployer_address);
            let game = simple_map::borrow_mut(&mut state.games, &0);

            assert!(vector::length(&game.buyers) == 1, 14);
            assert!(vector::length(&game.cards) == 1, 14);
            assert!(event::counter(&state.create_game_events) == 1, 14);
            assert!(event::counter(&game.join_game_events) == 1, 14);
            assert!(event::counter(&state.game_started_events) == 1, 14);

            let seed = string_utils::format1(&b"Bingo#{}", 0);
            let resource_account_address = account::create_resource_address(&game_creator_address, *string::bytes(&seed));
            let token_name = game.game_name;
            string::append(&mut token_name, string_utils::format1(&b" #{}", 0));

            expected_nft_token_address = token::create_token_address(
                &resource_account_address,
                &collection_name,
                &token_name
            );

            let nft_token_object = object::address_to_object<token::Token>(expected_nft_token_address);
            assert!(
                object::is_owner(nft_token_object, joiner_address) == true,
                1
            );
            assert!(
                token::creator(nft_token_object) == resource_account_address,
                12
            );

            let i = 0;
            while (i < 5) {
                &vector::remove(&mut game.undrawn_numbers, 0);
                i = i + 1;
            };
        };

        claim_prize(joiner, 0, string::utf8(b"row0"), expected_nft_token_address);

        let pool;
        {
            let state = borrow_global<State>(deployer_address);
            let game = simple_map::borrow(&state.games, &0);
            assert!(game.claim_pending.pendings == 1, 14);
            assert!(vector::length(&game.undrawn_numbers) == 85, 14);
            assert!(vector::contains(&game.claim_pending.row0, &joiner_address), 14);
            assert!(vector::length(&game.claim_pending.row0) == 1, 14);
            assert!(vector::length(&game.claim_pending.row1) == 0, 14);
            assert!(vector::length(&game.claim_pending.row2) == 0, 14);
            assert!(vector::length(&game.claim_pending.fh) == 0, 14);
            pool = coin::balance<AptosCoin>(signer::address_of(&account::create_signer_with_capability(&game.res_cap)));
        };

        timestamp::fast_forward_seconds(interval + 1);
        draw_number(0);

        let state = borrow_global<State>(deployer_address);
        let game = simple_map::borrow(&state.games, &0);
        assert!(game.claim_pending.pendings == 0, 14);
        assert!(vector::length(&game.undrawn_numbers) == 84, 14);
        assert!(coin::balance<AptosCoin>(joiner_address) == pool*(*vector::borrow(&PRIZE_POOL, 0))/100, 14);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

    }

    #[test(deployer = @deployer, game_creator = @0xA)]
    fun test_cancel_game_success_game_not_started(
        deployer: &signer,
        game_creator: &signer
    ) acquires State {
        let deployer_address = signer::address_of(deployer);
        let game_creator_address = signer::address_of(game_creator);
        account::create_account_for_test(deployer_address);
        account::create_account_for_test(game_creator_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        randomness::initialize_for_testing(&aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);
        init_module(deployer);
        let mint_price = 10000000; //0.1APT

        let game_name = string::utf8(b"test");
        let interval = 1; //1min
        let collection_name = string::utf8(b"test_collection");
        let collection_desc = string::utf8(b"test_collection_desc");
        let collection_uri = string::utf8(b"test_collection_uri");
        let royalty_numerator = 5;
        create_game(
            game_creator,
            game_name,
            5,
            mint_price,
            interval,
            collection_name,
            collection_desc,
            collection_uri,
            royalty_numerator
        );
        cancel_game(game_creator, 0);
        let state = borrow_global<State>(deployer_address);
        assert!(event::counter(&state.cancel_game_events) == 1, 14);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test(deployer = @deployer, treasury = @treasury, game_creator = @0xA, joiner = @0xB)]
    fun test_cancel_game_success_one_joiner(
        deployer: &signer,
        treasury: &signer,
        game_creator: &signer,
        joiner: &signer
    ) acquires State {
        let deployer_address = signer::address_of(deployer);
        let game_creator_address = signer::address_of(game_creator);
        let joiner_address = signer::address_of(joiner);
        let treasury_address = signer::address_of(treasury);
        account::create_account_for_test(deployer_address);
        account::create_account_for_test(game_creator_address);
        account::create_account_for_test(joiner_address);
        account::create_account_for_test(treasury_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        randomness::initialize_for_testing(&aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);
        coin::register<AptosCoin>(joiner);
        coin::register<AptosCoin>(treasury);
        init_module(deployer);
        let mint_price = 10000000; //0.1APT
        aptos_coin::mint(&aptos_framework, joiner_address, mint_price);

        let game_name = string::utf8(b"test");
        let interval = 1; //1min
        let collection_name = string::utf8(b"test_collection");
        let collection_desc = string::utf8(b"test_collection_desc");
        let collection_uri = string::utf8(b"test_collection_uri");
        let royalty_numerator = 5;
        create_game(
            game_creator,
            game_name,
            5,
            mint_price,
            interval,
            collection_name,
            collection_desc,
            collection_uri,
            royalty_numerator
        );
        let token_uri= string::utf8(b"test_token_uri");
        let r0 = vector[1,2,3,4,5,0,0,0,0];
        let r1 = vector[1,2,3,4,5,0,0,0,0];
        let r2 = vector[1,2,3,4,5,0,0,0,0];
        join_game(joiner, 0, token_uri, r0,r1,r2);
        cancel_game(game_creator, 0);
        let state = borrow_global<State>(deployer_address);
        assert!(event::counter(&state.cancel_game_events) == 1, 14);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

}
