-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-smtp protocol.
-- SMTP (RFC 5321) message types, authentication methods,
-- response codes, and MIME structures.

module Types

import Data.List

||| SMTP authentication mechanism.
public export
data AuthMethod : Type where
  Plain : AuthMethod   -- PLAIN SASL (RFC 4616)
  Login : AuthMethod   -- LOGIN (legacy two-step base64)
  NoAuth : AuthMethod  -- No authentication

||| SMTP response status code classes.
public export
data StatusClass : Type where
  Positive     : StatusClass  -- 2xx success
  Intermediate : StatusClass  -- 3xx continue (e.g. DATA input)
  Transient    : StatusClass  -- 4xx temporary failure
  Permanent    : StatusClass  -- 5xx permanent failure

||| An email address with optional display name.
public export
record Address where
  constructor MkAddress
  name  : String   -- Display name (may be empty)
  email : String   -- RFC 5321 mailbox address

||| A MIME attachment.
public export
record Attachment where
  constructor MkAttachment
  filename    : String
  contentType : String   -- MIME type
  dataLen     : Nat      -- Byte length of attachment data

||| An email message envelope and content.
public export
record Message where
  constructor MkMessage
  from        : Address
  to          : List Address
  cc          : List Address
  bcc         : List Address
  subject     : String
  bodyText    : String
  bodyHtml    : String
  attachments : List Attachment

||| SMTP server response.
public export
record SmtpResponse where
  constructor MkSmtpResponse
  code : Nat
  text : String
