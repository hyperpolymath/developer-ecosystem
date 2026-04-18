{- SPDX-License-Identifier: MPL-2.0 -}

module Main where

import Test.Hspec

main :: IO ()
main = hspec $ do
  describe "Scaffoldia" $ do
    it "placeholder test" $ do
      True `shouldBe` True
