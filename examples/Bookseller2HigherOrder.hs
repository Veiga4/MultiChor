{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds      #-}
{-# LANGUAGE LambdaCase     #-}

{-
# Higher-order bookseller

This example implements the higher-order bookseller protocol where
how the buyer decides whether to buy the book is abstracted as an
argument, making it a higher-order choreography.
For a general description of the protocol, see [`bookseller-1-simple`](../bookseller-1-simple).

We provide two decision-making functions:

- `mkDecision1` only checks if buyer's budget is greater than the
  book's price, which has the same behavior as [`bookseller-1-simple`](../bookseller-1-simple)
- `mkDecision2` asks buyer2 how much they're willing to contribute and
  checks if the buyer's budget is greater than the book's price minus
  buyer2's contribution.

By default, this example uses `mkDecision2`. To use `mkDecision1`,
change the line `choreo = bookseller mkDecisiont2` to `choreo = bookseller mkDecision1`.

## Running the protocol

```bash
# in shell 1
cabal run bookseller-2-higher-order buyer

# in shell 2
cabal run bookseller-2-higher-order buyer2

# in shell 3
cabal run bookseller-2-higher-order seller

# in shell 1
> Enter the title of the book to buy
Homotopy Type Theory

# in shell 2
> How much you're willing to contribute?
100

# in shell 1
The book will be delivered on 2023-01-01
```

Note previously in [`bookseller-1-simple`](../bookseller-1-simple),
the buyer can't buy `Homotopy Type Theory` as it's out of the budget,
but with buyer2's contribution, now it can.
-}

module Bookseller2HigherOrder where

import Choreography
import Data.Proxy
import Data.Time
import System.Environment

buyer :: Proxy "buyer"
buyer = Proxy

seller :: Proxy "seller"
seller = Proxy

buyer2 :: Proxy "buyer2"
buyer2 = Proxy

-- | `bookseller` is a choreography that implements the bookseller protocol.
-- This version takes a choreography `mkDecision` that implements the decision making process.
bookseller :: (Int @ "buyer" -> Choreo IO (Bool @ "buyer")) -> Choreo IO (Maybe Day @ "buyer")
bookseller mkDecision = do
  -- the buyer reads the title of the book and sends it to the seller
  title <- (buyer, \_ -> do
               putStrLn "Enter the title of the book to buy"
               getLine
           )
           ~~> seller

  -- the seller checks the price of the book and sends it to the buyer
  price <- (seller, \un -> return $ priceOf (un title)) ~~> buyer

  -- the buyer makes a decision using the `mkDecision` choreography
  decision <- mkDecision price

  -- if the buyer decides to buy the book, the seller sends the delivery date to the buyer
  cond (buyer, decision) \case
    True  -> do
      deliveryDate <- (seller, \un -> return $ deliveryDateOf (un title)) ~~> buyer

      buyer `locally` \un -> do
        putStrLn $ "The book will be delivered on " ++ show (un deliveryDate)
        return $ Just (un deliveryDate)

    False -> do
      buyer `locally` \_ -> do
        putStrLn "The book's price is out of the budget"
        return Nothing

-- | `mkDecision1` checks if buyer's budget is greater than the price of the book
mkDecision1 :: Int @ "buyer" -> Choreo IO (Bool @ "buyer")
mkDecision1 price = do
  buyer `locally` \un -> return $ un price < budget

-- | `mkDecision2` asks buyer2 how much they're willing to contribute and checks
-- if the buyer's budget is greater than the price of the book minus buyer2's contribution
mkDecision2 :: Int @ "buyer" -> Choreo IO (Bool @ "buyer")
mkDecision2 price = do
  contrib <- (buyer2, \_ -> do
                 putStrLn "How much you're willing to contribute?"
                 read <$> getLine
             )
             ~~> buyer
  buyer `locally` \un -> return $ un price - un contrib <= budget

budget :: Int
budget = 100

priceOf :: String -> Int
priceOf "Types and Programming Languages" = 80
priceOf "Homotopy Type Theory"            = 120

deliveryDateOf :: String -> Day
deliveryDateOf "Types and Programming Languages" = fromGregorian 2022 12 19
deliveryDateOf "Homotopy Type Theory"            = fromGregorian 2023 01 01

main :: IO ()
main = do
  [loc] <- getArgs
  case loc of
    "buyer"  -> runChoreography cfg choreo "buyer"
    "seller" -> runChoreography cfg choreo "seller"
    "buyer2" -> runChoreography cfg choreo "buyer2"
  return ()
  where
    choreo = bookseller mkDecision2

    cfg = mkHttpConfig [ ("buyer",  ("localhost", 4242))
                       , ("seller", ("localhost", 4343))
                       , ("buyer2", ("localhost", 4444))
                       ]