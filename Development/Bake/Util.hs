{-# LANGUAGE ScopedTypeVariables #-}

module Development.Bake.Util(
    sleep, timed,
    withTempFile, withTempDir,
    withCurrentDirectory, withTempDirCurrent,
    (&&^), whenJust,
    showException
    ) where

import qualified System.IO.Temp as T
import Control.Concurrent
import Control.Exception
import System.Directory
import System.IO


sleep :: Double -> IO ()
sleep x = threadDelay $ ceiling $ x * 1000000


timed :: IO a -> IO (Double, a)
timed = error "timed"


withTempFile :: String -> (FilePath -> IO a) -> IO a
withTempFile template act = T.withSystemTempFile template $ \file h -> hClose h >> act file

withTempDir :: (FilePath -> IO a) -> IO a
withTempDir = T.withSystemTempDirectory "bake"

withCurrentDirectory :: FilePath -> IO a -> IO a
withCurrentDirectory dir act =
    bracket getCurrentDirectory setCurrentDirectory $ const $ do
        setCurrentDirectory dir; act

withTempDirCurrent :: IO a -> IO a
withTempDirCurrent act = withTempDir $ \t -> withCurrentDirectory t act

(&&^) :: Monad m => m Bool -> m Bool -> m Bool
(&&^) a b = do a <- a; if a then b else return False

whenJust :: Monad m => Maybe a -> (a -> m ()) -> m ()
whenJust mg f = maybe (return ()) f mg

showException :: SomeException -> IO String
showException = f . show
    where
        f xs = do
            r <- try $ evaluate xs
            case r of
                Left (e :: SomeException) -> return "<NestedException>"
                Right [] -> return []
                Right (x:xs) -> fmap (x :) $ f xs
