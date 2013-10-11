{-# LANGUAGE FlexibleContexts #-}
module Blog.Common where

import Control.Concurrent.MVar
import Control.Exception.Peel
import Control.Monad.IO.Class
import qualified Data.ByteString.Char8 as S8
import qualified Data.ByteString.Lazy as L
import qualified Data.ByteString.Lazy.Search as L
import Data.IORef
import Database.PostgreSQL.Simple
import System.Environment
import System.INotify
import Web.Simple
import Text.Blaze.Html
import Text.Blaze.Html.Renderer.Utf8 (renderHtml)

import Blog.Templates

type LBS = L.ByteString

data AppSettings = AppSettings { appDB :: MVar Connection
                               , appTemplate :: IORef (LBS -> LBS) }

newAppSettings :: INotify -> IO AppSettings
newAppSettings inotify = do
  db <- newMVar =<< createConnection Nothing
  tmpl <- newIORef =<< generateTemplate
  let watcher = addWatch inotify [Modify] "templates/main.tmpl.html" $ const $
                  do
                    putStrLn "Reloading main template..."
                    writeIORef tmpl =<< generateTemplate
                    watcher >> return ()
  watcher
  return $ AppSettings { appDB = db, appTemplate = tmpl }

generateTemplate :: IO (LBS -> LBS)
generateTemplate = do
  tmpl <- L.readFile "templates/main.tmpl.html"
  return $ \content -> L.replace (S8.pack "{% content %}") content tmpl

createConnection :: Maybe S8.ByteString -> IO Connection
createConnection mconnectStr = do
  dbUrl <- case mconnectStr of
    Nothing -> do
      env <- getEnvironment
      return $ maybe S8.empty S8.pack $ lookup "DATABASE_URL" env
    Just str -> return str
  connectPostgreSQL dbUrl

withConnection :: (Connection -> Controller AppSettings b) -> Controller AppSettings b
withConnection func = do
  dbvar <- appDB `fmap` controllerState
  bracket (liftIO $ takeMVar dbvar) (liftIO . (putMVar dbvar)) $ \conn -> do
    res <- func conn
    return res

respondTemplate :: Html -> Controller AppSettings a
respondTemplate content = do
  tmplFunc <- liftIO . readIORef =<< fmap appTemplate controllerState
  respond $ okHtml $ tmplFunc $ renderHtml content

respondAdminTemplate :: Html -> Controller AppSettings a
respondAdminTemplate = respondTemplate . adminTemplate

