{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

{- |
Module      : Control.Concurrent.Async.Lifted
Copyright   : Copyright (C) 2012-2018 Mitsutoshi Aoe
License     : BSD-style (see the file LICENSE)
Maintainer  : Mitsutoshi Aoe <maoe@foldr.in>
Stability   : experimental

This is a wrapped version of @Control.Concurrent.Async@ with types generalized
from 'IO' to all monads in either 'MonadBase' or 'MonadBaseControl'.

All the functions restore the monadic effects in the forked computation
unless specified otherwise.

If your monad stack satisfies @'StM' m a ~ a@ (e.g. the reader monad), consider
using @Control.Concurrent.Async.Lifted.Safe@ module, which prevents you from
messing up monadic effects.
-}

module Control.Concurrent.Async.Unlifted
  ( -- * Asynchronous actions
    A.Async
    -- ** Spawning
  , async, asyncBound, asyncOn

    -- ** Spawning with automatic 'cancel'ation
  , withAsync

    -- ** Quering 'Async's
  , wait, poll, waitCatch
  , cancel
  , uninterruptibleCancel
  , cancelWith
  , A.asyncThreadId
  , A.AsyncCancelled(..)

    -- ** STM operations
  , A.waitSTM, A.pollSTM, A.waitCatchSTM

    -- ** Waiting for multiple 'Async's
  , waitAny, waitAnyCatch, waitAnyCancel, waitAnyCatchCancel
  , waitEither, waitEitherCatch, waitEitherCancel, waitEitherCatchCancel
  , waitEither_
  , waitBoth

    -- ** Waiting for multiple 'Async's in STM
  , A.waitAnySTM
  , A.waitAnyCatchSTM
  , A.waitEitherSTM
  , A.waitEitherCatchSTM
  , A.waitEitherSTM_
  , A.waitBothSTM

    -- ** Linking
  , link, link2
  , A.ExceptionInLinkedThread(..)

    -- * Convenient utilities
  , race, race_, concurrently, concurrently_
  , mapConcurrently, mapConcurrently_
  , forConcurrently, forConcurrently_
  , replicateConcurrently, replicateConcurrently_
  , Concurrently(..)

  , A.compareAsyncs
  ) where

import Control.Applicative
import Control.Concurrent (threadDelay)
import Control.Monad (forever, void)
import Control.Monad.IO.Class (MonadIO (liftIO))
import Data.Foldable (fold)
import Prelude

import Control.Concurrent.Async (Async)
import Control.Exception (SomeException, Exception)
import Control.Monad.IO.Unlift (MonadUnliftIO (withRunInIO))
import qualified Control.Concurrent.Async as A


-- | Generalized version of 'A.async'.
async :: MonadUnliftIO m => m a -> m (Async a)
async = asyncUsing A.async

-- | Generalized version of 'A.asyncBound'.
asyncBound :: MonadUnliftIO m => m a -> m (Async a)
asyncBound = asyncUsing A.asyncBound

-- | Generalized version of 'A.asyncOn'.
asyncOn :: MonadUnliftIO m => Int -> m a -> m (Async a)
asyncOn cpu = asyncUsing (A.asyncOn cpu)

asyncUsing
  :: MonadUnliftIO m
  => (IO a -> IO (Async a))
  -> m a
  -> m (Async a)
asyncUsing fork m =
  withRunInIO $ \runInIO -> fork (runInIO m)

-- | Generalized version of 'A.wait'.
wait :: MonadUnliftIO m => Async a -> m a
wait = liftIO . A.wait

-- | Generalized version of 'A.poll'.
poll
  :: MonadUnliftIO m
  => Async a
  -> m (Maybe (Either SomeException a))
poll a =
  liftIO (A.poll a) >>=
  maybe (return Nothing) (fmap Just . sequenceEither)

-- | Generalized version of 'A.cancel'.
cancel :: MonadIO m => Async a -> m ()
cancel = liftIO . A.cancel

-- | Generalized version of 'A.cancelWith'.
cancelWith :: (MonadIO m, Exception e) => Async a -> e -> m ()
cancelWith = (liftIO .) . A.cancelWith

-- | Generalized version of 'A.uninterruptibleCancel'.
uninterruptibleCancel :: MonadIO m => Async a -> m ()
uninterruptibleCancel = liftIO . A.uninterruptibleCancel

-- | Generalized version of 'A.waitCatch'.
waitCatch
  :: MonadUnliftIO m
  => Async a
  -> m (Either SomeException a)
waitCatch a = liftIO (A.waitCatch a) >>= sequenceEither

-- | Generalized version of 'A.waitAny'.
waitAny :: MonadUnliftIO m => [Async a] -> m (Async a, a)
waitAny as = do
  liftIO $ A.waitAny as

-- | Generalized version of 'A.waitAnyCatch'.
waitAnyCatch
  :: MonadUnliftIO m
  => [Async a]
  -> m (Async a, Either SomeException a)
waitAnyCatch as = do
  (a, s) <- liftIO $ A.waitAnyCatch as
  r <- sequenceEither s
  return (a, r)

-- | Generalized version of 'A.waitAnyCancel'.
waitAnyCancel
  :: MonadUnliftIO m
  => [Async a]
  -> m (Async a, a)
waitAnyCancel as = do
  liftIO $ A.waitAnyCancel as

-- | Generalized version of 'A.waitAnyCatchCancel'.
waitAnyCatchCancel
  :: MonadUnliftIO m
  => [Async a]
  -> m (Async a, Either SomeException a)
waitAnyCatchCancel as = do
  (a, s) <- liftIO $ A.waitAnyCatchCancel as
  r <- sequenceEither s
  return (a, r)

-- | Generalized version of 'A.waitEither'.
waitEither
  :: MonadUnliftIO m
  => Async a
  -> Async b
  -> m (Either a b)
waitEither a b =
  liftIO (A.waitEither a b)

-- | Generalized version of 'A.waitEitherCatch'.
waitEitherCatch
  :: MonadUnliftIO m
  => Async a
  -> Async b
  -> m (Either (Either SomeException a) (Either SomeException b))
waitEitherCatch a b =
  liftIO (A.waitEitherCatch a b) >>=
  either (fmap Left . sequenceEither) (fmap Right . sequenceEither)

-- | Generalized version of 'A.waitEitherCancel'.
waitEitherCancel
  :: MonadUnliftIO m
  => Async a
  -> Async b
  -> m (Either a b)
waitEitherCancel a b =
  liftIO $ A.waitEitherCancel a b

-- | Generalized version of 'A.waitEitherCatchCancel'.
waitEitherCatchCancel
  :: MonadUnliftIO m
  => Async a
  -> Async b
  -> m (Either (Either SomeException a) (Either SomeException b))
waitEitherCatchCancel a b =
  liftIO (A.waitEitherCatch a b) >>=
  either (fmap Left . sequenceEither) (fmap Right . sequenceEither)

-- | Generalized version of 'A.waitEither_'.
--
-- NOTE: This function discards the monadic effects besides IO in the forked
-- computation.
waitEither_
  :: MonadIO m
  => Async a
  -> Async b
  -> m ()
waitEither_ a b = liftIO (A.waitEither_ a b)

-- | Generalized version of 'A.waitBoth'.
waitBoth
  :: MonadUnliftIO m
  => Async a
  -> Async b
  -> m (a, b)
waitBoth a b = do
  liftIO (A.waitBoth a b)
{-# INLINABLE waitBoth #-}

-- | Generalized version of 'A.link'.
link :: MonadIO m => Async a -> m ()
link = liftIO . A.link

-- | Generalized version of 'A.link2'.
link2 :: MonadIO m => Async a -> Async b -> m ()
link2 = (liftIO .) . A.link2

-- | Generalized version of 'A.race'.
race :: MonadUnliftIO m => m a -> m b -> m (Either a b)
race left right =
  withAsync left $ \a ->
  withAsync right $ \b ->
  waitEither a b
{-# INLINABLE race #-}

-- | Generalized version of 'A.race_'.
--
-- NOTE: This function discards the monadic effects besides IO in the forked
-- computation.
race_ :: MonadUnliftIO m => m a -> m b -> m ()
race_ left right =
  withAsync left $ \a ->
  withAsync right $ \b ->
  waitEither_ a b
{-# INLINABLE race_ #-}

-- | Generalized version of 'A.concurrently'.
concurrently :: MonadUnliftIO m => m a -> m b -> m (a, b)
concurrently left right =
  withAsync left $ \a ->
  withAsync right $ \b ->
  waitBoth a b
{-# INLINABLE concurrently #-}

-- | Generalized version of 'A.concurrently_'.
concurrently_ :: MonadUnliftIO m => m a -> m b -> m ()
concurrently_ left right = void $ concurrently left right
{-# INLINABLE concurrently_ #-}

-- | Generalized version of 'A.mapConcurrently'.
mapConcurrently
  :: (Traversable t, MonadUnliftIO m)
  => (a -> m b)
  -> t a
  -> m (t b)
mapConcurrently f = runConcurrently . traverse (Concurrently . f)

-- | Generalized version of 'A.mapConcurrently_'.
mapConcurrently_
  :: (Foldable t, MonadUnliftIO m)
  => (a -> m b)
  -> t a
  -> m ()
mapConcurrently_ f = runConcurrently . foldMap (Concurrently . void . f)

-- | Generalized version of 'A.forConcurrently'.
forConcurrently
  :: (Traversable t, MonadUnliftIO m)
  => t a
  -> (a -> m b)
  -> m (t b)
forConcurrently = flip mapConcurrently

-- | Generalized version of 'A.forConcurrently_'.
forConcurrently_
  :: (Foldable t, MonadUnliftIO m)
  => t a
  -> (a -> m b)
  -> m ()
forConcurrently_ = flip mapConcurrently_

-- | Generalized version of 'A.replicateConcurrently'.
replicateConcurrently
  :: MonadUnliftIO m
  => Int
  -> m a
  -> m [a]
replicateConcurrently n =
  runConcurrently . sequenceA . replicate n . Concurrently

-- | Generalized version of 'A.replicateConcurrently_'.
replicateConcurrently_
  :: MonadUnliftIO m
  => Int
  -> m a
  -> m ()
replicateConcurrently_ n =
  runConcurrently . fold . replicate n . Concurrently . void

-- | Generalized version of 'A.Concurrently'.
--
-- A value of type @'Concurrently' m a@ is an IO-based operation that can be
-- composed with other 'Concurrently' values, using the 'Applicative' and
-- 'Alternative' instances.
--
-- Calling 'runConcurrently' on a value of type @'Concurrently' m a@ will
-- execute the IO-based lifted operations it contains concurrently, before
-- delivering the result of type 'a'.
--
-- For example
--
-- @
--   (page1, page2, page3) <- 'runConcurrently' $ (,,)
--     '<$>' 'Concurrently' (getURL "url1")
--     '<*>' 'Concurrently' (getURL "url2")
--     '<*>' 'Concurrently' (getURL "url3")
-- @
newtype Concurrently m a = Concurrently { runConcurrently :: m a }

instance Functor m => Functor (Concurrently m) where
  fmap f (Concurrently a) = Concurrently $ f <$> a

instance MonadUnliftIO m => Applicative (Concurrently m) where
  pure = Concurrently . pure
  Concurrently fs <*> Concurrently as =
    Concurrently $ uncurry ($) <$> concurrently fs as

instance MonadUnliftIO m => Alternative (Concurrently m) where
  empty = Concurrently $ withRunInIO $ \_ -> forever $ threadDelay maxBound
  Concurrently as <|> Concurrently bs =
    Concurrently $ either id id <$> race as bs

instance (MonadUnliftIO m, Semigroup a) =>
  Semigroup (Concurrently m a) where
    (<>) = liftA2 (<>)

instance (MonadUnliftIO m, Semigroup a, Monoid a) =>
  Monoid (Concurrently m a) where
    mempty = pure mempty

sequenceEither :: MonadUnliftIO m => Either e a -> m (Either e a)
sequenceEither = pure


withAsync :: MonadUnliftIO m => m a -> (Async a -> m b) -> m b
withAsync action callback = withRunInIO $ \runInIO ->
  liftIO $ A.withAsync (runInIO action) (runInIO . callback)
