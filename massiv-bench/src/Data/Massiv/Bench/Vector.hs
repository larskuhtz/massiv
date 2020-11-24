{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE UndecidableInstances #-}
module Data.Massiv.Bench.Vector
  ( randomV1
  , benchV1
  , VxV(..)
  , randomVxV
  , benchVxV
  , showsType
  ) where

import Data.Massiv.Array
import Data.Massiv.Bench.Matrix
import Data.Typeable
import Criterion.Main
import System.Random
import Control.DeepSeq

v1size :: Sz1
v1size = Sz1 1000000


randomV1 :: (Mutable r Ix1 e, Random e) => Vector r e
randomV1 = snd $ randomArrayS stdGen v1size random



benchV1 ::
     forall r e. (Typeable r, Typeable e, Construct r Ix1 e, Source r Ix1 e, Floating e, Numeric r e)
  => Vector r e
  -> Benchmark
benchV1 v =
  bgroup "normL2"
  [ bgroup (showsType @(Vector r e) (" - (" <> show (size v) <> ")"))
    [ bench "Seq" $ whnf normL2 v
    , bench "Par" $ whnf (normL2 . setComp Par) v
    ]
  , bgroup (showsType @(Vector D e) (" - (" <> show (size v) <> ")"))
    [ bench "Seq" $ whnf (normL2 . delay) v
    , bench "Par" $ whnf (normL2 . delay . setComp Par) v
    ]
  ]
{-# INLINEABLE benchV1 #-}



data VxV r e =
  VxV
    { aVxV :: !(Vector r e)
    , bVxV :: !(Vector r e)
    }
instance NFData (Vector r e) => NFData (VxV r e) where
  rnf (VxV a b) = a `deepseq` b `deepseq` ()

aVxVsize :: Sz1
aVxVsize = v1size

bVxVsize :: Sz1
bVxVsize = aVxVsize


randomVxV :: (Mutable r Ix1 e, Random e) => VxV r e
randomVxV =
  case randomArrayS stdGen aVxVsize random of
    (g, a) -> VxV {aVxV = a, bVxV = snd $ randomArrayS g bVxVsize random}

showSizeVxV :: Load r Ix1 e => VxV r e -> String
showSizeVxV VxV {..} = show n1 <> " X " <> show n2
  where
    Sz1 n1 = size aVxV
    Sz1 n2 = size bVxV


benchVxV ::
     forall r e. (Typeable r, Typeable e, Numeric r e, Mutable r Ix1 e)
  => VxV r e
  -> Benchmark
benchVxV vxv@VxV {..} =
  bgroup "dotProduct"
  [
    bgroup (showsType @(VxV r e) (" - (" <> showSizeVxV vxv <> ")"))
    [ bench "Seq" $ whnf (aVxV !.!) bVxV
    , bench "Par" $ whnf (setComp Par aVxV !.!) bVxV
    ]
  , bgroup (showsType @(VxV D e) (" - (" <> showSizeVxV vxv <> ")"))
    [ bench "Seq" $ whnf ((delay aVxV !.!) . delay) bVxV
    , bench "Par" $ whnf ((delay aVxV !.!) . setComp Par . delay) bVxV
    ]
  ]
{-# INLINEABLE benchVxV #-}