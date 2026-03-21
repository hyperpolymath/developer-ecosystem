-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-ocsp protocol.
-- OCSP types: certificate statuses, revocation reasons.

module Types

||| Certificate status.
public export
data CertStatus : Type where
  Good    : CertStatus
  Revoked : CertStatus
  Unknown : CertStatus

||| Revocation reason.
public export
data RevocationReason : Type where
  Unspecified          : RevocationReason
  KeyCompromise        : RevocationReason
  CaCompromise         : RevocationReason
  AffiliationChanged   : RevocationReason
  Superseded           : RevocationReason
  Cessation            : RevocationReason
  CertificateHold      : RevocationReason

||| OCSP request.
public export
record OcspRequest where
  constructor MkOcspRequest
  serialHex  : String
  issuerHash : String
  issuerKey  : String
