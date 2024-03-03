# SUI Move Lucky Cafe

## 1 Entity Definition

- Coffee Shop (`Cafe`)
- Coffee Card (`Card`)
- Coffee (`Coffee`)
- Owner (`Owner`, `Admin`)
- Customer

## 2 Entity Relationship

- Any user can create a coffee shop (`Cafe`) and become the owner (`Owner`, `Admin`)
- Customers can buy coffee cards (`Card`)
- Coffee cards (`Card`) can be exchanged for coffee (`Coffee`) on a `1:1` basis

## 3 Economic Design

- Every 5 GAS can buy a coffee card, buy two and get one free, that is, 10 GAS can buy 3 coffee cards, and so on
- A coffee Card can be exchanged for a cup of coffee, and after the coffee is exchanged, this coffee card becomes invalid
- Each coffee card has a unique lucky number (`Lucky Number`). Anyone can trigger the contract interface to randomly select a lucky number. If the selected lucky number corresponds to a used coffee card, a new lucky number can be drawn again
- The holder of the coffee card corresponding to the lucky number can use this lucky number coffee card to get a reward. The reward is to double the number of coffee cards in hand, with a single reward limit of 10 coffee cards. For example: Alice holds 4 coffee cards, one of which has a lucky number of 7. When the randomly selected lucky number is also 7, then good luck happens, `Alice` can destroy this lucky coffee card and double the number of coffee cards she holds.
- After the lucky number is drawn randomly, it cannot be drawn again until the corresponding coffee card is redeemed. However, the owner has admin rights and can delete the randomly generated lucky number so that a new lucky number can be selected, to avoid customers not claiming their rewards in time.

## 4 API Definition

- **create_cafe**: create a new cafe object with the provided base_drand_round and initializes its fields.
- **buy_cafe_card**: buy a card for the cafe object with the provided sui amount.
- **buy_coffee**: buy a coffee for the cafe object with the provided card object.
- **get_lucky_number**: get the lucky number for the cafe object with the provided drand signature.
- **get_reward_with_lucky_card**: get the reward for the more cafe object with the provided lucky card object.
- **remove_lucky_number**: remove the winner lucky number of the cafe object.
- **get_sender_card_count**: get the sender's card count of the cafe object.

