{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE TemplateHaskell #-}

module Lottery where

import CLI
import Choreography
import Choreography.Network.Http (API)
import Control.Monad (replicateM)
import Control.Monad.Cont (MonadIO, liftIO)
import Data.Maybe (fromJust)
import Logic.Classes (refl)
import System.Environment
import System.Random (randomIO)

{- | Issue #27
TODO just a stub for now
TODO make this nicer when we have fanin and fanout to avoid redundent code
-}

-- Multiple servers
-- Multiple clients
$(mkLoc "server1")
$(mkLoc "server2")

$(mkLoc "client1")
$(mkLoc "client2")

-- TODO fix later
type Fp = Integer -- field elements

type Participants = ["client1", "client2", "server1", "server2"]

-- Random field in [1 to n]
random :: CLI m Fp
random = liftIO randomIO

lottery2 ::
    forall clients servers census m _h1 _h2 _hs.
    ( KnownSymbols clients
    , KnownSymbols servers
    , (_h1 ': _h2 ': _hs) ~ servers
    , MonadIO m
    ) =>
    Subset clients census -> -- A proof that clients are part of the census
    Subset servers census -> -- A proof that servers are part of the census
    Choreo census (CLI m) ()
lottery2 clients servers = do
    secret <- parallel clients (\_ _ -> getInput "secret:")

    -- A lookup table that maps Server to share to send
    shares <-
        clients `parallel` \mem un -> do
            freeShares :: [Fp] <- case serverNames of
                [] -> return [] -- This can't actually happen/get used...
                _ : others -> replicateM (length others) random
            let lastShare = un mem secret - sum freeShares -- But freeShares could really be empty!
            return $ serverNames `zip` (lastShare : freeShares)

    -- Send 1 share from each client to each server
    servers
        `fanOut` ( \server ->
                    fanIn
                        clients
                        (inSuper servers server @@ nobody)
                        ( \client ->
                            ( inSuper clients client
                            , ( \un ->
                                    let serverName = toLocTm server
                                        share = fromJust $ lookup serverName $ un client shares
                                     in return share
                              )
                            )
                                ~~> inSuper servers server
                                @@ nobody
                        )
                 )

    -- servers commit to a random value. Better name Secret? Hash?
    randomServerValue <- parallel servers (\_ _ -> random)

    pure undefined
  where
    serverNames = toLocs servers

-- TODO arbitrary number of clients and participants >= 2 would be nice
-- I'll move this later just like having the above for reference
-- TODO extend to multiple servers later
-- The census is the list of parties present in the cheorography
-- We want to think about how pe9ople use this API
-- Instead of listing the census explicityl
-- Make it polymorphic
-- And instead make this a program where we take proofs that members are part of that polymorphic census
-- e.g. clients are a subset of some set of clients server
lottery :: forall clients m. (KnownSymbols clients) => Choreo ("server1" ': "server2" ': clients) (CLI m) ()
lottery =
    undefined -- do
    -- A proof that a subset clients is a subset of clients with servers?
    -- let clients = refl
    -- s <- clients `parallel` \_ _ -> secretShare

        -- Create shares
        -- client1Shares <- client1 `locally` (\_ -> secretShare)
        -- client2Shares <- client2 `locally` (\_ -> secretShare)

        -- Client 1 sends shares to all servers {1,2}
        -- client1Share1AtServer1 <- (s, \un -> return $ fst $ un client1 client1Shares) ~~> server1 @@ nobody
        -- client1Share2AtServer2 <- (client1, \un -> return $ snd $ un client1 client1Shares) ~~> server2 @@ nobody

        -- Client 2 sends shares to all servers {1,2}
        -- client2Share1AtServer1 <- (client2, \un -> return $ fst $ un client2 client2Shares) ~~> server1 @@ nobody
        -- client2Share1AtServer2 <- (client2, \un -> return $ snd $ un client2 client2Shares) ~~> server2 @@ nobody

        -- Server each commit to a random value r^j in [1-n]
        -- rj1 <- server1 `locally` \_ -> random
        -- rj2 <- server2 `locally` \_ -> random

        -- -- TODO I think there's a step missing because I don't see what we do with the client secrets

        -- -- The servers each reveal their randomness to all the other servers. R = sum_j(r^j) mod n
        -- rj1AtServer2 <- (server1, \un -> return $ un server1 rj1) ~~> server2 @@ nobody
        -- rj2AtServer1 <- (server2, \un -> return $ un server2 rj2) ~~> server1 @@ nobody

        pure
        undefined

main :: IO ()
main = undefined
