{-# LANGUAGE RecordWildCards, GeneralizedNewtypeDeriving #-}

-- Stuff on disk on the server
module Development.Bake.Server.Database(
    PointId, RunId, StateId, PatchId, patchIds, fromPatchIds, patchIdsSuperset,
    DbState(..), DbPatch(..), DbReject(..), DbPoint(..), DbRun(..), DbTest(..), DbSkip(..),
    create
    ) where

import Development.Bake.Core.Type
import Control.Applicative
import Data.String
import General.Extra
import Database.SQLite.Simple
import Database.SQLite.Simple.FromField
import Database.SQLite.Simple.ToField
import System.Time.Extra
import Data.List.Extra
import Prelude


newtype PointId = PointId Int deriving (ToField, FromField)
newtype RunId = RunId Int deriving (ToField, FromField, Eq)
newtype StateId = StateId Int deriving (ToField, FromField)
newtype PatchId = PatchId Int deriving (ToField, FromField)

instance Show PointId where show (PointId x) = "point-" ++ show x
instance Show RunId where show (RunId x) = "run-" ++ show x
instance Show StateId where show (StateId x) = "state-" ++ show x
instance Show PatchId where show (PatchId x) = "patch-" ++ show x

instance Read RunId where readsPrec i s = [x | Just s <- [stripPrefix "run-" s], x <- readsPrec i s]

newtype PatchIds = PatchIds String deriving (ToField, FromField)

patchIds :: [PatchId] -> PatchIds
patchIds = PatchIds . concatMap (\(PatchId x) -> "[" ++ show x ++ "]")

patchIdsSuperset :: [PatchId] -> PatchIds
patchIdsSuperset = PatchIds . ('%':) . concatMap (\(PatchId x) -> "[" ++ show x ++ "]%")

fromPatchIds :: PatchIds -> [PatchId]
fromPatchIds (PatchIds "") = []
fromPatchIds (PatchIds xs) = map (PatchId . read) $ splitOn "][" $ init $ tail xs

data DbState = DbState
    {sState :: State, sCreate :: UTCTime, sPoint :: Maybe PointId, sDuration :: Seconds}

createState = "CREATE TABLE IF NOT EXISTS state (" ++
    "state TEXT NOT NULL UNIQUE PRIMARY KEY, time TEXT NOT NULL, point INTEGER, duration REAL NOT NULL)"

data DbPatch = DbPatch
    {pPatch :: Patch, pAuthor :: String, pQueue :: UTCTime
    ,pStart :: Maybe UTCTime, pDelete :: Maybe UTCTime, pSupersede :: Maybe UTCTime, pReject :: Maybe UTCTime
    ,pPlausible :: Maybe UTCTime, pMerge :: Maybe UTCTime}

createPatch = "CREATE TABLE IF NOT EXISTS patch (" ++
    "patch TEXT NOT NULL UNIQUE PRIMARY KEY, author TEXT NOT NULL, queue TEXT NOT NULL, " ++
    "start TEXT, delete_ TEXT, supersede TEXT, reject TEXT, plausible TEXT, merge TEXT)"

data DbReject = DbReject
    {jPatch :: PatchId, jTest :: Maybe Test, jRun :: RunId}

createReject = "CREATE TABLE IF NOT EXISTS reject (" ++
    "patch INTEGER NOT NULL, test TEXT, run INTEGER NOT NULL)"

data DbPoint = DbPoint
    {tState :: StateId, tPatches :: PatchIds} -- surrounded by /

createPoint = "CREATE TABLE IF NOT EXISTS point (" ++
    "state INTEGER NOT NULL, patches TEXT NOT NULL, PRIMARY KEY (state, patches))"

data DbRun = DbRun
    {rPoint :: PointId, rTest :: Maybe Test, rSuccess :: Bool
    ,rClient :: Client, rStart :: UTCTime, rDuration :: Seconds}

createRun = "CREATE TABLE IF NOT EXISTS run (" ++
    "point INTEGER NOT NULL, test TEXT, success INTEGER NOT NULL, " ++
    "client TEXT NOT NULL, start TEXT NOT NULL, duration REAL NOT NULL)"

data DbTest = DbTest
    {tPoint :: PointId, tTest :: Maybe Test}
    -- include the Nothing result so that if something has no tests it is still recorded

createTests = "CREATE TABLE IF NOT EXISTS test (" ++
    "point INTEGER NOT NULL, test TEXT)"

data DbSkip = DbSkip
    {kTest :: Test, kComment :: String}

createSkip = "CREATE TABLE IF NOT EXISTS skip (" ++
    "test TEXT NOT NULL PRIMARY KEY, comment TEXT NOT NULL)"

create :: String -> IO Connection
create file = do
    c <- open file
    execute_ c $ fromString createState
    execute_ c $ fromString createPatch
    execute_ c $ fromString createReject
    execute_ c $ fromString createPoint
    execute_ c $ fromString createRun
    execute_ c $ fromString createTests
    execute_ c $ fromString createSkip
    return c

instance FromRow DbPatch where
    fromRow = DbPatch <$> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field

instance FromRow DbPoint where
    fromRow = DbPoint <$> field <*> field

instance ToRow DbPatch where
    toRow (DbPatch a b c d e f g h i) = toRow (a,b,c,d,e,f,g,h,i)

instance ToRow DbState where
    toRow (DbState a b c d) = toRow (a,b,c,d)

instance FromRow DbState where
    fromRow = DbState <$> field <*> field <*> field <*> field

instance ToRow DbReject where
    toRow (DbReject a b c) = toRow (a,b,c)

instance ToRow DbRun where
    toRow (DbRun a b c d e f) = toRow (a,b,c,d,e,f)

instance FromRow DbRun where
    fromRow = DbRun <$> field <*> field <*> field <*> field <*> field <*> field

instance ToRow DbPoint where
    toRow (DbPoint a b) = toRow (a,b)

instance ToRow DbSkip where
    toRow (DbSkip a b) = toRow (a,b)

instance FromRow DbSkip where
    fromRow = DbSkip <$> field <*> field

instance FromField Patch where fromField = fmap Patch . fromField
instance ToField Patch where toField = toField . fromPatch
instance FromField State where fromField = fmap State . fromField
instance ToField State where toField = toField . fromState
instance FromField Test where fromField = fmap Test . fromField
instance ToField Test where toField = toField . fromTest
instance FromField Client where fromField = fmap Client . fromField
instance ToField Client where toField = toField . fromClient