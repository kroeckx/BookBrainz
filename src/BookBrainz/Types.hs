-- | Types of data used within BookBrainz.
module BookBrainz.Types
       (
         -- * Core Entities
         Book (..)
       , Edition (..)
       , Person (..)
       , Publisher (..)

         -- * Other Entities
       , Country (..)
       , EditionFormat (..)
       , Language (..)
       , Role (..)

         -- * Other Types
       , Isbn

       , module BrainzStem.Types
       ) where

import Data.Char        (digitToInt)
import Data.Text        (Text)

import BrainzStem.Types

--------------------------------------------------------------------------------
{-| A book is an abstract concept, and does not have a physical representation.
People own 'BookBrainz.Types.Edition.Edition's of books, of which there
can be multiple versions (reprints, translations, etc.). A book is an
abstraction of this set of editions, and is what people commonly talk about in
discussions. -}
data Book = Book
    { bookName :: Text  -- ^ The name of the book.
    } deriving (Show, Eq)

--------------------------------------------------------------------------------
-- | A country, as defined by ISO 3166-1.
data Country = Country
    { -- | The human-readable name of the country.
      countryName    :: Text
      -- | The ISO 3166-1 alpha-2 ISO code of the country.
    , countryIsoCode :: String
    } deriving (Eq, Show)

--------------------------------------------------------------------------------
-- | The actual format of the edition that people read.
data EditionFormat = EditionFormat
    { -- | The human-readable name of the format.
      editionFormatName :: Text
    } deriving (Eq, Show)

--------------------------------------------------------------------------------
-- | A 13 digit ISBN code
newtype Isbn = Isbn { unIsbn :: [Int] } deriving (Eq)

instance Show Isbn where
  show = concat . map show . unIsbn

instance Read Isbn where
  readsPrec _ inp = let (isbn, rest) = splitAt 13 inp
                    in [(Isbn $ map digitToInt isbn, rest)]

--------------------------------------------------------------------------------
-- | An edition is a release of a 'Book' that people actually read from.
data Edition = Edition
    { -- | The name of the edition.
      editionName        :: Text
      -- | A reference to the format of the edition.
    , editionFormat      :: Maybe (Ref EditionFormat)
      -- | The 'Book' that this edition is an edition of.
    , editionBook        :: Ref (Concept Book)
      -- | The year the edition was released.
    , editionYear        :: Maybe Int
      -- | The 'Publisher' that published the edition.
    , editionPublisher   :: Maybe (Ref (Concept Publisher))
      -- | The 'Country' where the edition was published.
    , editionCountry     :: Maybe (Ref Country)
      -- | The 'Language' of this edition.
    , editionLanguage    :: Maybe (Ref Language)
      -- | The ISBN code of this edition.
    , editionIsbn        :: Maybe Isbn
      -- | An index used for sorting this edition.
    , editionIndex       :: Maybe Int
    } deriving (Eq, Show)

--------------------------------------------------------------------------------
-- | A language, as defined by ISO-639-3.
data Language = Language
    { -- | The human-readable name of the language.
      languageName :: Text
      -- | The ISO-639-3 code for the language.
    , languageIsoCode :: String
    } deriving (Eq, Show)

--------------------------------------------------------------------------------
{-| A person involved with a book, be it author, editor, illustrator,
etc. -}
data Person = Person
    { -- | The name of the person.
      personName :: Text
    } deriving (Eq, Show)

--------------------------------------------------------------------------------
-- | An organization or company which publishes books.
data Publisher = Publisher
    { -- | The name of the publisher.
      publisherName :: Text
    } deriving (Eq, Show)

--------------------------------------------------------------------------------
{-| The role a 'Person' played on a core entity (author, translator, etc. -}
data Role = Role
    { -- | The name of the role.
      roleName :: Text
    } deriving (Eq, Show)
