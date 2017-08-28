--
-- Copyright (c) 2012 Mark Dittmer - http://www.markdittmer.org
-- Developed for a Google Summer of Code project - http://gsoc2012.markdittmer.org
--
{-# LANGUAGE MultiParamTypeClasses, TypeSynonymInstances, FlexibleInstances #-}

module System.FSNotify.Path
       ( findFiles
       , findDirs
       , canonicalizeDirPath
       , canonicalizePath
       , hasThisExtension
       ) where

import Prelude hiding (FilePath)

import Control.Applicative
import Control.Monad
-- import Filesystem
-- import Filesystem.Path hiding (concat)

import qualified Data.Text as T
import qualified System.Directory as D
import System.PosixCompat.Files as PF
import System.FilePath

getDirectoryContentsPath :: FilePath -> IO [FilePath]
getDirectoryContentsPath path =
  ((map (path </>)) . filter (not . dots) <$> D.getDirectoryContents path)
  >>= filterM exists
  where
    exists x = (||) <$> D.doesFileExist x <*> D.doesDirectoryExist x
    dots "."  = True
    dots ".." = True
    dots _    = False

fileDirContents :: FilePath -> IO ([FilePath],[FilePath])
fileDirContents path = do
  contents <- getDirectoryContentsPath path
  stats <- mapM getFileStatus contents
  let pairs = zip stats contents
  let files = [ f | (s, f) <- pairs, PF.isRegularFile s]
  let dirs = [ d | (s, d) <- pairs, PF.isDirectory s]
  return (files, dirs)

findAllFiles :: FilePath -> IO [FilePath]
findAllFiles path = do
  (files, dirs) <- fileDirContents path
  nestedFiles <- mapM findAllFiles dirs
  return (files ++ concat nestedFiles)

findImmediateFiles, findImmediateDirs :: FilePath -> IO [FilePath]
findImmediateFiles = fileDirContents >=> mapM D.canonicalizePath . fst
findImmediateDirs  = fileDirContents >=> mapM D.canonicalizePath . snd

findAllDirs :: FilePath -> IO [FilePath]
findAllDirs path = do
  dirs <- findImmediateDirs path
  nestedDirs <- mapM findAllDirs dirs
  return (dirs ++ concat nestedDirs)

findFiles :: Bool -> FilePath -> IO [FilePath]
findFiles True path  = findAllFiles       =<< canonicalizeDirPath path
findFiles False path = findImmediateFiles =<<  canonicalizeDirPath path

findDirs :: Bool -> FilePath -> IO [FilePath]
findDirs True path  = findAllDirs       =<< canonicalizeDirPath path
findDirs False path = findImmediateDirs =<< canonicalizeDirPath path

-- | add a trailing slash to ensure the path indicates a directory
addTrailingSlash :: FilePath -> FilePath
addTrailingSlash = addTrailingPathSeparator

canonicalizeDirPath :: FilePath -> IO FilePath
canonicalizeDirPath path = addTrailingSlash `fmap` D.canonicalizePath path

-- | bugfix older version of canonicalizePath (system-fileio <= 0.3.7) loses trailing slash
canonicalizePath :: FilePath -> IO FilePath
canonicalizePath path = let was_dir = null (takeFileName path) in
  if not was_dir then D.canonicalizePath path
  else canonicalizeDirPath path

hasThisExtension :: FilePath -> T.Text -> Bool
hasThisExtension p ext = takeExtension p == T.unpack ext
