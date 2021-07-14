{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}
-- |
-- Module      : Data.Massiv.Array.Ops.Fold.Internal
-- Copyright   : (c) Alexey Kuleshevich 2018-2021
-- License     : BSD3
-- Maintainer  : Alexey Kuleshevich <lehins@yandex.ru>
-- Stability   : experimental
-- Portability : non-portable
--
module Data.Massiv.Array.Ops.Fold.Internal
  (
    foldlS
  , foldrS
  , ifoldlS
  , ifoldrS
  --Monadic
  , foldlM
  , foldrM
  , foldlM_
  , foldrM_
  , ifoldlM
  , ifoldrM
  , ifoldlM_
  , ifoldrM_
  --Special folds
  , fold
  , foldMono
  , foldlInternal
  , ifoldlInternal
  , foldrFB
  , lazyFoldlS
  , lazyFoldrS
  -- Parallel folds
  , foldlP
  , foldrP
  , ifoldlP
  , ifoldrP
  , ifoldlIO
  , ifoldrIO
  , splitReduce
  , any
  , anySu
  , anyPu
  ) where

import Control.Scheduler
import qualified Data.Foldable as F
import Data.Functor.Identity (runIdentity)
import Data.Massiv.Core.Common
import Prelude hiding (foldl, foldr, any)
import System.IO.Unsafe (unsafePerformIO)


-- | /O(n)/ - Unstructured fold of an array.
--
-- @since 0.3.0
fold ::
     (Monoid e, Index ix, Source r e)
  => Array r ix e -- ^ Source array
  -> e
fold = foldlInternal mappend mempty mappend mempty
{-# INLINE fold #-}


-- | /O(n)/ - This is exactly like `Data.Foldable.foldMap`, but for arrays. Fold over an array,
-- while converting each element into a `Monoid`. Also known as map-reduce. If elements of the array
-- are already a `Monoid` you can use `fold` instead.
--
-- @since 0.1.4
foldMono ::
     (Index ix, Source r e, Monoid m)
  => (e -> m) -- ^ Convert each element of an array to an appropriate `Monoid`.
  -> Array r ix e -- ^ Source array
  -> m
foldMono f = foldlInternal (\a e -> a `mappend` f e) mempty mappend mempty
{-# INLINE foldMono #-}


-- | /O(n)/ - Monadic left fold.
--
-- @since 0.1.0
foldlM :: (Index ix, Source r e, Monad m) => (a -> e -> m a) -> a -> Array r ix e -> m a
foldlM f = ifoldlM (\ a _ b -> f a b)
{-# INLINE foldlM #-}


-- | /O(n)/ - Monadic left fold, that discards the result.
--
-- @since 0.1.0
foldlM_ :: (Index ix, Source r e, Monad m) => (a -> e -> m a) -> a -> Array r ix e -> m ()
foldlM_ f = ifoldlM_ (\ a _ b -> f a b)
{-# INLINE foldlM_ #-}


-- | /O(n)/ - Monadic left fold with an index aware function.
--
-- @since 0.1.0
ifoldlM :: (Index ix, Source r e, Monad m) => (a -> ix -> e -> m a) -> a -> Array r ix e -> m a
ifoldlM f !acc !arr =
  iterM zeroIndex (unSz (size arr)) (pureIndex 1) (<) acc $ \ !ix !a -> f a ix (unsafeIndex arr ix)
{-# INLINE ifoldlM #-}


-- | /O(n)/ - Monadic left fold with an index aware function, that discards the result.
--
-- @since 0.1.0
ifoldlM_ :: (Index ix, Source r e, Monad m) => (a -> ix -> e -> m a) -> a -> Array r ix e -> m ()
ifoldlM_ f acc = void . ifoldlM f acc
{-# INLINE ifoldlM_ #-}


-- | /O(n)/ - Monadic right fold.
--
-- @since 0.1.0
foldrM :: (Index ix, Source r e, Monad m) => (e -> a -> m a) -> a -> Array r ix e -> m a
foldrM f = ifoldrM (\_ e a -> f e a)
{-# INLINE foldrM #-}


-- | /O(n)/ - Monadic right fold, that discards the result.
--
-- @since 0.1.0
foldrM_ :: (Index ix, Source r e, Monad m) => (e -> a -> m a) -> a -> Array r ix e -> m ()
foldrM_ f = ifoldrM_ (\_ e a -> f e a)
{-# INLINE foldrM_ #-}


-- | /O(n)/ - Monadic right fold with an index aware function.
--
-- @since 0.1.0
ifoldrM :: (Index ix, Source r e, Monad m) => (ix -> e -> a -> m a) -> a -> Array r ix e -> m a
ifoldrM f !acc !arr =
  iterM (liftIndex (subtract 1) (unSz (size arr))) zeroIndex (pureIndex (-1)) (>=) acc $ \ !ix !acc0 ->
    f ix (unsafeIndex arr ix) acc0
{-# INLINE ifoldrM #-}


-- | /O(n)/ - Monadic right fold with an index aware function, that discards the result.
--
-- @since 0.1.0
ifoldrM_ :: (Index ix, Source r e, Monad m) => (ix -> e -> a -> m a) -> a -> Array r ix e -> m ()
ifoldrM_ f !acc !arr = void $ ifoldrM f acc arr
{-# INLINE ifoldrM_ #-}



-- | /O(n)/ - Left fold, computed sequentially with lazy accumulator.
--
-- @since 0.1.0
lazyFoldlS :: (Index ix, Source r e) => (a -> e -> a) -> a -> Array r ix e -> a
lazyFoldlS f initAcc arr = go initAcc 0
  where
    len = totalElem (size arr)
    go acc k
      | k < len = go (f acc (unsafeLinearIndex arr k)) (k + 1)
      | otherwise = acc
{-# INLINE lazyFoldlS #-}


-- | /O(n)/ - Right fold, computed sequentially with lazy accumulator.
--
-- @since 0.1.0
lazyFoldrS :: (Index ix, Source r e) => (e -> a -> a) -> a -> Array r ix e -> a
lazyFoldrS = foldrFB
{-# INLINE lazyFoldrS #-}


-- | /O(n)/ - Left fold, computed sequentially.
--
-- @since 0.1.0
foldlS :: (Index ix, Source r e) => (a -> e -> a) -> a -> Array r ix e -> a
foldlS f = ifoldlS (\ a _ e -> f a e)
{-# INLINE foldlS #-}


-- | /O(n)/ - Left fold with an index aware function, computed sequentially.
--
-- @since 0.1.0
ifoldlS :: (Index ix, Source r e)
        => (a -> ix -> e -> a) -> a -> Array r ix e -> a
ifoldlS f acc = runIdentity . ifoldlM (\ a ix e -> return $ f a ix e) acc
{-# INLINE ifoldlS #-}


-- | /O(n)/ - Right fold, computed sequentially.
--
-- @since 0.1.0
foldrS :: (Index ix, Source r e) => (e -> a -> a) -> a -> Array r ix e -> a
foldrS f = ifoldrS (\_ e a -> f e a)
{-# INLINE foldrS #-}


-- | /O(n)/ - Right fold with an index aware function, computed sequentially.
--
-- @since 0.1.0
ifoldrS :: (Index ix, Source r e) => (ix -> e -> a -> a) -> a -> Array r ix e -> a
ifoldrS f acc = runIdentity . ifoldrM (\ ix e a -> return $ f ix e a) acc
{-# INLINE ifoldrS #-}


-- | Version of foldr that supports @foldr/build@ list fusion implemented by GHC.
--
-- @since 0.1.0
foldrFB :: (Index ix, Source r e) => (e -> b -> b) -> b -> Array r ix e -> b
foldrFB c n arr = go 0
  where
    !k = totalElem (size arr)
    go !i
      | i == k = n
      | otherwise = let !v = unsafeLinearIndex arr i in v `c` go (i + 1)
{-# INLINE [0] foldrFB #-}



-- | /O(n)/ - Left fold, computed with respect of array's computation strategy. Because we do
-- potentially split the folding among many threads, we also need a combining function and an
-- accumulator for the results. Depending on the number of threads being used, results can be
-- different, hence is the `RW` state token for the `Primal` monad.
--
-- ===__Examples__
--
-- >>> import Data.Massiv.Array
-- >>> foldlP (flip (:)) [] (flip (:)) [] $ makeArrayR D Seq (Sz1 6) id
-- [[5,4,3,2,1,0]]
-- >>> foldlP (flip (:)) [] (++) [] $ makeArrayR D Seq (Sz1 6) id
-- [5,4,3,2,1,0]
-- >>> foldlP (flip (:)) [] (flip (:)) [] $ makeArrayR D (ParN 3) (Sz1 6) id
-- [[5,4],[3,2],[1,0]]
-- >>> foldlP (flip (:)) [] (++) [] $ makeArrayR D (ParN 3) (Sz1 6) id
-- [1,0,3,2,5,4]
--
-- @since 0.1.0
foldlP :: (Primal RW m, Index ix, Source r e) =>
          (a -> e -> a) -- ^ Folding function @g@.
       -> a -- ^ Accumulator. Will be applied to @g@ multiple times, thus must be neutral.
       -> (b -> a -> b) -- ^ Chunk results folding function @f@.
       -> b -- ^ Accumulator for results of chunks folding.
       -> Array r ix e -> m b
foldlP f fAcc g gAcc = liftIO . ifoldlP (\ x _ -> f x) fAcc g gAcc
{-# INLINE foldlP #-}

-- | /O(n)/ - Left fold with an index aware function, computed in parallel. Just
-- like `foldlP`, except that folding function will receive an index of an
-- element it is being applied to.
--
-- @since 0.1.0
ifoldlP :: (Primal RW m, Index ix, Source r e) =>
           (a -> ix -> e -> a) -> a -> (b -> a -> b) -> b -> Array r ix e -> m b
ifoldlP f fAcc g gAcc =
  liftIO . ifoldlIO (\acc ix -> return . f acc ix) fAcc (\acc -> return . g acc) gAcc
{-# INLINE ifoldlP #-}


-- | /O(n)/ - Right fold, computed with respect to computation strategy. Same as `foldlP`, except
-- directed from the last element in the array towards beginning.
--
-- ==== __Examples__
--
-- >>> import Data.Massiv.Array
-- >>> foldrP (:) [] (++) [] $ makeArrayR D (ParN 2) (Sz2 2 3) fromIx2
-- [(0,0),(0,1),(0,2),(1,0),(1,1),(1,2)]
-- >>> foldrP (:) [] (:) [] $ makeArrayR D Seq (Sz1 6) id
-- [[0,1,2,3,4,5]]
-- >>> foldrP (:) [] (:) [] $ makeArrayR D (ParN 3) (Sz1 6) id
-- [[0,1],[2,3],[4,5]]
--
-- @since 0.1.0
foldrP :: (Primal RW m, Index ix, Source r e) =>
          (e -> a -> a) -> a -> (a -> b -> b) -> b -> Array r ix e -> m b
foldrP f fAcc g gAcc = liftIO . ifoldrP (const f) fAcc g gAcc
{-# INLINE foldrP #-}


-- | /O(n)/ - Right fold with an index aware function, while respecting the computation strategy.
-- Same as `ifoldlP`, except directed from the last element in the array towards
-- beginning, but also row-major.
--
-- @since 0.1.0
ifoldrP ::
     (Primal RW m, Index ix, Source r e)
  => (ix -> e -> a -> a)
  -> a
  -> (a -> b -> b)
  -> b
  -> Array r ix e
  -> m b
ifoldrP f fAcc g gAcc = liftIO . ifoldrIO (\ix e -> pure . f ix e) fAcc (\e -> pure . g e) gAcc
{-# INLINE ifoldrP #-}


-- | This folding function breaks referential transparency on some functions
-- @f@, therefore it is kept here for internal use only.
foldlInternal :: (Index ix, Source r e) => (a -> e -> a) -> a -> (b -> a -> b) -> b -> Array r ix e -> b
foldlInternal g initAcc f resAcc = unsafePerformIO . foldlP g initAcc f resAcc
{-# INLINE foldlInternal #-}


ifoldlInternal :: (Index ix, Source r e) => (a -> ix -> e -> a) -> a -> (b -> a -> b) -> b -> Array r ix e -> b
ifoldlInternal g initAcc f resAcc = unsafePerformIO . ifoldlP g initAcc f resAcc
{-# INLINE ifoldlInternal #-}


-- | Similar to `ifoldlP`, except that folding functions themselves do live in IO
--
-- @since 0.1.0
ifoldlIO ::
     (UnliftPrimal RW m, Index ix, Source r e)
  => (a -> ix -> e -> m a) -- ^ Index aware folding IO action
  -> a -- ^ Accumulator
  -> (b -> a -> m b) -- ^ Folding action that is applied to the results of a parallel fold
  -> b -- ^ Accumulator for chunks folding
  -> Array r ix e
  -> m b
ifoldlIO f !initAcc g !tAcc !arr
  | getComp arr == Seq = ifoldlM f initAcc arr >>= g tAcc
  | otherwise = do
      let !sz = size arr
          !totalLength = totalElem sz
      results <-
        withScheduler (getComp arr) $ \scheduler ->
          splitLinearly (numWorkers scheduler) totalLength $ \chunkLength slackStart -> do
            loopM_ 0 (< slackStart) (+ chunkLength) $ \ !start ->
              scheduleWork scheduler $
              iterLinearM sz start (start + chunkLength) 1 (<) initAcc $ \ !i ix !acc ->
                f acc ix (unsafeLinearIndex arr i)
            when (slackStart < totalLength) $
              scheduleWork scheduler $
              iterLinearM sz slackStart totalLength 1 (<) initAcc $ \ !i ix !acc ->
                f acc ix (unsafeLinearIndex arr i)
      F.foldlM g tAcc results
{-# INLINE ifoldlIO #-}

-- | Slice an array into linear row-major vector chunks and apply an action to each of
-- them. Number of chunks will depend on the computation strategy. Results of each action
-- will be combined with a folding function.
--
-- @since 1.0.0
splitReduce ::
     (UnliftPrimal RW m, Index ix, Source r e)
  => (Scheduler RW a -> Vector r e -> m a)
  -> (b -> a -> m b) -- ^ Folding action that is applied to the results of a parallel fold
  -> b -- ^ Accumulator for chunks folding
  -> Array r ix e
  -> m b
splitReduce f g !tAcc !arr = do
  let !sz = size arr
      !totalLength = totalElem sz
  results <-
    withScheduler (getComp arr) $ \scheduler -> do
      splitLinearly (numWorkers scheduler) totalLength $ \chunkLength slackStart -> do
        loopM_ 0 (< slackStart) (+ chunkLength) $ \ !start ->
          scheduleWork scheduler $ f scheduler $
            unsafeLinearSlice start (SafeSz chunkLength) arr
        when (slackStart < totalLength) $
          scheduleWork scheduler $ f scheduler $
            unsafeLinearSlice slackStart (SafeSz (totalLength - slackStart)) arr
  F.foldlM g tAcc results
{-# INLINE splitReduce #-}



-- | Similar to `ifoldrP`, except that folding functions themselves do live in IO
--
-- @since 0.1.0
ifoldrIO :: (UnliftPrimal RW m, Index ix, Source r e) =>
           (ix -> e -> a -> m a) -> a -> (a -> b -> m b) -> b -> Array r ix e -> m b
ifoldrIO f !initAcc g !tAcc !arr
  | getComp arr == Seq = ifoldrM f initAcc arr >>= (`g` tAcc)
  | otherwise = do
    let !sz = size arr
        !totalLength = totalElem sz
    results <-
      withScheduler (getComp arr) $ \ scheduler ->
        splitLinearly (numWorkers scheduler) totalLength $ \ chunkLength slackStart -> do
          when (slackStart < totalLength) $
            scheduleWork scheduler $
            iterLinearM sz (totalLength - 1) slackStart (-1) (>=) initAcc $ \ !i ix !acc ->
              f ix (unsafeLinearIndex arr i) acc
          loopM_ slackStart (> 0) (subtract chunkLength) $ \ !start ->
            scheduleWork scheduler $
              iterLinearM sz (start - 1) (start - chunkLength) (-1) (>=) initAcc $ \ !i ix !acc ->
                f ix (unsafeLinearIndex arr i) acc
    F.foldlM (flip g) tAcc results
{-# INLINE ifoldrIO #-}

-- | Sequential implementation of `any` with unrolling
anySu :: (Index ix, Source r e) => (e -> Bool) -> Array r ix e -> Bool
anySu f arr = go 0
  where
    !k = elemsCount arr
    !k4 = k - (k `rem` 4)
    go !i
      | i < k4 =
        f (unsafeLinearIndex arr i      ) ||
        f (unsafeLinearIndex arr (i + 1)) ||
        f (unsafeLinearIndex arr (i + 2)) ||
        f (unsafeLinearIndex arr (i + 3)) ||
        go (i + 4)
      | i < k = f (unsafeLinearIndex arr i) || go (i + 1)
      | otherwise = False
{-# INLINE anySu #-}


-- | Implementaton of `any` on a slice of an array with short-circuiting using batch cancellation.
anySliceSuM ::
     (Index ix, Source r e)
  => Batch RW Bool
  -> Ix1
  -> Sz1
  -> (e -> Bool)
  -> Array r ix e
  -> IO Bool
anySliceSuM batch ix0 (Sz1 k) f arr = go ix0
  where
    !k' = k - ix0
    !k4 = ix0 + (k' - (k' `rem` 4))
    go !i
      | i < k4 = do
        let r =
              f (unsafeLinearIndex arr i) ||
              f (unsafeLinearIndex arr (i + 1)) ||
              f (unsafeLinearIndex arr (i + 2)) ||
              f (unsafeLinearIndex arr (i + 3))
         in if r
              then cancelBatchWith batch True
              else do
                done <- hasBatchFinished batch
                if done
                  then pure True
                  else go (i + 4)
      | i < k =
        if f (unsafeLinearIndex arr i)
          then cancelBatchWith batch True
          else go (i + 1)
      | otherwise = pure False
{-# INLINE anySliceSuM #-}



-- | Parallelizable implementation of `any` with unrolling
anyPu :: (Index ix, Source r e) => (e -> Bool) -> Array r ix e -> IO Bool
anyPu f arr = do
  let !sz = size arr
      !totalLength = totalElem sz
  results <-
    withScheduler (getComp arr) $ \scheduler -> do
      batch <- getCurrentBatch scheduler
      splitLinearly (numWorkers scheduler) totalLength $ \chunkLength slackStart -> do
        loopM_ 0 (< slackStart) (+ chunkLength) $ \ !start ->
          scheduleWork scheduler $ anySliceSuM batch start (Sz (start + chunkLength)) f arr
        when (slackStart < totalLength) $
          scheduleWork scheduler $ anySliceSuM batch slackStart (Sz totalLength) f arr
  pure $ F.foldl' (||) False results
{-# INLINE anyPu #-}



-- | /O(n)/ - Determines whether any element of the array satisfies a predicate.
--
-- @since 0.1.0
any :: (Index ix, Source r e) => (e -> Bool) -> Array r ix e -> Bool
any f arr =
  case getComp arr of
    Seq -> anySu f arr
    _ -> unsafePerformIO $ anyPu f arr
{-# INLINE any #-}
