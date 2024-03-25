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
   struct InvalidSuiAmountError has drop {}
   struct MismatchedCardError has drop {}
   struct AlreadyHasWinnerLuckyNumberError has drop {}
   struct InvalidDrandRoundError has drop {}
   struct InvalidWinnerLuckyNumberError has drop {}
   struct EmptyWinnerLuckyNumberError has drop {}
   struct UnauthorizedAccessError has drop {}

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
       // admin address
       admin_address: address,
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
       let sender = tx_context::sender(ctx);
       let cafe = Cafe {
           id: object::new(ctx),
           sui: balance::zero(),
           participants: 0,
           owner: sender,
           lucky_number_2_owner: vec_map::empty(),
           lucky_number_2_card_id: vec_map::empty(),
           owner_2_card_count: vec_map::empty(),
           winner_lucky_number: option::none(),
           base_drand_round: base_drand_round,
       };

       transfer::public_share_object(cafe);

       transfer::transfer(
           Admin {
               id: object::new(ctx),
               admin_address: sender,
           },
           sender,
       );
   }

   // buy a card for the cafe object with the provided sui amount.
   public entry fun buy_cafe_card<A: drop>(
       cafe: &mut Cafe,
       sui: Coin<SUI>,
       ctx: &mut TxContext,
   ) {
       let sui_amount = coin::value(&sui);
       if (sui_amount % 5 != 0) {
           abort InvalidSuiAmountError {}
       }

       let sui_balance = coin::into_balance(sui);

       // add SUI to the cafe's balance
       balance::join(&mut cafe.sui, sui_balance);

       let recipient = tx_context::sender(ctx);

       let card_count = sui_amount / 5;
       let reward_card_count = card_count / 2;
       let total_card_count = card_count + reward_card_count;
       vec_map::insert(
           &mut cafe.owner_2_card_count,
           recipient,
           total_card_count,
       );

       transfer_cards(
           cafe,
           recipient,
           card_count,
           reward_card_count,
           ctx,
       );
   }

   fun transfer_cards<A: drop>(
       cafe: &mut Cafe,
       recipient: address,
       card_count: u64,
       reward_card_count: u64,
       ctx: &mut TxContext,
   ) {
       let total_card_count = card_count + reward_card_count;
       let i = 0_u64;
       while (i < total_card_count) {
           let card = Card {
               id: object::new(ctx),
               cafe_id: object::uid_to_inner(&cafe.id),
               lucky_number: cafe.participants,
           };

           vec_map::insert(
               &mut cafe.lucky_number_2_owner,
               cafe.participants,
               recipient,
           );

           vec_map::insert(
               &mut cafe.lucky_number_2_card_id,
               cafe.participants,
               object::uid_to_inner(&card.id),
           );

           cafe.participants = cafe.participants + 1;

           transfer::transfer(card, recipient);

           i = i + 1;
       }
   }

   // buy a coffee for the cafe object with the provided card object.
   public entry fun buy_coffee<A: drop>(
       cafe: &mut Cafe,
       card: Card,
       ctx: &mut TxContext,
   ) {
       let Card {
           id,
           cafe_id,
           lucky_number,
       } = card;
       if (cafe_id != object::uid_to_inner(&cafe.id)) {
           abort MismatchedCardError {}
       }

       transfer::transfer(
           Coffee {
               id: object::new(ctx),
               cafe_id,
           },
           tx_context::sender(ctx),
       );

       object::delete(id);

       vec_map::remove(&mut cafe.lucky_number_2_owner, &lucky_number);
       vec_map::remove(&mut cafe.lucky_number_2_card_id, &lucky_number);

       let card_count = vec_map::get_mut(
           &mut cafe.owner_2_card_count,
           &tx_context::sender(ctx),
       );
       *card_count = *card_count - 1;
   }

   // get the lucky number for the cafe object with the provided drand signature.
   public entry fun get_lucky_number<A: drop>(
       cafe: &mut Cafe,
       current_round: u64,
       drand_sig: vector<u8>,
   ) {
       if (cafe.winner_lucky_number != option::none()) {
           abort AlreadyHasWinnerLuckyNumberError {}
       }

       if (cafe.base_drand_round >= current_round) {
           abort InvalidDrandRoundError {}
       }

       verify_drand_signature(drand_sig, current_round);
       cafe.base_drand_round = current_round;

       let digest = derive_randomness(drand_sig);
       cafe.winner_lucky_number =
           option::some(safe_selection(cafe.participants, &digest));

       let lucky_number = option::borrow(&cafe.winner_lucky_number);

       if (!vec_map::contains(&cafe.lucky_number_2_owner, lucky_number)) {
           abort InvalidWinnerLuckyNumberError {}
       }

       let owner = vec_map::get(&cafe.lucky_number_2_owner, lucky_number);
       let card_id = vec_map::get(&cafe.lucky_number_2_card_id, lucky_number);

       event::emit(WinnerLuckyNumberCreated {
           cafe_id: object::uid_to_inner(&cafe.id),
           lucky_number: *lucky_number,
           owner: *owner,
           card_id: *card_id,
       });
   }

   // get the reward for the cafe object with the provided lucky card object.
   public entry fun get_reward_with_lucky_card<A: drop>(
       cafe: &mut Cafe,
       card: Card,
       ctx: &mut TxContext,
   ) {
       let Card {
           id,
           cafe_id,
           lucky_number,
       } = card;

       if (cafe_id != object::uid_to_inner(&cafe.id)) {
           abort MismatchedCardError {}
       }

       let winner_lucky_number = option::borrow(&cafe.winner_lucky_number);
       if (winner_lucky_number != &lucky_number) {
           abort InvalidWinnerLuckyNumberError {}
       }

       vec_map::remove(&mut cafe.lucky_number_2_owner, &lucky_number);
       vec_map::remove(&mut cafe.lucky_number_2_card_id, &lucky_number);

       let recipient = tx_context::sender(ctx);

       let card_count = vec_map::get(&cafe.owner_2_card_count, &recipient);

       let reward_card_count = math::min(*card_count, MAX_REWARD_CARD_COUNT);

       cafe.winner_lucky_number = option::none();
       object::delete(id);

       let card_count = vec_map::get_mut(
           &mut cafe.owner_2_card_count,
           &tx_context::sender(ctx),
       );
       *card_count = *card_count - 1;

       transfer_cards(
           cafe,
           recipient,
           0,
           reward_card_count,
           ctx,
       );
   }

   // remove the winner lucky number of the cafe object.
   public entry fun remove_lucky_number<A: drop>(
       _admin: &Admin,
       cafe: &mut Cafe,
   ) {
       if (tx_context::sender(@_admin) != _admin.admin_address) {
           abort UnauthorizedAccessError {}
       }

       if (cafe.winner_lucky_number == option::none()) {
           abort EmptyWinnerLuckyNumberError {}
       }

       cafe.winner_lucky_number = option::none();
   }

   // get the sender's card count of the cafe object.
   public entry fun get_sender_card_count<A: drop>(
       cafe: &Cafe,
       ctx: &mut TxContext,
   ): u64 {
       let sender = tx_context::sender(ctx);
       *vec_map::get(&cafe.owner_2_card_count, &sender)
   }

   #[test_only]
   public fun init_for_testing(ctx: &mut TxContext) {
       create_cafe(0, ctx)
   }
}
