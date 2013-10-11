{-# LANGUAGE OverloadedStrings #-}
module Blog.Controllers.CommentsController where

import Control.Monad.IO.Class
import qualified Data.ByteString.Char8 as S8
import qualified Data.Text as T
import Database.PostgreSQL.ORM
import Web.Simple
import Web.Simple.Cache
import Web.Frank

import Blog.Common
import qualified Blog.Models ()
import qualified Blog.Models.Comment as C
import qualified Blog.Models.Post as P

import Blog.Models
import Blog.Views.Comments

lookupText :: S8.ByteString -> [(S8.ByteString, S8.ByteString)] -> Maybe T.Text
lookupText k vals = fmap (T.pack . S8.unpack) $ lookup k vals

commentsController = do
  post "/" $ do
    pid <- readQueryParam' "post_id"
    (params, _) <- parseForm
    let mcomment = do
          name <- lookupText "name" params
          email <- lookupText "email" params
          comment <- lookupText "comment" params
          return $ C.Comment NullKey name email comment pid
    case mcomment of
      Just comment -> withConnection $ \conn -> do
        (Just post) <- liftIO $ findRow conn pid
        liftIO $ save conn comment
    redirectBack

commentsAdminController = do
  get "/" $ withConnection $ \conn -> do
    pid <- readQueryParam' "post_id"
    (Just post) <- liftIO $ findRow conn pid
    comments <- liftIO $ allComments conn post
    respondAdminTemplate $ listComments post comments
    
  delete ":id" $ withConnection $ \conn -> do
    cid <- readQueryParam' "id"
    (Just comment) <- liftIO $ (findRow conn cid :: IO (Maybe C.Comment))
    liftIO $ destroy conn comment
    redirectBack

