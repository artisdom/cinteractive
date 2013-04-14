{-# LANGUAGE OverloadedStrings #-}
import Language
import Data.Aeson
import Data.Aeson.Encode (fromValue)
import Data.Conduit as DC
import Data.Conduit.Binary as CB
import Network.Wai
import Network.Wai.Handler.Warp
import Network.HTTP.Types
import Blaze.ByteString.Builder (copyByteString)
import Blaze.ByteString.Builder.Char8 (fromLazyText)
import qualified Data.ByteString.UTF8 as BU
import qualified Data.ByteString.Lazy as BL
import Data.Monoid
import Data.Enumerator (run_, enumList, ($$))
import Data.Functor ((<$>))
import Data.ByteString.Char8 (pack)
import Control.Arrow ((>>>))
import Data.Text (intercalate, unpack, splitOn)
import Data.Text.Lazy.Builder (toLazyText)
import Control.Monad.IO.Class (liftIO)

appJson = "application/json"
textPlain = "text/plain"
textHtml = "text/html"

main = do
   let port = 3000
   putStrLn $ "Listening on port " ++ show port
   run port app

-- app :: Application
app :: Request -> ResourceT IO Response
app req =
   case pathInfo req of
      ["parse"] -> requestBody req DC.$$ parse
      path@("static":rest) -> let filepath = unpack $ intercalate "/" path
                                  ext = last . splitOn "." $ last rest
                                  contentType = if ext == "css" then "text/css" else "text/plain"
                              in  return $ ResponseFile status200 [ (hContentType, contentType) ] (unpack $ intercalate "/" path) Nothing
      x -> do
         ihtml <- CB.sourceFile "index.html" DC.$$ await
         return $ index ihtml

parse = do
   body <- await
   return $ ResponseBuilder status200 [ (hContentType, textPlain) ] $
      case body of
         Nothing -> mempty
         Just body -> fromLazyText . toLazyText . fromValue . toJSON . byteStringToAST $ body

index html = ResponseBuilder status200 [ (hContentType, "text/html; charset=utf-8") ] $ case html of
   Nothing -> copyByteString "<html><head><title>Whoops!</title></head><body><h1>Whoops! clearly something bad happened.</h1></body></html>"
   (Just html) -> copyByteString html
