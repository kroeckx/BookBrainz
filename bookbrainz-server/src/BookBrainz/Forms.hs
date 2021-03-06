{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE TupleSections #-}
module BookBrainz.Forms where

import           Control.Applicative         ((<$>), (<*>), pure)
import           Control.Monad (join)
import           Data.Char                   (isDigit, digitToInt)
import           Data.Maybe                  (isNothing)

import           Data.Copointed              (copoint, Copointed)
import           Data.Text                   (Text)
import qualified Data.Text                   as T
import           Data.Text.Read              (decimal)
import           Snap.Core
import           Snap.Snaplet.PostgresqlSimple (HasPostgres)
import           Text.Blaze (ToMarkup)
import           Text.Blaze.Html5            (Html, toHtml)
import           Text.Digestive
import           Text.Digestive.Snap

import           BookBrainz.Model.Country  (allCountries)
import           BookBrainz.Model.EditionFormat (allEditionFormats)
import           BookBrainz.Model.Language (allLanguages)
import           BookBrainz.Model.Editor (getEditorByName)
import           BookBrainz.Model.Person (allPersons)
import           BookBrainz.Model.Publisher (allPublishers)
import           BookBrainz.Model.Role (allRoles)
import           BookBrainz.Types (Book (Book), Edition (Edition)
                                  ,EditionFormat, Ref, Concept, Isbn
                                  ,Language, Country, Publisher (Publisher)
                                  ,Person (Person), Role
                                  ,entityRef, coreEntityConcept)
import qualified BookBrainz.Types as BB

--------------------------------------------------------------------------------
data SearchQuery = SearchQuery { query :: Text }

--------------------------------------------------------------------------------
data Login = Login { loginFormId :: Text
                   , loginFormPassword :: Text
                   , loginFormRemember :: Bool
                   }

--------------------------------------------------------------------------------
data Registration = Registration { newUserName :: Text
                                 , newUserPassword :: Text
                                 , newUserEmail :: Text
                                 }

--------------------------------------------------------------------------------
book :: (Monad m, MonadSnap m)
     => Maybe Book
     -> Form Html m Book
book defBook = Book <$> "title" .: nonEmptyText (BB.bookName `fmap` defBook)

--------------------------------------------------------------------------------
addEdition :: (MonadSnap m, HasPostgres m)
           => Ref (Concept Book)
           -> m (Form Html m Edition)
addEdition parentBook = edition (Right parentBook)

editEdition :: (MonadSnap m, HasPostgres m)
            => Edition
            -> m (Form Html m Edition)
editEdition edition' = edition (Left edition')

edition :: (MonadSnap m, HasPostgres m)
        => Either Edition (Ref (Concept Book))
        -> m (Form Html m Edition)
edition start = do
  formatField    <- optionalEditionFormat $ getDef' BB.editionFormat
  countryField   <- optionalCountry $ getDef' BB.editionCountry
  languageField  <- optionalLanguage $ getDef' BB.editionLanguage
  publisherField <- optionalPublisherRef $ getDef' BB.editionPublisher
  return $
    Edition <$> "name" .: (nonEmptyText $ getDef BB.editionName)
            <*> pure (either BB.editionBook id start)
            <*> "year" .: (optionalYear $ getDef' BB.editionYear)
            <*> "publisher" .: publisherField
            <*> "country" .: countryField
            <*> "language" .: languageField
            <*> "isbn" .: (optionalIsbn13 $ getDef' BB.editionIsbn)
            <*> pure Nothing
            <*> "format" .: formatField
  where existing = either Just (const Nothing) start
        getDef p = fmap p existing
        getDef'= join . getDef

--------------------------------------------------------------------------------
personRole :: (HasPostgres m, MonadSnap m)
           => m (Form Html m (Ref (Concept Person), Ref Role))
personRole = do
  personField <- personRef Nothing
  roleField   <- role Nothing
  return $
    (,) <$> "person" .: personField
        <*> "role" .: roleField

--------------------------------------------------------------------------------
dbSelect :: (Monad m, MonadSnap m, HasPostgres m, Copointed c, ToMarkup v, Eq r)
         => m [c e]
         -> (c e -> r)
         -> (e -> v)
         -> Maybe r
         -> m (Form Html m r)
dbSelect selector value label def = do
  opts <- selector
  return $ choice (map (\a -> (value a, toHtml $ label $ copoint a)) opts) def

optionalDbSelect :: (Monad m, MonadSnap m, HasPostgres m, Copointed c, ToMarkup v, Eq r)
                 => m [c e]
                 -> (c e -> r)
                 -> (e -> v)
                 -> Maybe r
                 -> m (Form Html m (Maybe r))
optionalDbSelect selector value label def = do
  opts <- selector
  return $ choice ((Nothing, "") : map (\a -> (Just $ value a, toHtml $ label $ copoint a)) opts) (Just def)


--------------------------------------------------------------------------------
personRef :: (Monad m, MonadSnap m, HasPostgres m)
          => Maybe (Ref (Concept Person))
          -> m (Form Html m (Ref (Concept Person)))
personRef = dbSelect allPersons coreEntityConcept BB.personName

--------------------------------------------------------------------------------
role :: (Monad m, MonadSnap m, HasPostgres m)
     => Maybe (Ref Role)
     -> m (Form Html m (Ref Role))
role = dbSelect allRoles entityRef BB.roleName

--------------------------------------------------------------------------------
optionalLanguage :: (Monad m, MonadSnap m, HasPostgres m)
                 => Maybe (Ref Language)
                 -> m (Form Html m (Maybe (Ref Language)))
optionalLanguage = optionalDbSelect allLanguages entityRef BB.languageName

--------------------------------------------------------------------------------
optionalEditionFormat :: (Monad m, MonadSnap m, HasPostgres m)
                      => Maybe (Ref EditionFormat)
                      -> m (Form Html m (Maybe (Ref EditionFormat)))
optionalEditionFormat = optionalDbSelect allEditionFormats entityRef BB.editionFormatName

--------------------------------------------------------------------------------
optionalCountry :: (Monad m, MonadSnap m, HasPostgres m)
                => Maybe (Ref Country)
                -> m (Form Html m (Maybe (Ref Country)))
optionalCountry = optionalDbSelect allCountries entityRef BB.countryName

--------------------------------------------------------------------------------
optionalPublisherRef :: (Monad m, MonadSnap m, HasPostgres m)
                     => Maybe (Ref (Concept Publisher))
                     -> m (Form Html m (Maybe (Ref (Concept Publisher))))
optionalPublisherRef = optionalDbSelect allPublishers coreEntityConcept BB.publisherName

--------------------------------------------------------------------------------
optionalYear :: (Monad m, MonadSnap m)
             => Maybe Int -> Form Html m (Maybe Int)
optionalYear def = validate yearCheck $ text ((T.pack . show) `fmap` def)
  where
    yearCheck y | T.null y = Success Nothing
                | otherwise   =
      if T.all isDigit y
      then case (decimal y :: Either String (Int, Text)) of
        Left e -> Error $ toHtml e
        Right (d, _) -> Success $ Just d
      else Error "A year can only consist of integers"

--------------------------------------------------------------------------------
optionalIsbn13 :: (Monad m, MonadSnap m)
               => Maybe Isbn -> Form Html m (Maybe Isbn)
optionalIsbn13 def = validate checkIsbn $ text ((T.pack . show) `fmap` def)
  where
    checkIsbn isbn | T.null isbn    = Success Nothing
                   | validIsbn isbn = Success $ read $ T.unpack isbn
                   | otherwise      = Error "This is not a valid ISBN-13 identifier"
    validIsbn i = let digits = map digitToInt (T.unpack i) :: [Int]
                      isbn = init digits
                      checkDigit = last digits
                      checkSum (x:y:xs) = x + (3 * y) + checkSum xs
                      checkSum (_:[]) = error "Checksum must contain 12 digits"
                      checkSum [] = 0
                   in all isDigit (T.unpack i) &&
                        (T.length i == 13) &&
                          ((10 - checkSum isbn `mod` 10) `mod` 10) == checkDigit

--------------------------------------------------------------------------------
person :: (MonadSnap m)
       => Form Html m Person
person = Person <$> "name" .: nonEmptyText Nothing

--------------------------------------------------------------------------------
publisher :: (MonadSnap m)
          => Form Html m Publisher
publisher = Publisher <$> "name" .: nonEmptyText Nothing

--------------------------------------------------------------------------------
searchForm :: (Monad m, MonadSnap m) => Form Html m SearchQuery
searchForm = SearchQuery <$> "query" .: nonEmptyText Nothing

--------------------------------------------------------------------------------
registerForm :: (Monad m, MonadSnap m, HasPostgres m)
             => Form Html m Registration
registerForm = Registration <$> "userName" .: nonExistingUser
                            <*> "password" .: passwordForm
                            <*> "email" .: nonEmptyText Nothing
  where
    passwordForm = validate matchPasswords $
                     (,) <$> "password" .: nonEmptyText Nothing
                         <*> "confirmPassword" .: nonEmptyText Nothing
    matchPasswords (a, b) | a == b    = Success a
                          | otherwise = Error "Error passwords must match"
    nonExistingUser = checkM "An account with this name already exists"
      (fmap isNothing . getEditorByName) $ nonEmptyText Nothing

loginForm :: (Monad m, MonadSnap m) => Form Html m Login
loginForm = Login <$> "userName" .: nonEmptyText Nothing
                  <*> "password" .: nonEmptyText Nothing
                  <*> "remember" .: bool Nothing

--------------------------------------------------------------------------------
nonEmptyText :: (Monad m, MonadSnap m) => Formlet Html m Text
nonEmptyText = check "Cannot be empty" (not . T.null) . text

--------------------------------------------------------------------------------
processForm :: (MonadSnap m)
            => Form v m a           -- ^ Form
            -> Text                 -- ^ Form name
            -> m (View v, Maybe a)  -- ^ Result
processForm form name = runForm name form
