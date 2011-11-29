module BookBrainz.Model.Editor
       ( getEditorByName
       ) where

import Data.Maybe (listToMaybe)

import Database.HDBC (toSql)
import Data.Text (Text)
import Snap.Snaplet.Hdbc (HasHdbc, query, Row)

import BrainzStem.Database ((!))
import BookBrainz.Types

getEditorByName :: (Functor m, HasHdbc m c s) => Text -> m (Maybe (LoadedEntity Editor))
getEditorByName name =
  (fmap fromRow . listToMaybe) `fmap` query selectSql [ toSql name ]
  where selectSql = "SELECT editor_id, name FROM editor WHERE name = ?"

fromRow :: Row -> LoadedEntity Editor
fromRow r = Entity { entityInfo = Editor { editorName = r ! "name"
                                         }
                   , entityRef = r ! "editor_id"
                   }
