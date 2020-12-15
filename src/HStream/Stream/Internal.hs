{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE StrictData #-}
{-# LANGUAGE NoImplicitPrelude #-}

module HStream.Stream.Internal
  ( InternalStreamBuilder,
    mkInternalStreamBuilder,
    mkInternalProcessorName,
    addSourceInternal,
    addProcessorInternal,
    addSinkInternal,
    buildInternal,
  )
where

import Control.Comonad ((=>>))
import HStream.Processor
import HStream.Processor.Internal
import RIO
import qualified RIO.Text as T

data InternalStreamBuilder = InternalStreamBuilder
  { isbTaskBuilder :: TaskBuilder,
    isbProcessorId :: IORef Int
  }

mkInternalStreamBuilder :: TaskBuilder -> IO InternalStreamBuilder
mkInternalStreamBuilder taskBuilder = do
  index <- newIORef 0
  return
    InternalStreamBuilder
      { isbTaskBuilder = taskBuilder,
        isbProcessorId = index
      }

addSourceInternal ::
  (Typeable k, Typeable v) =>
  SourceConfig k v ->
  InternalStreamBuilder ->
  IO InternalStreamBuilder
addSourceInternal sourceCfg builder@InternalStreamBuilder {..} = do
  let taskBuilder = isbTaskBuilder =>> addSource sourceCfg
  return
    builder {isbTaskBuilder = taskBuilder}

addProcessorInternal ::
  (Typeable k, Typeable v) =>
  T.Text ->
  Processor k v ->
  [T.Text] ->
  InternalStreamBuilder ->
  IO InternalStreamBuilder
addProcessorInternal processorName processor parents builder@InternalStreamBuilder {..} = do
  let taskBuilder = isbTaskBuilder =>> addProcessor processorName processor parents
  return
    builder {isbTaskBuilder = taskBuilder}

addSinkInternal ::
  (Typeable k, Typeable v) =>
  SinkConfig k v ->
  [T.Text] ->
  InternalStreamBuilder ->
  IO InternalStreamBuilder
addSinkInternal sinkCfg parents builder@InternalStreamBuilder {..} = do
  let taskBuilder = isbTaskBuilder =>> addSink sinkCfg parents
  return
    builder {isbTaskBuilder = taskBuilder}

buildInternal :: InternalStreamBuilder -> Task
buildInternal InternalStreamBuilder {..} = build isbTaskBuilder

mkInternalProcessorName :: T.Text -> InternalStreamBuilder -> IO T.Text
mkInternalProcessorName namePrefix InternalStreamBuilder {..} = do
  index <- readIORef isbProcessorId
  writeIORef isbProcessorId (index + 1)
  return $ namePrefix `T.append` T.pack (show index)
