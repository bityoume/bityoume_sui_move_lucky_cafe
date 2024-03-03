module bityoume::lucky_cafe {
    //===============================
    //          Dependencies
    //===============================
    use bityoume::drand_lib::{derive_randomness, verify_drand_signature, safe_selection};
    use sui::object::{Self, UID, ID};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::math;
    use sui::event;
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::option::{Self, Option};
    use sui::vec_map::{Self, VecMap};

    //===============================
    //          Constants
    //===============================
    const MAX_REWARD_CARD_COUNT: u64 = 10;

    //===============================
    //         Error codes
    //===============================
    const EInvalidSuiAmount: u64 = 1;
    const EMismatchedCard: u64 = 2;
    const EAlreadyHasWinnerLuckyNumber: u64 = 3;
    const EInvalidDrandRound: u64 = 4;
    const EInvalidWinnerLuckyNumber: u64 = 5;
    const EEmptyWinnerLuckyNumber: u64 = 6;

    //===============================
    //        Module Structs
    //===============================
    // one Card can only purchase one cup of coffee
    struct Card has key, store {
        // uid of the card object
        id: UID,
        // id of the cafe object
        cafe_id: ID,
        // lucky number of the card object
        lucky_number: u64,
    }

    // represents a cup of coffee object
    struct Coffee has key, store {
        // uid of the coffee object
        id: UID,
        // id of the cafe object
        cafe_id: ID,
    }

    // represents a cafe object
    struct Cafe has key, store {
        // uid of the cafe object
        id: UID,
        // balance of the cafe object
        sui: Balance<SUI>,
        // number of participants in the cafe
        participants: u64,
        // owner of the cafe object
        owner: address,
        // lucky number of the winner of the cafe object
        winner_lucky_number: Option<u64>,
        // base drand round of the cafe object
        base_drand_round: u64,
        // lucky number to owner mapping
        lucky_number_2_owner: VecMap<u64, address>,
        // lucky number to card id mapping
        lucky_number_2_card_id: VecMap<u64, ID>,
        // owner to card count mapping
        owner_2_card_count: VecMap<address, u64>,
    }

    // represents an admin object
    struct Admin has key {
        // uid of the admin object
        id: UID,
    }

    //===============================
    //        Event Structs
    //===============================
    // event emitted when a lucky number is created
    struct WinnerLuckyNumberCreated has copy, drop {
        // id of the cafe object
        cafe_id: ID,
        // id of the card object
        card_id: ID,
        // lucky number of the card object
        lucky_number: u64,
        // owner of the card object
        owner: address,
    }

    //===============================
    //        Functions
    //===============================
    // create a new cafe object with the provided base_drand_round and initializes its fields.
    public entry fun create_cafe(base_drand_round: u64, ctx: &mut TxContext) {
        let cafe = Cafe {
            id: object::new(ctx),
            sui: balance::zero(),
            participants: 0,
            owner: tx_context::sender(ctx),
            lucky_number_2_owner: vec_map::empty(),
            lucky_number_2_card_id: vec_map::empty(),
            owner_2_card_count: vec_map::empty(),
            winner_lucky_number: option::none(),
            base_drand_round: base_drand_round,
        };

        transfer::public_share_object(cafe);

        let recipient= tx_context::sender(ctx); 
        transfer::transfer(
            Admin {
                id: object::new(ctx),
            }, recipient
        );
    }

    // buy a card for the cafe object with the provided sui amount.
    public entry fun buy_cafe_card(cafe: &mut Cafe, sui: Coin<SUI>, ctx: &mut TxContext) {
        let sui_amount = coin::value(&sui);
        assert!(sui_amount % 5 == 0 , EInvalidSuiAmount);

        let sui_balance = coin::into_balance(sui);

        // add SUI to the cafe's balance
        balance::join(&mut cafe.sui, sui_balance);

        let recipient= tx_context::sender(ctx); 

        let card_count = sui_amount / 5;
        let reward_card_count = card_count / 2;
        let i = 0_u64;
        let total_card_count = card_count + reward_card_count;
        vec_map::insert(&mut cafe.owner_2_card_count, recipient, total_card_count);
        while (i < total_card_count ) {

            let card = Card {
                id: object::new(ctx),
                cafe_id:  object::uid_to_inner(&cafe.id),
                lucky_number: cafe.participants,
            };

            vec_map::insert(&mut cafe.lucky_number_2_owner, 
                    cafe.participants, recipient);

            vec_map::insert(&mut cafe.lucky_number_2_card_id, 
                    cafe.participants, object::uid_to_inner(&card.id));

            cafe.participants = cafe.participants + 1;

            transfer::transfer(card, recipient);

            i = i + 1;
        }
    }

    // buy a coffee for the cafe object with the provided card object.
    public entry fun buy_coffee(cafe: &mut Cafe, card: Card, ctx: &mut TxContext) {

        let Card { id, cafe_id, lucky_number} = card;
        assert!(cafe_id == object::uid_to_inner(&cafe.id), EMismatchedCard);

        transfer::transfer(Coffee {
             id: object::new(ctx), cafe_id: cafe_id}, tx_context::sender(ctx));

         object::delete(id);

        vec_map::remove(&mut cafe.lucky_number_2_owner, &lucky_number);
        vec_map::remove(&mut cafe.lucky_number_2_card_id, &lucky_number);

        // cafe.participants = cafe.participants - 1;

        let card_count = vec_map::get_mut(&mut cafe.owner_2_card_count, 
            &tx_context::sender(ctx));
        *card_count = *card_count - 1;
    }

    // get the lucky number for the cafe object with the provided drand signature.
    public entry fun get_lucky_number(cafe: &mut Cafe, current_round: u64, drand_sig: vector<u8>) {
        assert!(cafe.winner_lucky_number == 
            option::none(), EAlreadyHasWinnerLuckyNumber);

        assert!(cafe.base_drand_round < current_round, EInvalidDrandRound);
        verify_drand_signature(drand_sig, current_round);

        cafe.base_drand_round = current_round;

        let digest = derive_randomness(drand_sig);
        cafe.winner_lucky_number= 
            option::some(safe_selection(cafe.participants, &digest));

        let lucky_number = option::borrow(&cafe.winner_lucky_number);

        assert!(vec_map::contains(&cafe.lucky_number_2_owner, lucky_number), 
            EInvalidWinnerLuckyNumber);

        let owner = vec_map::get(&cafe.lucky_number_2_owner, lucky_number);
        let card_id = vec_map::get(&cafe.lucky_number_2_card_id, lucky_number);

        event::emit(WinnerLuckyNumberCreated {
            cafe_id: object::uid_to_inner(&cafe.id),
            lucky_number: *lucky_number,
            owner: *owner,
            card_id: *card_id,
        });
    }

    // get the reward for the more cafe object with the provided lucky card object.
    public entry fun get_reward_with_lucky_card(cafe: &mut Cafe, card: Card, ctx: &mut TxContext) {
        let Card { id, cafe_id, lucky_number} = card;

        assert!(cafe_id == object::uid_to_inner(&cafe.id), EMismatchedCard);

        assert!(cafe.winner_lucky_number == 
            option::some(lucky_number), EInvalidWinnerLuckyNumber);

        vec_map::remove(&mut cafe.lucky_number_2_owner, &lucky_number);
        vec_map::remove(&mut cafe.lucky_number_2_card_id, &lucky_number);

        let recipient= tx_context::sender(ctx); 

        let card_count = vec_map::get(&cafe.owner_2_card_count, &recipient);

        let reward_card_count = math::min(*card_count, MAX_REWARD_CARD_COUNT);

        cafe.winner_lucky_number = option::none();
        object::delete(id);

        let card_count = vec_map::get_mut(&mut cafe.owner_2_card_count, 
            &tx_context::sender(ctx));
        *card_count = *card_count - 1;

        let i = 0_u64;
        while (i < reward_card_count) {
            let card = Card {
                id: object::new(ctx),
                cafe_id:  object::uid_to_inner(&cafe.id),
                lucky_number: cafe.participants,
            };

            vec_map::insert(&mut cafe.lucky_number_2_owner, 
                    cafe.participants, recipient);

            vec_map::insert(&mut cafe.lucky_number_2_card_id, 
                    cafe.participants, object::uid_to_inner(&card.id));

            cafe.participants = cafe.participants + 1;

            *card_count = *card_count + 1;

            transfer::transfer(card, recipient);

            i = i + 1;
        }
    }

    // remove the winner lucky number of the cafe object.
    public entry fun remove_lucky_number(_: &Admin, cafe: &mut Cafe) {
        assert!(cafe.winner_lucky_number != 
            option::none(), EEmptyWinnerLuckyNumber);

        cafe.winner_lucky_number = option::none();
    }

    // get the sender's card count of the cafe object.
    public entry fun get_sender_card_count(cafe: &Cafe, ctx: &mut TxContext): u64 {
        let sender = tx_context::sender(ctx); 
        *vec_map::get(&cafe.owner_2_card_count, &sender)
    }

    #[test_only] public fun init_for_testing(ctx: &mut TxContext) { create_cafe(0, ctx) }
}