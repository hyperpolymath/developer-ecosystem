-- SPDX-License-Identifier: MIT
-- | Mark2 Integrity Module - Cryptographic chain of custody for eTMA marking
-- |
-- | Provides independent, tamper-evident records that can cross-check
-- | against university systems in case of disputes.
module Mark2.Integrity

import Data.String
import System.Clock

%default total

||| Supported hash algorithms
public export
data HashAlgorithm = SHA256 | SHA384 | SHA512 | BLAKE3

||| A cryptographic hash with its algorithm
public export
record ContentHash where
  constructor MkHash
  algorithm : HashAlgorithm
  value     : String  -- hex encoded

||| RFC 3161 Timestamp Token from a trusted TSA
public export
record TimestampToken where
  constructor MkTST
  authority   : String  -- e.g., "timestamp.digicert.com"
  tokenBase64 : String  -- the actual RFC 3161 response
  verifiedAt  : String  -- ISO 8601 datetime

||| Digital signature
public export
record Signature where
  constructor MkSig
  algorithm : String  -- e.g., "Ed25519"
  publicKey : String  -- hex encoded
  signature : String  -- hex encoded

||| Integrity record for a single file at a point in time
public export
record IntegrityRecord where
  constructor MkRecord
  filepath      : String
  contentHash   : ContentHash
  timestamp     : TimestampToken
  previousHash  : Maybe String     -- hash of previous state (chain link)
  eventType     : String           -- INGRESS, EDIT, EGRESS
  signature     : Signature

||| Chain of custody - ordered list of integrity records
public export
record ChainOfCustody where
  constructor MkChain
  submissionId  : String           -- e.g., "E225-25J-01-hd3393"
  studentId     : String
  tutorId       : String
  records       : List IntegrityRecord

||| Validation result
public export
data ValidationResult
  = Valid
  | InvalidHash (expected : String) (actual : String)
  | InvalidSignature
  | InvalidTimestamp
  | BrokenChain (atIndex : Nat)
  | InvalidXml (line : Nat) (col : Nat) (msg : String)
  | InvalidZip String
  | MissingFile String

||| The events we track
public export
data CustodyEvent
  = Ingress           -- tutor receives from OU
  | ValidationPassed  -- all checks passed
  | ValidationFailed ValidationResult
  | EditStarted       -- tutor opens for marking
  | EditSaved         -- tutor saves changes
  | CommentAdded      -- comment injected
  | Egress            -- tutor returns to OU

export
Show CustodyEvent where
  show Ingress = "INGRESS"
  show ValidationPassed = "VALIDATION_PASSED"
  show (ValidationFailed r) = "VALIDATION_FAILED"
  show EditStarted = "EDIT_STARTED"
  show EditSaved = "EDIT_SAVED"
  show CommentAdded = "COMMENT_ADDED"
  show Egress = "EGRESS"

||| File types we validate
public export
data FileType = FHI | DOCX | DOC | PDF | Unknown

export
detectFileType : String -> FileType
detectFileType path =
  if isSuffixOf ".fhi" path then FHI
  else if isSuffixOf ".docx" path then DOCX
  else if isSuffixOf ".doc" path then DOC
  else if isSuffixOf ".pdf" path then PDF
  else Unknown

||| What we check for each file type
public export
record ValidationChecks where
  constructor MkChecks
  checkZipIntegrity   : Bool  -- for DOCX
  checkXmlWellFormed  : Bool  -- for FHI, DOCX internals
  checkRelationships  : Bool  -- for DOCX
  checkNoMacros       : Bool  -- for DOCX
  checkMediaFiles     : Bool  -- for DOCX
  checkEncoding       : Bool  -- for all text
  checkFileSize       : Bool  -- sanity check

||| Default checks for DOCX
export
docxChecks : ValidationChecks
docxChecks = MkChecks True True True True True True True

||| Default checks for FHI
export
fhiChecks : ValidationChecks
fhiChecks = MkChecks False True False False False True True

||| Summary of validation for reporting
public export
record ValidationReport where
  constructor MkReport
  filepath        : String
  fileType        : FileType
  fileSize        : Nat
  contentHash     : ContentHash
  zipValid        : Maybe Bool      -- Nothing if not applicable
  xmlFilesChecked : List (String, Bool)  -- filename, valid?
  overallResult   : ValidationResult
  timestamp       : String
