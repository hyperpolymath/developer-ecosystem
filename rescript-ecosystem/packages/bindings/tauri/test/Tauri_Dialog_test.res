// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Dialog_test.res - Tests for Tauri_Dialog bindings

open RescriptCore
open Deno_Test

// Helper to check if array contains element
let arrayIncludes = (arr: array<string>, item: string) => {
  Array.some(arr, x => x == item)
}

let () = {
  // ============================================================================
  // Type Structure Tests
  // ============================================================================

  test("Dialog: dialogFilter has correct structure", async () => {
    let filter: Tauri_Dialog.dialogFilter = {
      name: "Images",
      extensions: ["png", "jpg", "gif"],
    }
    Assert.equals(filter.name, "Images")
    Assert.hasLength(filter.extensions, 3)
  })

  test("Dialog: messageKind variants exist", async () => {
    let info: Tauri_Dialog.messageKind = Info
    let warning: Tauri_Dialog.messageKind = Warning
    let error: Tauri_Dialog.messageKind = Error_

    Assert.equals(info, Tauri_Dialog.Info)
    Assert.equals(warning, Tauri_Dialog.Warning)
    Assert.equals(error, Tauri_Dialog.Error_)
  })

  test("Dialog: openDialogOptions accepts all fields", async () => {
    let opts: Tauri_Dialog.openDialogOptions = {
      title: "Open File",
      defaultPath: "/home/user",
      filters: [{name: "All", extensions: ["*"]}],
      multiple: true,
      directory: false,
      recursive: false,
      canCreateDirectories: true,
    }
    Assert.equals(opts.title, Some("Open File"))
    Assert.equals(opts.multiple, Some(true))
  })

  test("Dialog: saveDialogOptions accepts all fields", async () => {
    let opts: Tauri_Dialog.saveDialogOptions = {
      title: "Save File",
      defaultPath: "/home/user/document.txt",
      filters: [{name: "Text", extensions: ["txt"]}],
      canCreateDirectories: true,
    }
    Assert.equals(opts.title, Some("Save File"))
  })

  // ============================================================================
  // Filter Presets Tests
  // ============================================================================

  test("Filters: images preset has common image extensions", async () => {
    let filter = Tauri_Dialog.Filters.images
    Assert.equals(filter.name, "Images")
    Assert.isTrue(arrayIncludes(filter.extensions, "png"))
    Assert.isTrue(arrayIncludes(filter.extensions, "jpg"))
    Assert.isTrue(arrayIncludes(filter.extensions, "gif"))
  })

  test("Filters: documents preset has document extensions", async () => {
    let filter = Tauri_Dialog.Filters.documents
    Assert.equals(filter.name, "Documents")
    Assert.isTrue(arrayIncludes(filter.extensions, "pdf"))
    Assert.isTrue(arrayIncludes(filter.extensions, "txt"))
  })

  test("Filters: audio preset has audio extensions", async () => {
    let filter = Tauri_Dialog.Filters.audio
    Assert.equals(filter.name, "Audio")
    Assert.isTrue(arrayIncludes(filter.extensions, "mp3"))
    Assert.isTrue(arrayIncludes(filter.extensions, "wav"))
  })

  test("Filters: video preset has video extensions", async () => {
    let filter = Tauri_Dialog.Filters.video
    Assert.equals(filter.name, "Video")
    Assert.isTrue(arrayIncludes(filter.extensions, "mp4"))
    Assert.isTrue(arrayIncludes(filter.extensions, "webm"))
  })

  test("Filters: json preset has json extension", async () => {
    let filter = Tauri_Dialog.Filters.json
    Assert.equals(filter.name, "JSON")
    Assert.hasLength(filter.extensions, 1)
    Assert.equals(filter.extensions[0], Some("json"))
  })

  test("Filters: all preset has wildcard", async () => {
    let filter = Tauri_Dialog.Filters.all
    Assert.equals(filter.name, "All Files")
    Assert.equals(filter.extensions[0], Some("*"))
  })

  test("Filters: custom creates filter with given values", async () => {
    let filter = Tauri_Dialog.Filters.custom(
      ~name="ReScript",
      ~extensions=["res", "resi"],
    )
    Assert.equals(filter.name, "ReScript")
    Assert.hasLength(filter.extensions, 2)
  })

  // ============================================================================
  // OpenDialog Builder Tests
  // ============================================================================

  test("OpenDialog: builder chain works", async () => {
    let builder = Tauri_Dialog.OpenDialog.make()
      ->Tauri_Dialog.OpenDialog.title("Select File")
      ->Tauri_Dialog.OpenDialog.defaultPath("/home")
      ->Tauri_Dialog.OpenDialog.filter(Tauri_Dialog.Filters.images)
      ->Tauri_Dialog.OpenDialog.multiple

    // If we get here, the chain compiled and ran
    Assert.isTrue(true)
    ignore(builder)
  })

  test("OpenDialog: filters can be chained", async () => {
    let builder = Tauri_Dialog.OpenDialog.make()
      ->Tauri_Dialog.OpenDialog.filter(Tauri_Dialog.Filters.images)
      ->Tauri_Dialog.OpenDialog.filter(Tauri_Dialog.Filters.video)

    Assert.isTrue(true)
    ignore(builder)
  })

  test("OpenDialog: filters can be set in batch", async () => {
    let builder = Tauri_Dialog.OpenDialog.make()
      ->Tauri_Dialog.OpenDialog.filters([
        Tauri_Dialog.Filters.images,
        Tauri_Dialog.Filters.video,
        Tauri_Dialog.Filters.audio,
      ])

    Assert.isTrue(true)
    ignore(builder)
  })

  // ============================================================================
  // SaveDialog Builder Tests
  // ============================================================================

  test("SaveDialog: builder chain works", async () => {
    let builder = Tauri_Dialog.SaveDialog.make()
      ->Tauri_Dialog.SaveDialog.title("Save As")
      ->Tauri_Dialog.SaveDialog.defaultPath("/home/document.txt")
      ->Tauri_Dialog.SaveDialog.filter(Tauri_Dialog.Filters.documents)

    Assert.isTrue(true)
    ignore(builder)
  })
}
