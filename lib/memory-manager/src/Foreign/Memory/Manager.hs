{-# LANGUAGE DeriveGeneric            #-}
{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE ScopedTypeVariables      #-}
{-# LANGUAGE UnliftedFFITypes         #-}
{-# LANGUAGE ViewPatterns             #-}

module Foreign.Memory.Manager where

import Prologue hiding (Item)

import Control.DeepSeq        (NFData)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Data.Convert           (convert)
import Foreign                (Ptr, castPtr, nullPtr)
import Foreign.C              (CDouble (..), CSize (..))
import GHC.Generics           (Generic)


---------------------------
-- === Type wrappers === --
---------------------------

newtype MemoryManager = MemoryManager (Ptr ()) deriving (Eq, Ord, Show, Generic, NFData)
type Item = Ptr ()



--------------------------------------
-- === Foreign imports from C++ === --
--------------------------------------

foreign import ccall unsafe "newManager"    c_newManager    :: CSize -> CSize -> IO MemoryManager
foreign import ccall unsafe "deleteManager" c_deleteManager :: MemoryManager -> IO ()
foreign import ccall unsafe "newItem"       c_newItem       :: MemoryManager -> IO Item
foreign import ccall unsafe "newItems"      c_newItems      :: MemoryManager -> CSize -> IO Item
foreign import ccall unsafe "deleteItem"    c_deleteItem    :: MemoryManager -> Item -> IO ()

-- foreign import ccall unsafe "acquireItemList" c_acquireItemList :: MemoryManager -> Ptr CSize -> IO (Ptr Item)
-- foreign import ccall unsafe "releaseItemList" c_releaseItemList :: Ptr Item -> IO ()

----------------------------------------
-- === Wrappers for foreign calls === --
----------------------------------------

newManager :: MonadIO m => Int -> Int -> m MemoryManager
newManager (convert -> blockSize) (convert -> itemSize) = liftIO $ c_newManager itemSize blockSize
{-# INLINE newManager #-}

deleteManager :: MonadIO m => MemoryManager -> m ()
deleteManager = liftIO . c_deleteManager
{-# INLINE deleteManager #-}

newItem :: MonadIO m => MemoryManager -> m (Ptr a)
newItem mm = liftIO $ castPtr <$> c_newItem mm
{-# INLINE newItem #-}

newItemN :: MonadIO m => MemoryManager -> Int -> m (Ptr a)
newItemN mm n = liftIO $ do
    when_ (n < 1) $ fail "[MemoryManager.newItemN] Insufficient number of elements."
    castPtr <$> c_newItems mm (fromIntegral n)
{-# INLINE newItemN #-}

deleteItem :: MonadIO m => MemoryManager -> Ptr a -> m ()
deleteItem mm = liftIO . c_deleteItem mm . castPtr
{-# INLINE deleteItem #-}

unsafeNull :: MemoryManager
unsafeNull = MemoryManager nullPtr

-- allocatedItems :: MemoryManager -> IO [Item]
-- allocatedItems mgr = alloca $ \outListSize ->
--     bracket (acquireItemList mgr outListSize) releaseItemList $
--         \listPtr ->
--             if listPtr /= nullPtr then do
--                 obtainedSize <- peek outListSize
--                 peekArray (fromInteger $ toInteger obtainedSize) listPtr
--              else return []
