{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds      #-}
{-# LANGUAGE LambdaCase     #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE FlexibleInstances #-}

module ObliviousTransfer where

import Choreography
--import Control.Monad
import Control.Monad.Cont (MonadIO, liftIO)
import System.Environment
--import Logic.Propositional (introAnd)
import CLI
import GHC.TypeLits (KnownSymbol)
import Logic.Propositional (introAnd)
import Logic.Classes (Reflexive, refl, Transitive, transitive)


import qualified Sel.PublicKey.Cipher as Cipher

-- Multiple servers
-- Multiple clients
$(mkLoc "client1")
$(mkLoc "client2")
$(mkLoc "client3")

-- p2pSum :: (MonadIO m) => Choreo Participants (CLI m) ()
-- p2pSum = do
--   shares1 <- client1 `locally` \_ -> secretShare
--   shares2 <- client2 `locally` \_ -> secretShare
--   s12s <- (client1, \un -> return $ snd $ un client1 shares1) ~~> client2 @@ nobody
--   s21s <- (client2, \un -> return $ snd $ un client2 shares2) ~~> client1 @@ nobody
--   sum1 <- (client1, \un -> return $ (fst $ un client1 shares1) + (un client1 s21s)) ~~> client1 @@ client2 @@ nobody
--   sum2 <- (client2, \un -> return $ (un client2 s12s) + (fst $ un client2 shares2)) ~~> client1 @@ client2 @@ nobody
--   total1 <- client1 `locally` \un -> return $ (un client1 sum1) + (un client1 sum2)
--   total2 <- client2 `locally` \un -> return $ (un client2 sum1) + (un client2 sum2)
--   client1 `locally_` \un -> putOutput "Total:" $ un client1 total1
--   client2 `locally_` \un -> putOutput "Total:" $ un client2 total2


--ot :: (KnownSymbol p1, KnownSymbol p2, MonadIO m) => Choreo '[p1, p2] (CLI m) ()
-- ot :: (KnownSymbol p1, KnownSymbol p2, KnownSymbols ps, MonadIO m) => Member p1 ps -> Member p2 ps -> Choreo ps (CLI m) ()
ot2Insecure :: (MonadIO m) =>
  Located '["client1"] Bool ->  -- sender
  Located '["client1"] Bool ->  -- sender
  Located '["client2"] Bool ->  -- receiver
  Choreo '["client1", "client2"] (CLI m) (Located '["client2"] Bool)
ot2Insecure b1 b2 s = do
  sr <- (client2 `introAnd` client2, s) ~> client1 @@ nobody
  (client1, \un -> return $ un client1 $ if (un client1 sr) then b1 else b2) ~~> client2 @@ nobody

ot2 :: (KnownSymbol p1, KnownSymbol p2, MonadIO m) =>
  Located '[p1] Bool ->  -- sender
  Located '[p1] Bool ->  -- sender
  Located '[p2] Bool ->  -- receiver
  Choreo '[p1, p2] (CLI m) (Located '[p2] Bool)
ot2 b1 b2 s = do
  let p1 = explicitMember :: Member p1 '[p1, p2]
  let p2 = (inSuper (consSuper refl) explicitMember) :: Member p2 '[p1, p2]

  ks1 <- p2 `_locally` (liftIO Cipher.newKeyPair)
  ks2 <- p2 `_locally` (liftIO Cipher.newKeyPair)
  --pks <- p2 `locally` \un -> return (fst $ un explicitMember ks1, fst $ un explicitMember ks2)

  pks <- (p2, \un -> return (fst $ un explicitMember ks1, fst $ un explicitMember ks2)) ~~> p1 @@ nobody
  encrypted <- p1 `locally` \un -> enc (un explicitMember pks) (un explicitMember b1) (un explicitMember b2)
  sr <- (explicitMember `introAnd` p2, s) ~> p1 @@ nobody
  (p1, \un -> return $ un explicitMember $ if (un explicitMember sr) then b1 else b2) ~~> p2 @@ nobody
    where enc (pk1, pk2) b1 b2 = undefined

otTest :: (KnownSymbol p1, KnownSymbol p2, MonadIO m) => Choreo '[p1, p2] (CLI m) ()
otTest = do
  let p1 = explicitMember :: Member p1 '[p1, p2]
  let p2 = (inSuper (consSuper refl) explicitMember) :: Member p2 '[p1, p2]
  b1 <- p1 `_locally` return False
  b2 <- p1 `_locally` return True
  s <- p2 `_locally` return False
  otResult <- ot2 b1 b2 s
  p2 `locally_` \un -> putOutput "OT output:" $ un explicitMember otResult

main :: IO ()
main = do
  [loc] <- getArgs
  delivery <- case loc of
    "client1" -> runCLIIO $ runChoreography cfg (otTest @"client1" @"client2") "client1"
    "client2" -> runCLIIO $ runChoreography cfg (otTest @"client1" @"client2") "client2"
    _ -> error "unknown party"
  print delivery
  where
    cfg = mkHttpConfig [ ("client1", ("localhost", 4242))
                       , ("client2", ("localhost", 4343))
                       ]
