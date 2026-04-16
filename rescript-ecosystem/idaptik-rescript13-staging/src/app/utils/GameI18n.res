// SPDX-License-Identifier: PMPL-1.0-or-later
// Global i18n Wrapper  single entry point for all game translations
//
// All game code calls GameI18n.t("key") to get translated text.
// Uses a simple Dict lookup from Locales.res  synchronous, zero dependencies.
// If polyglot-i18n is integrated later, only this file needs to change.
//
// Fallback chain: current language  English  key itself

// Current language code (kept in sync with LanguageSettings)
let currentLang = ref("en")

//  Translation Functions 

// Simple translate  returns the translated string, or key if missing
let t = (key: string): string => {
  let translations = Locales.getTranslations(currentLang.contents)
  switch Dict.get(translations, key) {
  | Some(text) => text
  | None =>
    // Fall back to English
    if currentLang.contents != "en" {
      switch Dict.get(Locales.en, key) {
      | Some(text) => text
      | None => key
      }
    } else {
      key
    }
  }
}

// Translate with mustache-style interpolation: GameI18n.tw("hello", [("name", "Alice")])
let tw = (key: string, vars: array<(string, string)>): string => {
  let template = t(key)
  Array.reduce(vars, template, (acc, (name, value)) => {
    String.replaceAll(acc, `{{${name}}}`, value)
  })
}

// Translate plural (simple approach  picks singular or plural form)
let tn = (singularKey: string, pluralKey: string, count: float): string => {
  if count == 1.0 {
    t(singularKey)
  } else {
    t(pluralKey)
  }
}

//  Language Control 

// Change language at runtime (called from LanguageSettings.setLanguage)
let setLanguage = (langCode: string): unit => {
  currentLang := langCode
}

// Get current language code
let getLanguageCode = (): string => {
  currentLang.contents
}

//  Initialization 

// Initialize  called from Main.res after LanguageSettings.init()
let init = (): unit => {
  currentLang := LanguageSettings.getLanguageCode()
}
