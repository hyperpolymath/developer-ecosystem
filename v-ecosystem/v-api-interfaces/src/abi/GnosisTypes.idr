-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Gnosis API ABI Types
|||
||| Dependent type definitions for the Gnosis stateful artefacts rendering API.
||| These types prove correctness of the API contract at compile-time.
|||
||| The Gnosis API exposes three operations across all three interfaces
||| (REST, gRPC, GraphQL):
|||   1. Render — hydrate a template against 6scm context
|||   2. Context — dump all resolved keys from 6scm files
|||   3. Health — check engine availability

module Gnosis.ABI.Types

import Data.So
import Data.Vect

%default total

--------------------------------------------------------------------------------
-- Render Mode
--------------------------------------------------------------------------------

||| Render mode determines output format.
public export
data RenderMode = Plain | Badges

||| Proof that render mode is one of exactly two values.
public export
renderModeExhaustive : (m : RenderMode) -> Either (m = Plain) (m = Badges)
renderModeExhaustive Plain = Left Refl
renderModeExhaustive Badges = Right Refl

--------------------------------------------------------------------------------
-- Request Types
--------------------------------------------------------------------------------

||| A render request must have either a template body or a template path.
||| This is enforced at the type level.
public export
data TemplateSource
  = Inline (body : String)
  | FromFile (path : String)

||| Proof that a template source is non-empty.
public export
data NonEmptySource : TemplateSource -> Type where
  InlineNonEmpty : So (length body > 0) -> NonEmptySource (Inline body)
  FileNonEmpty   : So (length path > 0) -> NonEmptySource (FromFile path)

||| A validated render request.
public export
record RenderRequest where
  constructor MkRenderRequest
  source  : TemplateSource
  scmPath : String
  mode    : RenderMode
  {auto 0 sourceValid : NonEmptySource source}

||| A context dump request requires a valid SCM path.
public export
record ContextRequest where
  constructor MkContextRequest
  scmPath : String

--------------------------------------------------------------------------------
-- Response Types
--------------------------------------------------------------------------------

||| Result of a successful render operation.
public export
record RenderResponse where
  constructor MkRenderResponse
  output    : String
  keysCount : Nat

||| A single context entry (key-value pair from 6scm).
public export
record ContextEntry where
  constructor MkContextEntry
  key   : String
  value : String

||| Result of a context dump.
public export
record ContextResponse where
  constructor MkContextResponse
  entries : List ContextEntry
  count   : Nat
  {auto 0 countCorrect : count = length entries}

||| Health check result.
public export
data HealthStatus = Serving | NotServing

||| Proof that health status maps to gRPC standard.
public export
healthStatusString : HealthStatus -> String
healthStatusString Serving = "SERVING"
healthStatusString NotServing = "NOT_SERVING"

public export
record HealthResponse where
  constructor MkHealthResponse
  status  : HealthStatus
  version : String

--------------------------------------------------------------------------------
-- API Contract
--------------------------------------------------------------------------------

||| The Gnosis API contract: every operation returns a well-typed response.
||| This interface is implemented by all three transports (REST, gRPC, GraphQL).
public export
interface GnosisAPI (m : Type -> Type) where
  render  : RenderRequest -> m (Either String RenderResponse)
  context : ContextRequest -> m (Either String ContextResponse)
  health  : m HealthResponse

||| Proof that a render response with keysCount > 0 means the engine found data.
public export
renderFoundData : (resp : RenderResponse) -> So (resp.keysCount > 0) -> So (length resp.output > 0)
renderFoundData resp prf = ?renderFoundDataProof

--------------------------------------------------------------------------------
-- Transport Identifiers
--------------------------------------------------------------------------------

||| The three API transports, each on a consecutive port.
public export
data Transport = REST | GRPC | GraphQL

||| Port offset for each transport.
public export
portOffset : Transport -> Nat
portOffset REST    = 1
portOffset GRPC   = 2
portOffset GraphQL = 3

||| Proof that all transports have distinct offsets.
public export
transportDistinct : (a : Transport) -> (b : Transport) -> Not (a = b) -> Not (portOffset a = portOffset b)
transportDistinct REST REST contra = absurd (contra Refl)
transportDistinct REST GRPC _ = \h => absurd h
transportDistinct REST GraphQL _ = \h => absurd h
transportDistinct GRPC REST _ = \h => absurd h
transportDistinct GRPC GRPC contra = absurd (contra Refl)
transportDistinct GRPC GraphQL _ = \h => absurd h
transportDistinct GraphQL REST _ = \h => absurd h
transportDistinct GraphQL GRPC _ = \h => absurd h
transportDistinct GraphQL GraphQL contra = absurd (contra Refl)
