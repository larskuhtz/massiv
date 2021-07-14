{-# LANGUAGE ExplicitForAll #-}
{-# LANGUAGE FlexibleContexts #-}
-- |
-- Module      : Data.Massiv.Array.Mutable.Algorithms
-- Copyright   : (c) Alexey Kuleshevich 2019-2021
-- License     : BSD3
-- Maintainer  : Alexey Kuleshevich <lehins@yandex.ru>
-- Stability   : experimental
-- Portability : non-portable
--
module Data.Massiv.Array.Mutable.Algorithms
  ( quicksortM_
  , quicksortByM_
  , unstablePartitionM
  , iterateUntilM
  ) where

import Data.Massiv.Array.Ops.Sort
import Data.Massiv.Array.Manifest.Internal (iterateUntilM)
import Data.Massiv.Core.Common


-- | Partition elements of the supplied mutable vector according to the predicate.
--
-- ==== __Example__
--
-- >>> import Data.Massiv.Array as A
-- >>> import Data.Massiv.Array.Mutable.Algorithms
-- >>> :set -XOverloadedLists
-- >>> m <- thaw ([2,1,50,10,20,8] :: Array P Ix1 Int)
-- >>> unstablePartitionM m (pure . (<= 10))
-- 4
-- >>> freeze Seq m
-- Array P Seq (Sz1 6)
--   [ 2, 1, 8, 10, 20, 50 ]
--
-- @since 1.0.0
unstablePartitionM ::
     forall r e m s. (Mutable r e, Primal s m)
  => MVector r e s
  -> (e -> m Bool) -- ^ Predicate
  -> m Ix1
unstablePartitionM marr f = unsafeUnstablePartitionRegionM marr f 0 (unSz (msize marr) - 1)
