{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TupleSections     #-}

-- | Handlers for the @/book@ resource.
module BookBrainz.Web.Handler.Book
       ( listBooks
       , showBook
       , addBook
       , editBook
       , addBookRole
       ) where

import           Control.Applicative        ((<$>))
import           Data.Traversable           (traverse)

import           Data.ByteString.Char8      (pack)
import           Data.Copointed             (copoint)
import           Snap.Core                  (redirect)
import Snap.Snaplet.Hdbc (withTransaction')
import           Text.Digestive.Blaze.Html5
import           Text.Digestive.Forms.Snap  (eitherSnapForm)

import qualified BookBrainz.Forms as Forms
import           BookBrainz.Model.Book      (create, listAllBooks)
import           BookBrainz.Model.Edition
import           BookBrainz.Model.Publisher ()
import           BookBrainz.Model.Role      (findRoles, addRole)
import           BookBrainz.Types
import           BookBrainz.Web.Handler     (output, onNothing, withUser)
import           BookBrainz.Web.Snaplet     (BookBrainzHandler)
import qualified BookBrainz.Web.View.Book   as V
import           BrainzStem.Model           (getByBbid, getByConcept, update
                                            ,findMasterBranch, changeBranch)

--------------------------------------------------------------------------------
-- | List all known books.
listBooks :: BookBrainzHandler ()
listBooks = do
  bs <- listAllBooks
  output $ V.showBooks bs

--------------------------------------------------------------------------------
{-| Show a single 'Book', searching by its BBID. If the book cannot be found,
a 404 page is displayed. -}
showBook :: BBID Book -> BookBrainzHandler ()
showBook bbid' = do
  book <- getByBbid bbid' `onNothing` "Book not found"
  editions <- findBookEditions (coreEntityConcept book) >>= mapM loadEdition
  roles <- findRoles (coreEntityTree book)
  output $ V.showBook (book, roles) editions
  where loadEdition e =
          (e, ) <$> traverse getByConcept (editionPublisher . copoint $ e)

---------------------------------------------------------------------------------
{-| Display a form for adding 'Book's, and on submission, add that book and
redirect to view it. -}
addBook :: BookBrainzHandler ()
addBook = do
  withUser $ \user -> do
    r <- eitherSnapForm (Forms.bookForm Nothing) "book"
    case r of
      Left form' -> output $ V.addBook $ renderFormHtml form'
      Right submission -> do
        book <- withTransaction' $ create submission $ entityRef user
        redirect $ pack . ("/book/" ++) . show . bbid $ book

---------------------------------------------------------------------------------
{-| Display a form for adding 'Book's, and on submission, add that book and
redirect to view it. -}
editBook :: BBID Book -> BookBrainzHandler ()
editBook bbid' = do
  withUser $ \user -> do
    book <- getByBbid bbid' `onNothing` "Book not found"
    r <- eitherSnapForm (Forms.bookForm . Just $ copoint book) "book"
    case r of
      Left form' -> output $ V.addBook $ renderFormHtml form'
      Right submission -> do
        withTransaction' $ do
          master <- findMasterBranch $ coreEntityConcept book
          changeBranch master (entityRef user) $
            update submission
        redirect $ pack . ("/book/" ++) . show . bbid $ book

--------------------------------------------------------------------------------
{-| Present an interface for adding a new role to this book. -}
addBookRole :: BBID Book -> BookBrainzHandler ()
addBookRole bbid' = do
  withUser $ \user -> do
    book <- getByBbid bbid' `onNothing` "Book not found"
    roleForm <- Forms.personRole
    r <- eitherSnapForm roleForm "book"
    case r of
      Left form' -> output $ V.addBook $ renderFormHtml form'
      Right submission -> do
        withTransaction' $ do
          master <- (findMasterBranch $ coreEntityConcept book)
          changeBranch master (entityRef user) $
            addRole submission
        redirect $ pack . ("/book/" ++) . show . bbid $ book
