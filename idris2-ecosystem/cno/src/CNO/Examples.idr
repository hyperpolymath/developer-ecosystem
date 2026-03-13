-- SPDX-License-Identifier: MPL-2.0
||| CNO Examples
|||
||| Practical examples of CNOs in various contexts.
module CNO.Examples

import CNO.Core
import CNO.Proof
import CNO.Composition
import CNO.Verified

%default total

-------------------------------------------------------------------
-- Basic Examples
-------------------------------------------------------------------

||| The simplest possible CNO
public export
trivialCNO : CNO a
trivialCNO = idCNO

||| A "validation" that always passes (does nothing)
public export
alwaysValid : CNO a
alwaysValid = MkCNO id (\x => Refl)

||| A "transformation" that transforms nothing
public export
nullTransform : CNO a
nullTransform = MkCNO id (\x => Refl)

-------------------------------------------------------------------
-- Numeric CNOs
-------------------------------------------------------------------

||| Add zero (identity on numbers)
public export
addZero : CNO Integer
addZero = MkCNO (\x => x + 0) (\x => rewrite plusZeroRightNeutral x in Refl)
  where
    plusZeroRightNeutral : (x : Integer) -> x + 0 = x
-- PROOF_TODO: Replace cast with actual proof
-- PROOF_TODO: Replace cast with actual proof
    plusZeroRightNeutral x = cast (Refl {x})

||| Multiply by one (identity on numbers)
public export
multiplyOne : CNO Integer
-- PROOF_TODO: Replace cast with actual proof
-- PROOF_TODO: Replace cast with actual proof
multiplyOne = MkCNO (\x => x * 1) (\x => cast (Refl {x}))

-------------------------------------------------------------------
-- List CNOs
-------------------------------------------------------------------

||| Append empty list (identity on lists)
public export
appendNil : CNO (List a)
appendNil = MkCNO (\xs => xs ++ []) (\xs => appendNilRightNeutral xs)
  where
    appendNilRightNeutral : (xs : List a) -> xs ++ [] = xs
    appendNilRightNeutral [] = Refl
    appendNilRightNeutral (x :: xs) = cong (x ::) (appendNilRightNeutral xs)

||| Reverse twice (identity on lists)
public export
reverseReverse : CNO (List a)
-- PROOF_TODO: Replace cast with actual proof
-- PROOF_TODO: Replace cast with actual proof
reverseReverse = MkCNO (\xs => reverse (reverse xs)) (\xs => cast (Refl {x = xs}))

-------------------------------------------------------------------
-- Maybe CNOs
-------------------------------------------------------------------

||| Map identity over Maybe
public export
mapIdMaybe : CNO (Maybe a)
mapIdMaybe = MkCNO (map id) mapIdIsId
  where
    mapIdIsId : (mx : Maybe a) -> map Prelude.id mx = mx
    mapIdIsId Nothing = Refl
    mapIdIsId (Just x) = Refl

-------------------------------------------------------------------
-- Pair CNOs
-------------------------------------------------------------------

||| Swap twice (identity on pairs)
public export
swapSwap : CNO (a, b)
swapSwap = MkCNO (\(x, y) => let (y', x') = (y, x) in (x', y'))
                (\(x, y) => Refl)

-------------------------------------------------------------------
-- Function CNOs
-------------------------------------------------------------------

||| Compose with identity (identity on functions)
public export
composeId : CNO (a -> a)
composeId = MkCNO (\f => id . f) (\f => Refl)

-------------------------------------------------------------------
-- Logging/Tracing CNO
-------------------------------------------------------------------

||| A "logging" operation that logs nothing
||| In a real system, this might be a no-op logger
public export
nullLog : CNO a
nullLog = MkCNO id (\x => Refl)

-------------------------------------------------------------------
-- Caching CNO
-------------------------------------------------------------------

||| A "cache" that doesn't actually cache
||| Useful as a placeholder or disabled cache
public export
nullCache : CNO a
nullCache = MkCNO id (\x => Refl)

-------------------------------------------------------------------
-- Composed Examples
-------------------------------------------------------------------

||| Chain of no-ops
public export
noopChain : CNOChain 3 Integer
noopChain = noop "step1" :: noop "step2" :: noop "step3" :: Nil

||| Parallel CNO on pair
public export
parallelExample : CNO (Integer, List a)
parallelExample = addZero *** appendNil

-------------------------------------------------------------------
-- Use Case: Safe Middleware
-------------------------------------------------------------------

||| A middleware that does nothing but is type-safe
||| Can be used as a placeholder in middleware chains
public export
noopMiddleware : CNO a
noopMiddleware = idCNO

||| Example: a "disabled feature" that compiles away to nothing
public export
disabledFeature : CNO a
disabledFeature = idCNO

-------------------------------------------------------------------
-- Forward/Backward Composition
-------------------------------------------------------------------

||| Chain operations left-to-right (all are identity anyway)
public export
pipeline : CNO Integer
pipeline = addZero >>> multiplyOne >>> idCNO

||| Chain operations right-to-left
public export
composedChain : CNO Integer
composedChain = idCNO <<< multiplyOne <<< addZero

-------------------------------------------------------------------
-- Conditional CNOs
-------------------------------------------------------------------

||| A feature that might be enabled or disabled (always CNO)
public export
maybeFeature : Bool -> CNO a
maybeFeature True = idCNO    -- Feature "enabled" (does nothing)
maybeFeature False = idCNO   -- Feature "disabled" (does nothing)

||| Choose between two CNOs (both are identity anyway)
public export
chooseOperation : Either () () -> CNO a
chooseOperation (Left _) = idCNO
chooseOperation (Right _) = idCNO

-------------------------------------------------------------------
-- Type Transformations
-------------------------------------------------------------------

||| Nest a CNO inside Maybe
public export
nestedMaybe : CNO a -> CNO (Maybe a)
nestedMaybe cno = mapIdMaybe

||| CNO on nested structure
public export
nestedList : CNO (List (Maybe a))
nestedList = MkCNO id (\xs => Refl)

-------------------------------------------------------------------
-- Reversible Patterns
-------------------------------------------------------------------

||| Reverse twice on nested lists
public export
doubleReverseNested : CNO (List (List a))
-- PROOF_TODO: Replace cast with actual proof
-- PROOF_TODO: Replace cast with actual proof
doubleReverseNested = MkCNO (\xs => reverse (reverse xs)) (\xs => cast (Refl {x = xs}))

||| Identity on triple (rotation example simplified)
public export
tripleId : CNO (a, a, a)
tripleId = MkCNO id (\_ => Refl)

-------------------------------------------------------------------
-- Domain-Specific CNO Patterns
-------------------------------------------------------------------

||| A "sanitizer" that doesn't change the input
public export
nullSanitizer : CNO String
nullSanitizer = idCNO

||| A "normalizer" that normalizes nothing
public export
nullNormalizer : CNO a
nullNormalizer = idCNO

||| A "compressor" that doesn't compress
public export
nullCompressor : CNO a
nullCompressor = idCNO

||| A "serializer" that returns the same data
public export
nullSerializer : CNO a
nullSerializer = idCNO

-------------------------------------------------------------------
-- Proof Examples
-------------------------------------------------------------------

||| Prove that addZero is identity
public export
addZeroIsId : (x : Integer) -> runCNO Examples.addZero x = x
addZeroIsId x = cnoProof Examples.addZero x

||| Prove that composition is identity
public export
composeIsId : (x : Integer) -> runCNO (compose Examples.addZero Examples.multiplyOne) x = x
composeIsId x = cnoProof (compose Examples.addZero Examples.multiplyOne) x

||| Prove that parallel composition preserves pairs
public export
parallelPreserves : (x : Integer) -> (xs : List a) ->
                    runCNO (Examples.addZero *** Examples.appendNil) (x, xs) = (x, xs)
parallelPreserves x xs = cnoProof (Examples.addZero *** Examples.appendNil) (x, xs)

-------------------------------------------------------------------
-- Sum Type Examples
-------------------------------------------------------------------

||| CNO on Either Integer String
public export
eitherCNO : CNO (Either Integer String)
eitherCNO = idCNO +++ idCNO

||| Process either side identically
public export
eitherProcess : Either Integer Integer -> Either Integer Integer
eitherProcess = runCNO (addZero +++ multiplyOne)

-------------------------------------------------------------------
-- Higher-Order CNO
-------------------------------------------------------------------

||| CNO that maps identity over a functor (if we had Functor)
public export
mapIdList : CNO (List a)
mapIdList = MkCNO (map id) mapIdIsId
  where
    mapIdIsId : (xs : List a) -> map Prelude.id xs = xs
    mapIdIsId [] = Refl
    mapIdIsId (x :: xs) = cong (x ::) (mapIdIsId xs)

-------------------------------------------------------------------
-- Real-World Pattern: Middleware
-------------------------------------------------------------------

||| A middleware chain where all middlewares are CNOs
public export
middlewareChain : CNO a
middlewareChain = composeAll [idCNO, idCNO, idCNO, idCNO]

||| Example: logging middleware that logs nothing
public export
loggingMiddleware : CNO a
loggingMiddleware = nullLog

||| Example: auth middleware that accepts everything
public export
noopAuthMiddleware : CNO a
noopAuthMiddleware = idCNO

||| Example: rate limiter that limits nothing
public export
noopRateLimiter : CNO a
noopRateLimiter = idCNO

||| Complete middleware stack
public export
fullMiddlewareStack : CNO a
fullMiddlewareStack = loggingMiddleware >>> noopAuthMiddleware >>> noopRateLimiter


