#[test_only]
module bityoume::lucky_cafe_test {
    use bityoume::lucky_cafe::{Self, Cafe, Card};

    #[test]
    fun use_cafe_card_by_coffee_test() {
        use sui::test_scenario;
        use sui::test_utils::assert_eq;
        use sui::coin::mint_for_testing;

        let jason = @0x11;
        let alice = @0x22;
        let bob = @0x33;

        let scenario_val = test_scenario::begin(jason);
        let scenario = &mut scenario_val;

        // jason create a Cafe share object and got Admin object
        test_scenario::next_tx(scenario, jason);
        {
            lucky_cafe::init_for_testing(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, alice);
        {
            let cafe = test_scenario::take_shared<Cafe>(scenario);
            let cafe_ref = &mut cafe;
            let coin = mint_for_testing(10, test_scenario::ctx(scenario));
            lucky_cafe::buy_cafe_card(cafe_ref, coin, test_scenario::ctx(scenario));

            let card_count = lucky_cafe::get_sender_card_count(cafe_ref, test_scenario::ctx(scenario));
            assert_eq(card_count, 3);

            test_scenario::return_shared(cafe);
        };

        test_scenario::next_tx(scenario, bob);
        {
            let cafe = test_scenario::take_shared<Cafe>(scenario);
            let cafe_ref = &mut cafe;
            let coin = mint_for_testing(5, test_scenario::ctx(scenario));
            lucky_cafe::buy_cafe_card(cafe_ref, coin, test_scenario::ctx(scenario));

            let card_count = lucky_cafe::get_sender_card_count(cafe_ref, test_scenario::ctx(scenario));
            assert_eq(card_count, 1);

            test_scenario::return_shared(cafe);
        };

        test_scenario::next_tx(scenario, alice);
        {
            let cafe = test_scenario::take_shared<Cafe>(scenario);
            let cafe_ref = &mut cafe;

            let card = test_scenario::take_from_sender<Card>(scenario);

            lucky_cafe::buy_coffee(cafe_ref, card, test_scenario::ctx(scenario));

            let card_count = lucky_cafe::get_sender_card_count(cafe_ref, test_scenario::ctx(scenario));
            assert_eq(card_count, 2);

            test_scenario::return_shared(cafe);
        };

        test_scenario::end(scenario_val);
    }
}