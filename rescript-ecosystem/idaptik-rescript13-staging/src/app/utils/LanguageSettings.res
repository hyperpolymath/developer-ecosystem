// SPDX-License-Identifier: PMPL-1.0-or-later
// Language Settings  persisted language preference with cached ref
//
// Follows the same pattern as AccessibilitySettings.res: a cached ref
// for zero per-frame cost, with localStorage persistence.
// Auto-detects browser language on first launch, overridable from Settings.

//  Language Variants 

type language =
  | EN
  | ES
  | FR
  | DE
  | JA

let allLanguages: array<language> = [EN, ES, FR, DE, JA]

let languageToCode = (lang: language): string => {
  switch lang {
  | EN => "en"
  | ES => "es"
  | FR => "fr"
  | DE => "de"
  | JA => "ja"
  }
}

let languageFromCode = (code: string): language => {
  switch code {
  | "es" => ES
  | "fr" => FR
  | "de" => DE
  | "ja" => JA
  | _ => EN
  }
}

// Native display names for the language selector UI
let languageDisplayName = (lang: language): string => {
  switch lang {
  | EN => "English"
  | ES => "Espaol"
  | FR => "Franais"
  | DE => "Deutsch"
  | JA => ""
  }
}

// Cycle to next language
let nextLanguage = (lang: language): language => {
  switch lang {
  | EN => ES
  | ES => FR
  | FR => DE
  | DE => JA
  | JA => EN
  }
}

//  LocalStorage Key 

let keyLanguage = "idaptik-language"

//  Cached Ref 

let languageRef = ref(EN)

//  Getters (read from cached ref) 

let getLanguage = (): language => languageRef.contents
let getLanguageCode = (): string => languageToCode(languageRef.contents)

//  Setter (update ref + persist to localStorage) 

let setLanguage = (lang: language): unit => {
  languageRef := lang
  Storage.setString(keyLanguage, languageToCode(lang))
}

// Cycle language forward (returns the new language)
let cycleLanguage = (): language => {
  let next = nextLanguage(languageRef.contents)
  setLanguage(next)
  next
}

//  Browser Language Detection 

// Read navigator.language (e.g. "en-US", "fr", "ja")
@val @scope("navigator") external navigatorLanguage: string = "language"

// Extract the primary language subtag (e.g. "en-US" -> "en")
let detectBrowserLanguage = (): option<language> => {
  let raw = navigatorLanguage
  let primary = switch String.split(raw, "-")[0] {
  | Some(code) => String.toLowerCase(code)
  | None => ""
  }
  switch primary {
  | "en" => Some(EN)
  | "es" => Some(ES)
  | "fr" => Some(FR)
  | "de" => Some(DE)
  | "ja" => Some(JA)
  | _ => None
  }
}

//  Initialization 

let init = (): unit => {
  // Priority: localStorage > browser language > English
  let stored = Storage.getString(keyLanguage)->Option.map(languageFromCode)
  let detected = detectBrowserLanguage()

  languageRef :=
    switch stored {
    | Some(lang) => lang
    | None =>
      switch detected {
      | Some(lang) => lang
      | None => EN
      }
    }
}
