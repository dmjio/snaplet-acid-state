{-# LANGUAGE FlexibleContexts          #-}
{-# LANGUAGE FlexibleInstances         #-}
{-# LANGUAGE FunctionalDependencies    #-}
{-# LANGUAGE KindSignatures            #-}
{-# LANGUAGE MultiParamTypeClasses     #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE OverloadedStrings         #-}
{-# LANGUAGE RankNTypes                #-}
{-# LANGUAGE ScopedTypeVariables       #-}
module Snap.Snaplet.AcidState
  ( Acid
  , HasAcid(..)
  , acidInit
  , acidInit'
  , getAcidState
  , update
  , query
  , createCheckpoint
  , closeAcidState

  , module Data.Acid
  ) where


import           Prelude hiding ((.), id)
import           Control.Category
import qualified Data.Acid as A
import qualified Data.Acid.Advanced as A
import           Data.Acid hiding (update
                                  ,query
                                  ,createCheckpoint
                                  ,closeAcidState
                                  )
import           Data.Typeable
import           Data.Text (Text)
import           Snap


------------------------------------------------------------------------------
-- | 
description :: Text
description = "Snaplet providing acid-state functionality"


------------------------------------------------------------------------------
-- | Data type holding acid-state snaplet data.
newtype Acid st = Acid
    { _acidStore :: A.AcidState st
    }


------------------------------------------------------------------------------
-- | Initializer that stores the state in the "state/[typeOf state]/"
-- directory.
acidInit :: (A.IsAcidic st, Typeable st)
         => st
         -- ^ Initial state to be used if 
         -> SnapletInit b (Acid st)
acidInit initial = makeSnaplet "acid-state" description Nothing $ do
    st <- liftIO $ A.openLocalState initial
    return $ Acid st


------------------------------------------------------------------------------
-- | Initializer allowing you to specify the location of the acid-state store.
acidInit' :: A.IsAcidic st
          => FilePath
          -- ^ Location of the acid-state store on disk
          -> st
          -- ^ Initial state to be used if 
          -> SnapletInit b (Acid st)
acidInit' location initial = makeSnaplet "acid-state" description Nothing $ do
    st <- liftIO $ A.openLocalStateFrom location initial
    onUnload (A.closeAcidState st)
    return $ Acid st


------------------------------------------------------------------------------
-- | Type class standardizing a context that holds an AcidState.
--
-- You can minimize boilerplate in your application by adding an instance like
-- the following:
--
-- > data App = App { ... _acid :: Snaplet (Acid MyState) ... }
-- > instance HasAcid App MyState where
-- >     getAcidStore = getL (snapletValue . acid)
class HasAcid myState acidState where
    getAcidStore :: myState -> (Acid acidState)


instance HasAcid (Acid st) st where
    getAcidStore = id


------------------------------------------------------------------------------
-- | Lower-level function providing direct access to the AcidState data type.
getAcidState :: (HasAcid s st, MonadSnaplet m, MonadState s (m v' v'))
    => m v' v (AcidState st)
getAcidState = withTop' id $ gets $ _acidStore . getAcidStore


------------------------------------------------------------------------------
-- | Wrapper for acid-state's update function that works for arbitrary
-- instances of HasAcid.
update :: (HasAcid s (A.MethodState event),
           MonadSnaplet m,
           MonadState s (m v' v'),
           UpdateEvent event,
           MonadIO (m v' v))
       => event -> m v' v (EventResult event)
update event = do
    st <- getAcidState
    liftIO $ A.update st event


------------------------------------------------------------------------------
-- | Wrapper for acid-state's query function that works for arbitrary
-- instances of HasAcid.
query :: (HasAcid s (A.MethodState event),
          MonadSnaplet m,
          MonadState s (m v' v'),
          QueryEvent event,
          MonadIO (m v' v))
      => event -> m v' v (EventResult event)
query event = do
    st <- getAcidState
    liftIO $ A.query st event


------------------------------------------------------------------------------
-- | Wrapper for acid-state's createCheckpoint function that works for
-- arbitrary instances of HasAcid.
createCheckpoint = do
    st <- getAcidState
    liftIO $ A.createCheckpoint st


------------------------------------------------------------------------------
-- | Wrapper for acid-state's closeAcidState function that works for
-- arbitrary instances of HasAcid.  The state is automatically closed by the
-- snaplet's unload action, but this is here in case the user needs more
-- control.
closeAcidState = do
    st <- getAcidState
    liftIO $ A.closeAcidState st

