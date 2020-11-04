{-# LANGUAGE TypeApplications #-}

module Test.Massiv.Array.NumericSpec
  ( spec
  ) where

import Data.Massiv.Array as A
import Test.Massiv.Array.Numeric
import Test.Massiv.Core

spec :: Spec
spec = do
  mutableNumericSpec @P @Int
  mutableNumericSpec @P @Float
  mutableNumericFloatSpec @P
  mutableNumericSpec @S @Int
  mutableNumericSpec @S @Float
  mutableNumericFloatSpec @S