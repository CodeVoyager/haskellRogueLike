{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE ScopedTypeVariables #-}

module GameCore where

import           Protolude hiding (Map)
import qualified Data.Text as Txt
import           Data.Map.Strict (Map)
import qualified Data.Aeson as Ae
import qualified System.Random as Rnd
import           Control.Lens.TH (makeLenses)

import qualified GameHost as Host
import qualified EntityType as E
import qualified BoundedInt as B

data ActorClass = ClassPlayer
                | ClassEnemy
                deriving (Show, Eq)

newtype Aid = Aid Text deriving (Show, Eq, Ord)

data Actor = Actor { _acId :: !Aid
                   , _acClass :: !ActorClass
                   , _acEntity :: !Entity
                   , _acWorldPos :: !WorldPos
                   , _acStdGen :: !Rnd.StdGen
                   , _acFov :: !(Maybe [(WorldPos, [WorldPos])])
                   , _acFovHistory :: !(Set WorldPos)
                   , _acFovDistance :: !Int
                   , _acEnergy :: !B.BInt -- ^ available energy, bounded
                   , _acMoveEnergyCost :: !Int
                   , _acSkipMove :: !Bool

{-! SECTION< 13_actor !-}
                   -- | List of utilities in order of execution
                   --    Note that the world is threaded through the utilities and can be updated (i.e. in the ([], World) result)
                   --    The array of results has an updated actor and a score. These are speculative, and are only applied
                   --    if that utility is selected. The world updates are kept even if nothing is selected
                   , _acUtilities :: ![World -> Actor -> [PathTo] -> ([(Float, Actor, Impulse, Text, Maybe PathTo)], World)]
                   
                   -- | The actor's disposition - the values that define the actors personality
                   , _acDisposition :: !Disposition
{-! SECTION> 13_actor !-}
                   }

data Player = Player { _plConn :: !Host.Connection
                     , _plActor :: !Actor
                     , _plScreenSize :: !(Int, Int)
                     , _plWorldTopLeft :: !WorldPos
                     , _plViewPortStyle :: !ViewPortStyle
                     , _plPendingEnergy :: !Int
                     }

data World = World { _wdPlayer :: !Player
                   , _wdConfig :: !Config
                   , _wdMap :: !(Map WorldPos Entity)
                   , _wdActors :: !(Map Aid Actor)
                   , _wdMinMoveEnergy :: !Int   -- ^ min energy required before any more, regardless of cost, can be attempted
                   , _wdEnergyIncrements :: !Int -- ^ amount of energy that is added per game loop
                   }

data Config = Config { _cfgKeys :: !(Map Text Text)
                     , _cfgMinMaxBounds :: !(Int, Int, Int, Int) -- (minX, maxX, minY, maxY)
                    }


data Tile = Tile { _tlName :: !Text
                 , _tlPic :: !(Int, Int)
                 , _tlId :: !Int
                 } deriving (Show, Eq, Ord)

data Entity = Entity { _enType :: !E.EntityType
                     , _enTile :: !Tile
                     , _enProps :: !(Map Text Text)
                     } deriving (Show, Eq, Ord)

newtype WorldPos = WorldPos (Int, Int) deriving (Show, Eq, Ord)
newtype PlayerPos = PlayerPos (Int, Int) deriving (Show, Eq, Ord)

data RogueAction = ActMovePlayer (Int, Int)
                 | ActSetPlayerViewPortStyle ViewPortStyle

data ViewPortStyle = ViewPortCentre
                   | ViewPortLock PlayerPos
                   | ViewPortScroll
                   | ViewPortSnapCentre
                   | ViewPortBorder Int
                   deriving (Show, Eq)




----------------------------------------------------------------------------------------
-- Utility brain types
----------------------------------------------------------------------------------------
{-! SECTION< 13_path !-}
newtype Path = Path [WorldPos] deriving (Show)
{-! SECTION> 13_path !-}

{-! SECTION< 13_pathTo !-}
data PathTo = PathToEntity Path Entity WorldPos
            | PathToActor Path Actor WorldPos
            | PathToPlayer Path Player WorldPos
{-! SECTION> 13_pathTo !-}

{-! SECTION< 13_impulse !-}
data Impulse = ImpMoveTowards Path
             | ImpMoveRandom
{-! SECTION> 13_impulse !-}

{-! SECTION< 13_disposition !-}
data Disposition = Disposition { _dsSmitten :: Float
                               , _dsWanderlust :: Float
                               , _dsWanderlustToExits :: Float
                               , _dsSmittenWith :: [E.EntityType]
                               } 
{-! SECTION> 13_disposition !-}
----------------------------------------------------------------------------------------


----------------------------------------------------------------------------------------
-- UI types
----------------------------------------------------------------------------------------
data UiMessage = UiMessage { umCmd :: !Text
                           , umMessage :: !Text
                           }
                           deriving (Generic)
  
data UiConfig = UiConfig { ucCmd :: !Text
                         , ucData :: !UiConfigData
                         }
                         deriving (Generic)

data UiConfigData = UiConfigData { udKeys :: ![UiKey]
                                 , udBlankId :: !Int
                                 }
                                 deriving (Generic)

data UiKey = UiKey { ukShortcut :: !Text
                   , ukAction :: !Text
                   }
                   deriving (Generic)


data UiDrawCommand = UiDrawCommand
                     { drCmd :: !Text
                     , drScreenWidth :: !Int
                     , drMapData :: ![[(Int, Int, Int)]]
                     } deriving (Generic)


instance Ae.ToJSON UiMessage where
  toJSON = Ae.genericToJSON Ae.defaultOptions { Ae.fieldLabelModifier = renField 2 True }

instance Ae.ToJSON UiConfig where
  toJSON = Ae.genericToJSON Ae.defaultOptions { Ae.fieldLabelModifier = renField 2 True }

instance Ae.ToJSON UiConfigData where
  toJSON = Ae.genericToJSON Ae.defaultOptions { Ae.fieldLabelModifier = renField 2 True }

instance Ae.ToJSON UiKey where
  toJSON = Ae.genericToJSON Ae.defaultOptions { Ae.fieldLabelModifier = renField 2 True }

instance Ae.ToJSON UiDrawCommand where
  toJSON = Ae.genericToJSON Ae.defaultOptions { Ae.fieldLabelModifier = renField 2 True }


-- | drop prefix, and then lower case
-- | renField 3 "tskBla" == "bla"
renField :: Int -> Bool -> [Char] -> [Char]
renField drp toLower =
  Txt.unpack . (if toLower then mkLower else identity) . Txt.drop drp . Txt.pack
  where
    mkLower t = Txt.toLower (Txt.take 1 t) <> Txt.drop 1 t
----------------------------------------------------------------------------------------

makeLenses ''World
makeLenses ''Config
makeLenses ''Player
makeLenses ''Entity
makeLenses ''Tile
makeLenses ''Actor
makeLenses ''Disposition
