-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-ca protocol.
-- X.509 Certificate Authority types for ACME (RFC 8555),
-- EST (RFC 7030), and SCEP enrollment protocols.

module Types

import Data.List

||| CA enrollment protocol selection.
public export
data Protocol : Type where
  ACME : Protocol  -- RFC 8555 (Let's Encrypt, step-ca)
  EST  : Protocol  -- RFC 7030 (Enterprise enrollment)
  SCEP : Protocol  -- Legacy device enrollment

||| Asymmetric key algorithm for CSR generation.
public export
data KeyAlgorithm : Type where
  RSA2048   : KeyAlgorithm
  RSA4096   : KeyAlgorithm
  ECDSAP256 : KeyAlgorithm
  ECDSAP384 : KeyAlgorithm
  Ed25519   : KeyAlgorithm

||| Certificate revocation status.
public export
data CertStatus : Type where
  Valid   : CertStatus
  Revoked : CertStatus
  Expired : CertStatus
  Pending : CertStatus
  Unknown : CertStatus

||| Revocation reason code (RFC 5280 section 5.3.1).
public export
data RevocationReason : Type where
  Unspecified          : RevocationReason
  KeyCompromise        : RevocationReason
  CaCompromise         : RevocationReason
  AffiliationChanged   : RevocationReason
  Superseded           : RevocationReason
  CessationOfOperation : RevocationReason

||| ACME challenge type for domain validation.
public export
data ChallengeType : Type where
  Http01    : ChallengeType  -- File-based HTTP challenge
  Dns01     : ChallengeType  -- DNS TXT record challenge
  TlsAlpn01 : ChallengeType -- TLS-ALPN extension challenge

||| X.509 distinguished name subject fields.
public export
record Subject where
  constructor MkSubject
  commonName         : String
  organization       : String
  organizationalUnit : String
  country            : String
  state              : String
  locality           : String

||| Certificate signing request parameters.
public export
record CertificateRequest where
  constructor MkCertificateRequest
  subject  : Subject
  dnsNames : List String
  ipAddrs  : List String
  keyAlgo  : KeyAlgorithm

||| An issued X.509 certificate with metadata.
public export
record Certificate where
  constructor MkCertificate
  pem       : String
  chainPem  : String
  serial    : String
  issuer    : String
  subjectDN : String
  dnsNames  : List String
  status    : CertStatus
