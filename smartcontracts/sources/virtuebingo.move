module admin::virtuebingo {

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
    use aptos_token_objects::royalty;
    use aptos_token_objects::collection;
    use aptos_framework::option;
    use aptos_framework::event::{Self, EventHandle};
    use std::string_utils;

    use aptos_framework::timestamp;
    use aptos_std::simple_map::{Self, SimpleMap};
    //use std::debug;

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
    const ERROR_OTHER: u64 = 4;

    //==============================================================================================
    // Constants
    //==============================================================================================

    // Seed for resource account creation
    const SEED: vector<u8> = b"virtuebingo";

    //The minimum price of a NFT (in APT).
    const MINT_PRICE: u64 = 10000000; // 0.1

    //Wait interval between each randomizer call
    const INTERVAL: u64 = 60000; // 1 minute


    // NFT Collection Info
    const COLLECTION_NAME: vector<u8> = b"VirtueBingo";
    const COLLECTION_DESCRIPTION: vector<u8> = b"VirtueBingo - Bingo Onchain powered by Aptos";
    const COLLECTION_URI: vector<u8> = b"ipfs://bafybeiducfeukqcariynevzzpjyd4f3m7yzy3aeipug6tdpx2on2rqezla";

    const TOKEN_URI: vector<u8> = b"ipfs://bafybeihkz7uhpuszpmpme7iukexcveb7tk4pf4g5sdtmnv42ic6yhukfxa/";

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
    }

    /*
        Struct holding data about a single game
    */
    struct Game has store {
        // List of players participating in a game.
        // Every inner inner vector of the value represents a single row of a bingo sheet.
        // i.e. vector<Card>
        cards: vector<vector<vector<u8>>>,
        // Timestamp of game's start
        start_timestamp: u64,
        // Numbers drawn by the admin for a game
        drawn_numbers: vector<u8>,
        // Boolean flag indicating if a game is ongoing or has finished
        is_finished: bool,
        // Events
        draw_number_events: EventHandle<DrawNumberEvent>,
        join_game_events: EventHandle<JoinGameEvent>,
        bingo_events: EventHandle<BingoEvent>
    }

    /*
        Information to be used in the module
    */
    struct State has key {
        // List of games
        games: SimpleMap<String, Game>,
        // number of games
        game_count: u64,
        // SignerCapability instance to recreate PDA's signer
        cap: SignerCapability,
        // Events
        create_game_events: EventHandle<CreateGameEvent>,
        cancel_game_events: EventHandle<CancelGameEvent>
    }

    //==============================================================================================
    // Event structs
    //==============================================================================================
    struct CreateGameEvent has store, drop {
        game_name: String,
        game_symbol: String,
        start_timestamp: u64,
        timestamp: u64
    }

    struct DrawNumberEvent has store, drop {
        game_name: String,
        number: u8,
        timestamp: u64
    }

    struct JoinGameEvent has store, drop {
        game_name: String,
        player: address,
        card: vector<vector<u8>>,
        timestamp: u64
    }

    struct BingoEvent has store, drop {
        game_name: String,
        player: address,
        timestamp: u64
    }

    struct CancelGameEvent has store, drop {
        game_name: String,
        timestamp: u64
    }
    //==============================================================================================
    // Functions
    //==============================================================================================

    fun init_module(admin: &signer) {
        assert_admin(signer::address_of(admin));
        let (resource_signer, resource_cap) = account::create_resource_account(admin, SEED);

        let royalty = royalty::create(5,100,@admin);

        // Create NFT collection with an unlimited supply and the following params:
        collection::create_unlimited_collection(
            &resource_signer,
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(COLLECTION_NAME),
            option::some(royalty),
            string::utf8(COLLECTION_URI)
        );

        // Create the State global resource and move it to the admin account
        let state = State{
            games: simple_map::new(),
            game_count: 0,
            cap: resource_cap,
            create_game_events: account::new_event_handle<CreateGameEvent>(admin),
            cancel_game_events: account::new_event_handle<CancelGameEvent>(admin)
        };
        move_to<State>(admin, state);
    }

    // Create Bingo Game
    public entry fun create_game(admin: &signer, game_name: String, game_symbol: String, start_time: u64) acquires State {
        let admin_add = signer::address_of(admin);
        assert_admin(admin_add);
        assert_start_timestamp_is_valid(start_time);
        let state = borrow_global_mut<State>(admin_add);
        let new_game = Game{
            cards: vector::empty(),
            start_timestamp: start_time,
            drawn_numbers: vector::empty<u8>(),
            is_finished: false,
            draw_number_events: account::new_event_handle<DrawNumberEvent>(admin),
            join_game_events: account::new_event_handle<JoinGameEvent>(admin),
            bingo_events: account::new_event_handle<BingoEvent>(admin)
        };

        simple_map::add(&mut state.games, game_name, new_game);
        state.game_count = state.game_count + 1;

        event::emit_event<CreateGameEvent>(
            &mut state.create_game_events,
            CreateGameEvent{
                game_name,
                game_symbol,
                start_timestamp: start_time,
                timestamp: timestamp::now_seconds()
            }
        );
    }

    public entry fun join_game(user: &signer, game_name: String, token_uri: String) acquires State {
        assert_game_initialized(game_name);
        let user_add = signer::address_of(user);
        assert_enough_apt(user_add);
        // Payment
        coin::transfer<AptosCoin>(user, @admin, MINT_PRICE);
        let state = borrow_global_mut<State>(@admin);
        let game = simple_map::borrow_mut(&mut state.games, &game_name);
        let card = generate_card_internal();
        while(vector::contains(&game.cards, &card)){
            card = generate_card_internal();
        };
        vector::push_back(&mut game.cards, card);
        // debug::print(vector::borrow(&card, 0));
        // debug::print(vector::borrow(&card, 1));
        // debug::print(vector::borrow(&card, 2));

        let res_signer = account::create_signer_with_capability(&state.cap);
        let royalty = royalty::create(5,100,@admin);
        let token_name = game_name;
        string::append(&mut token_name, string_utils::format1(&b" #{}",vector::length(&game.cards)));
        let status = string_utils::format1(&b"Status:{}",b"Open");
        // Create a new named token:
        let token_const_ref = token::create_named_token(
            &res_signer,
            string::utf8(COLLECTION_NAME),
            status,
            token_name,
            option::some(royalty),
            token_uri //todo: how is the token uri generated or looks like?
        );
        let obj_signer = object::generate_signer(&token_const_ref);
        let obj_add = object::address_from_constructor_ref(&token_const_ref);

        // Transfer the token to the user account
        object::transfer_raw(&res_signer, obj_add, user_add);

        // Create the ErebrusToken object and move it to the new token object signer
        let new_nft_token = Card {
            mutator_ref: token::generate_mutator_ref(&token_const_ref),
            burn_ref: token::generate_burn_ref(&token_const_ref),
        };

        move_to<Card>(&obj_signer, new_nft_token);
        event::emit_event<JoinGameEvent>(
            &mut game.join_game_events,
            JoinGameEvent{
                game_name,
                player: user_add,
                card,
                timestamp: timestamp::now_seconds()
            }
        );
    }

    //==============================================================================================
    // Helper functions
    //==============================================================================================


    inline fun generate_card_internal(): vector<vector<u8>> {
        let row_1 = vector[0,0,0,0,0,0,0,0,0];
        let non_empty_cells = non_empty_cell_pos();
        let i = 0;
        while(i < vector::length(&non_empty_cells)){
            let col = *vector::borrow(&non_empty_cells, i);
            let no = randomness::u8_range(1, 11) + col*10;
            vector::push_back(&mut row_1, no);
            vector::swap_remove(&mut row_1, i);
            i = i + 1;
        };
        let row_2 = generate_row_n(row_1);
        let drawn_num = row_1;
        vector::append(&mut drawn_num, row_2);
        let row_3 = generate_row_n(drawn_num);
        //todo: check on destroying unecessary storage
        vector[row_1,row_2,row_3]
    }

    inline fun generate_row_n(drawn_num: vector<u8>): vector<u8> {
        let row_n = vector[0,0,0,0,0,0,0,0,0];
        let non_empty_cells = non_empty_cell_pos();
        let i = 0;
        while(i < vector::length(&non_empty_cells)){
            let col = *vector::borrow(&non_empty_cells, i);
            let filled = false;
            while (!filled){
                let no = randomness::u8_range(1, 11) + col*10;
                if(!vector::contains(&drawn_num, &no)){
                    filled = true;
                    vector::push_back(&mut row_n, no);
                };
            };
            vector::swap_remove(&mut row_n, i);
            i = i + 1;
        };
        row_n
    }

    inline fun non_empty_cell_pos(): vector<u8> {
        let output = vector::empty<u8>();
        while (vector::length(&output) < 5){
            let pos = randomness::u8_range(0, 9);
            if(!vector::contains(&output, &pos)){
                vector::push_back(&mut output, pos);
            }
        };
        output
    }

    //==============================================================================================
    // View functions
    //==============================================================================================

    //==============================================================================================
    // Validation functions
    //==============================================================================================

    inline fun assert_admin(admin: address) {
        assert!(admin == @admin, ERROR_SIGNER_NOT_ADMIN);
    }

    inline fun assert_start_timestamp_is_valid(start_timestamp: u64) {
        assert!(start_timestamp >= timestamp::now_seconds(),ERROR_INVALID_START_TIMESTAMP);
    }

    inline fun assert_game_initialized(game_name: String) acquires State {
        assert!(exists<State>(@admin),ERROR_GAME_NOT_INITIALIZED);
        let state = borrow_global<State>(@admin);
        assert!(simple_map::contains_key(&state.games, &game_name),ERROR_GAME_NOT_INITIALIZED);
    }

    inline fun assert_enough_apt(user: address) {
        assert!(coin::balance<AptosCoin>(user) >= MINT_PRICE, ERROR_INSUFFICIENT_BALANCE);
    }


    //==============================================================================================
    // Test functions
    //==============================================================================================

    #[test(admin = @admin)]
    fun test_init_module_success(
        admin: &signer
    ) acquires State {
        let admin_address = signer::address_of(admin);
        account::create_account_for_test(admin_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        init_module(admin);

        let expected_resource_account_address = account::create_resource_address(&admin_address, SEED);
        assert!(account::exists_at(expected_resource_account_address), 0);

        let state = borrow_global<State>(admin_address);
        assert!(
            account::get_signer_capability_address(&state.cap) == expected_resource_account_address,
            0
        );

        let expected_collection_address = collection::create_collection_address(
            &expected_resource_account_address,
            &string::utf8(COLLECTION_NAME)
        );
        let collection_object = object::address_to_object<collection::Collection>(expected_collection_address);
        assert!(
            collection::creator<collection::Collection>(collection_object) == expected_resource_account_address,
            4
        );
        assert!(
            collection::name<collection::Collection>(collection_object) == string::utf8(COLLECTION_NAME),
            4
        );
        assert!(
            collection::description<collection::Collection>(collection_object) == string::utf8(COLLECTION_DESCRIPTION),
            4
        );
        assert!(
            collection::uri<collection::Collection>(collection_object) == string::utf8(COLLECTION_URI),
            4
        );

        assert!(event::counter(&state.create_game_events) == 0, 4);
    }

    #[test(admin = @admin, user = @0xA)]
    fun test_join_game_success(
        admin: &signer,
        user: &signer
    ) acquires State {
        let admin_address = signer::address_of(admin);
        let user_address = signer::address_of(user);
        account::create_account_for_test(admin_address);
        account::create_account_for_test(user_address);

        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);
            coin::register<AptosCoin>(user);
            coin::register<AptosCoin>(admin);
            init_module(admin);
            aptos_coin::mint(&aptos_framework, user_address, MINT_PRICE);

        let start_time = timestamp::now_seconds() + 2*INTERVAL;
        let game_name = string::utf8(b"name");
        let game_symbol = string::utf8(b"symbol");
        create_game(admin, game_name, game_symbol, start_time);
        join_game(user, game_name, string::utf8(TOKEN_URI));
        let state = borrow_global<State>(admin_address);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        assert!(event::counter(&state.create_game_events) == 1, 4);
    }

}