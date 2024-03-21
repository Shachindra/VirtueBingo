module deployer::SNL {

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
    use aptos_token_objects::property_map;
    use aptos_framework::timestamp;
    use aptos_std::simple_map::{Self, SimpleMap};
    use std::bcs;
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
    const ERROR_GAME_HAS_ENDED: u64 = 7;
    const ERROR_NEED_TO_WAIT_INTERVAL_TIME: u64 = 8;
    const ERROR_USER_ALREADY_BOUGHT_ONE: u64 = 9;
    const ERROR_NOT_GAME_CREATOR: u64 = 10;
    const ERROR_NOT_AVATAR_OWNER: u64 = 11;
    const ERROR_OTHER: u64 = 12;

    //==============================================================================================
    // Constants
    //==============================================================================================

    const PROP_KEYS: vector<vector<u8>> = vector[
    b"GAME_STATUS",
    b"SNAKES_ENCOUNTERED",
    b"LADDERS_CLIMBED",
    b"TIMESTAMP_WON"
    ];

    const PROP_TYPES: vector<vector<u8>> = vector[
    b"0x1::string::String",
    b"u64",
    b"u64",
    b"u64"
    ];

    //==============================================================================================
    // Module Structs
    //==============================================================================================

    /*
    Struct holding data about a single card
    */
    struct Avatar has store, key{
        // Used for editing the token data
        mutator_ref: token::MutatorRef,
        // Used for burning the token
        burn_ref: token::BurnRef,
        property_mutator_ref: property_map::MutatorRef,
        // last roll timestamp
        last_roll_timestamp: u64,
        // last rolled number
        last_rolled_num: u64
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
        // address of buyers to make sure each user can only buy 1 ticket
        buyers: vector<address>,
        // nft_obj_add
        nft_obj_add: vector<address>,
        // Timestamp of game's start
        start_timestamp: u64,
        // Boolean flag indicating if a game has started
        is_started: bool,
        // Boolean flag indicating if a game is ongoing or has finished
        is_finished: bool,
        // Events
        roll_dice_events: EventHandle<RollDiceEvent>,
        join_game_events: EventHandle<JoinGameEvent>,
        game_won_events: EventHandle<GameWonEvent>
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

    struct RollDiceEvent has store, drop {
        game_id: u64,
        user: address,
        number: u64,
        timestamp: u64
    }

    struct JoinGameEvent has store, drop {
        game_id: u64,
        user: address,
        timestamp: u64
    }

    struct GameWonEvent has store, drop {
        game_id: u64,
        user: address,
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
        start_time: u64,
        mint_price: u64,
        interval: u64,
        collection_name: String,
        collection_desc: String,
        collection_uri: String,
        royalty_numerator: u64
    ) acquires State {
        let state = borrow_global_mut<State>(@deployer);
        let game_id = state.game_count;

        let customs = Customs{
            mint_price,
            interval,
            collection_name,
            collection_desc,
            collection_uri,
            royalty_numerator
        };

        let seed = string_utils::format1(&b"SL#{}", game_id);
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
            nft_obj_add: vector::empty(),
            buyers: vector::empty(),
            start_timestamp: start_time,
            is_started: false,
            is_finished: false,
            roll_dice_events: account::new_event_handle<RollDiceEvent>(&res_signer),
            join_game_events: account::new_event_handle<JoinGameEvent>(&res_signer),
            game_won_events: account::new_event_handle<GameWonEvent>(&res_signer)
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
        token_uri: String
    ) acquires State {
        assert_game_initialized(game_id);
        let state = borrow_global_mut<State>(@deployer);
        let game = simple_map::borrow_mut(&mut state.games, &game_id);
        assert_game_not_started(game.is_started);
        let user_add = signer::address_of(user);
        assert_one_user_one_card_purchase(game.buyers, user_add);
        let user_add = signer::address_of(user);
        assert_enough_apt(user_add, game.customs.mint_price);
        // Payment
        coin::transfer<AptosCoin>(user, signer::address_of(&account::create_signer_with_capability(&game.res_cap)), game.customs.mint_price);

        let token_name = game.game_name;
        let royalty = royalty::create(game.customs.royalty_numerator,100,@treasury);
        string::append(&mut token_name, string_utils::format1(&b" #{}",vector::length(&game.buyers)));
        let desc = string::utf8(b"Snakes & Ladders");
        let res_signer = account::create_signer_with_capability(&game.res_cap);
        // Create a new named token:
        let token_const_ref = token::create_named_token(
            &res_signer,
            game.customs.collection_name,
            desc,
            token_name,
            option::some(royalty),
            token_uri
        );
        let obj_signer = object::generate_signer(&token_const_ref);
        let obj_add = object::address_from_constructor_ref(&token_const_ref);

        // Transfer the token to the user account
        object::transfer_raw(&res_signer, obj_add, user_add);

        // Create the property_map for the new token with the following properties:
        //          - GAME_STATUS
        //          - SNAKES_ENCOUNTERED
        //          - LADDERS_CLIMBED
        //          - TIMESTAMP_WON

        let i = 0;
        let prop_keys = vector::empty();
        while(i < 4){
            vector::push_back(&mut prop_keys, string::utf8(*vector::borrow(&PROP_KEYS, i)));
            i = i + 1;
        };
        i = 0;
        let prop_types = vector::empty();
        while(i < 4){
            vector::push_back(&mut prop_types, string::utf8(*vector::borrow(&PROP_TYPES, i)));
            i = i + 1;
        };

        let status = string::utf8(b"-");
        let prop_values = vector[
            bcs::to_bytes(&status),
            bcs::to_bytes(&0),
            bcs::to_bytes(&0),
            bcs::to_bytes(&0),
        ];

        let token_prop_map = property_map::prepare_input(prop_keys,prop_types,prop_values);
        property_map::init(&token_const_ref,token_prop_map);

        // Create the ErebrusToken object and move it to the new token object signer
        let new_nft_token = Avatar {
            mutator_ref: token::generate_mutator_ref(&token_const_ref),
            burn_ref: token::generate_burn_ref(&token_const_ref),
            property_mutator_ref: property_map::generate_mutator_ref(&token_const_ref),
            last_roll_timestamp: 0,
            last_rolled_num: 0
        };
        move_to<Avatar>(&obj_signer, new_nft_token);

        vector::push_back(&mut game.buyers, user_add);
        vector::push_back(&mut game.nft_obj_add, obj_add);

        event::emit_event<JoinGameEvent>(
            &mut game.join_game_events,
            JoinGameEvent{
                game_id,
                user: user_add,
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
            assert_pass_set_start_time(game.start_timestamp);
            game.is_started = true;
            let now = timestamp::now_seconds();
            event::emit_event<GameStartedEvent>(
                &mut state.game_started_events,
                GameStartedEvent {
                    game_id,
                    timestamp: now
                }
            );
            game.start_timestamp = now;
        };
    }

    public entry fun roll_dice(user: &signer, game_id: u64, avatar_obj_add: address) acquires State, Avatar{
        assert_game_initialized(game_id);
        let state = borrow_global_mut<State>(@deployer);
        let game = simple_map::borrow_mut(&mut state.games, &game_id);
        assert_game_has_started(game.is_started);
        assert_game_not_finished(game.is_finished);
        assert_avatar_owner(signer::address_of(user), object::owner(object::address_to_object<Avatar>(avatar_obj_add)));
        let avatar = borrow_global_mut<Avatar>(avatar_obj_add);
        assert_passed_interval_timeframe(avatar.last_roll_timestamp, game.customs.interval);

        let rolled = get_new_number();
        avatar.last_rolled_num = rolled;

        event::emit_event<RollDiceEvent>(
            &mut game.roll_dice_events,
            RollDiceEvent{
                game_id,
                user: signer::address_of(user),
                number: rolled,
                timestamp: timestamp::now_seconds()
            }
        );

        avatar.last_roll_timestamp = timestamp::now_seconds();
    }

    public entry fun game_won(admin: &signer, game_id: u64, user: address, avatar_obj_add: address, snakes: u64, ladders: u64) acquires State, Avatar {
        assert_game_initialized(game_id);
        assert_admin(signer::address_of(admin));
        let state = borrow_global_mut<State>(@deployer);
        let game = simple_map::borrow_mut(&mut state.games, &game_id);
        assert_game_has_started(game.is_started);
        assert_game_not_finished(game.is_finished);
        let avatar = borrow_global_mut<Avatar>(avatar_obj_add);
        //          - GAME_STATUS
        //          - SNAKES_ENCOUNTERED
        //          - LADDERS_CLIMBED
        //          - TIMESTAMP_WON
        property_map::update(
            &mut avatar.property_mutator_ref,
            &string::utf8(*vector::borrow(&PROP_KEYS, 0)),
            string::utf8(*vector::borrow(&PROP_KEYS, 0)),
            b"WON"
        );
        property_map::update(
            &mut avatar.property_mutator_ref,
            &string::utf8(*vector::borrow(&PROP_KEYS, 1)),
            string::utf8(*vector::borrow(&PROP_KEYS, 1)),
            bcs::to_bytes(&snakes)
        );
        property_map::update(
            &mut avatar.property_mutator_ref,
            &string::utf8(*vector::borrow(&PROP_KEYS, 2)),
            string::utf8(*vector::borrow(&PROP_KEYS, 2)),
            bcs::to_bytes(&ladders)
        );
        property_map::update(
            &mut avatar.property_mutator_ref,
            &string::utf8(*vector::borrow(&PROP_KEYS, 3)),
            string::utf8(*vector::borrow(&PROP_KEYS, 3)),
            bcs::to_bytes(&timestamp::now_seconds())
        );

        event::emit_event<GameWonEvent>(
            &mut game.game_won_events,
            GameWonEvent{
                game_id,
                user,
                timestamp: timestamp::now_seconds()
            }
        );
    }

    public entry fun cancel_game(user: &signer, game_id: u64) acquires State{
        assert_game_initialized(game_id);
        let user_add = signer::address_of(user);
        let state = borrow_global_mut<State>(@deployer);
        let game = simple_map::borrow_mut(&mut state.games, &game_id);
        assert_game_creator(user_add, game.game_creator);
        assert_game_not_started(game.is_started);
        let res_signer = account::create_signer_with_capability(&game.res_cap);
        let pool = coin::balance<AptosCoin>(signer::address_of(&res_signer));
        let split = vector::length(&game.nft_obj_add);
        if(pool != 0){
            while(vector::length(&game.nft_obj_add) != 0){
                let owner = object::owner(object::address_to_object<Avatar>(*vector::borrow(&game.nft_obj_add,0)));
                coin::transfer<AptosCoin>(&res_signer, owner, pool/split);
                vector::remove(&mut game.nft_obj_add, 0);
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

    inline fun get_new_number(): u64 {
        let num = randomness::u64_range(1, 7);
        num + randomness::u64_range(1, 7)
    }

    inline fun edit_nft(nft: address, new_status: String){
        assert_admin(@admin);
        let status = string::utf8(b"Status: ");
        string::append(&mut status, new_status);
        let card = borrow_global<Avatar>(nft);
        token::set_description(&card.mutator_ref, status);
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
        vector::length(&game.buyers)
    }

    //==============================================================================================
    // Validation functions
    //==============================================================================================

    inline fun assert_admin(admin: address) {
        assert!(admin == @admin, ERROR_SIGNER_NOT_ADMIN);
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

    inline fun assert_passed_interval_timeframe(start_timestamp: u64, interval: u64) {
        debug::print(&(timestamp::now_seconds() >= (start_timestamp + interval)));
        assert!(timestamp::now_seconds() >= start_timestamp + interval, ERROR_NEED_TO_WAIT_INTERVAL_TIME);
    }

    inline fun assert_one_user_one_card_purchase(buyers: vector<address>, user: address){
        assert!(!vector::contains(&buyers, &user), ERROR_USER_ALREADY_BOUGHT_ONE);
    }

    inline fun assert_game_creator(user: address, creator: address){
        assert!(user == creator, ERROR_NOT_GAME_CREATOR);
    }

    inline fun assert_avatar_owner(user: address, owner: address){
        assert!(user == owner, ERROR_NOT_AVATAR_OWNER);
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

        assert!(state.game_count == 1, 12);
        let game = simple_map::borrow(&state.games, &0);
        assert!(game.game_name == game_name, 12);
        assert!(event::counter(&state.create_game_events) == 1, 12);
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
        join_game(joiner, 0, token_uri);

        let state = borrow_global<State>(deployer_address);
        let game = simple_map::borrow(&state.games, &0);
        assert!(vector::length(&game.buyers) == 1, 12);
        assert!(event::counter(&state.create_game_events) == 1, 12);
        assert!(event::counter(&game.join_game_events) == 1, 12);

        let seed = string_utils::format1(&b"SL#{}", 0);
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
    fun test_roll_dice_success(
        deployer: &signer,
        game_creator: &signer,
        joiner: &signer
    ) acquires State, Avatar {
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
        let interval = 1;
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
        join_game(joiner, 0, token_uri);

        start_game(0);

        let expected_nft_token_address;
        {
            let state = borrow_global_mut<State>(deployer_address);
            let game = simple_map::borrow_mut(&mut state.games, &0);

            assert!(vector::length(&game.buyers) == 1, 12);
            assert!(event::counter(&state.create_game_events) == 1, 12);
            assert!(event::counter(&game.join_game_events) == 1, 12);
            assert!(event::counter(&state.game_started_events) == 1, 12);

            let seed = string_utils::format1(&b"SL#{}", 0);
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

        };

        timestamp::fast_forward_seconds(interval + 1);
        roll_dice(joiner, 0, expected_nft_token_address);
        let avatar = borrow_global<Avatar>(expected_nft_token_address);
        assert!(avatar.last_rolled_num != 0, 10);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

    }

}
