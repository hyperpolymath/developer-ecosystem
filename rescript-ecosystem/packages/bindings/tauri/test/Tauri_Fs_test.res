// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Fs_test.res - Tests for Tauri_Fs bindings

open RescriptCore
open Deno_Test

let () = {
  // ============================================================================
  // Type Structure Tests
  // ============================================================================

  test("Fs: baseDirectory has all variants", async () => {
    // Test that all variants exist and compile
    let dirs: array<Tauri_Fs.baseDirectory> = [
      Audio, Cache, Config, Data, LocalData, Document, Download,
      Picture, Public, Video, Resource, Temp, AppConfig, AppData,
      AppLocalData, AppCache, AppLog, Desktop, Executable, Font,
      Home, Runtime, Template,
    ]
    Assert.hasLength(dirs, 23)
  })

  test("Fs: seekMode has all variants", async () => {
    let start: Tauri_Fs.seekMode = Start
    let current: Tauri_Fs.seekMode = Current
    let end: Tauri_Fs.seekMode = End

    Assert.equals(start, Tauri_Fs.Start)
    Assert.equals(current, Tauri_Fs.Current)
    Assert.equals(end, Tauri_Fs.End)
  })

  test("Fs: watchEventKind has all variants", async () => {
    let create: Tauri_Fs.watchEventKind = Create
    let modify: Tauri_Fs.watchEventKind = Modify
    let remove: Tauri_Fs.watchEventKind = Remove
    let any: Tauri_Fs.watchEventKind = Any

    Assert.equals(create, Tauri_Fs.Create)
    Assert.equals(modify, Tauri_Fs.Modify)
    Assert.equals(remove, Tauri_Fs.Remove)
    Assert.equals(any, Tauri_Fs.Any)
  })

  test("Fs: fileInfo has correct structure", async () => {
    let info: Tauri_Fs.fileInfo = {
      isFile: true,
      isDirectory: false,
      isSymlink: false,
      size: 1024.0,
      mtime: Nullable.make(1234567890.0),
      atime: Nullable.make(1234567890.0),
      birthtime: Nullable.null,
      readonly: false,
      mode: Nullable.make(0o644),
      uid: Nullable.make(1000),
      gid: Nullable.make(1000),
    }
    Assert.isTrue(info.isFile)
    Assert.isFalse(info.isDirectory)
    Assert.equals(info.size, 1024.0)
  })

  test("Fs: dirEntry has correct structure", async () => {
    let entry: Tauri_Fs.dirEntry = {
      name: "test.txt",
      isFile: true,
      isDirectory: false,
      isSymlink: false,
    }
    Assert.equals(entry.name, "test.txt")
    Assert.isTrue(entry.isFile)
  })

  test("Fs: openOptions accepts all fields", async () => {
    let opts: Tauri_Fs.openOptions = {
      read: true,
      write: true,
      append: false,
      truncate: true,
      create: true,
      createNew: false,
      mode: 0o644,
      baseDir: AppData,
    }
    Assert.equals(opts.read, Some(true))
    Assert.equals(opts.write, Some(true))
  })

  test("Fs: readOptions accepts baseDir", async () => {
    let opts: Tauri_Fs.readOptions = {
      baseDir: Document,
    }
    Assert.equals(opts.baseDir, Some(Document))
  })

  test("Fs: writeOptions accepts all fields", async () => {
    let opts: Tauri_Fs.writeOptions = {
      append: true,
      create: true,
      createNew: false,
      mode: 0o644,
      baseDir: AppData,
    }
    Assert.equals(opts.append, Some(true))
  })

  // ============================================================================
  // Function Existence Tests
  // ============================================================================

  test("Fs: file operation functions exist", async () => {
    let _readFile: (string, ~options: Tauri_Fs.readOptions=?) => promise<Uint8Array.t> =
      Tauri_Fs.readFile
    let _readTextFile: (string, ~options: Tauri_Fs.readOptions=?) => promise<string> =
      Tauri_Fs.readTextFile
    let _writeFile: (string, Uint8Array.t, ~options: Tauri_Fs.writeOptions=?) => promise<unit> =
      Tauri_Fs.writeFile
    let _writeTextFile: (string, string, ~options: Tauri_Fs.writeOptions=?) => promise<unit> =
      Tauri_Fs.writeTextFile
    Assert.isTrue(true)
  })

  test("Fs: directory operation functions exist", async () => {
    let _readDir: (string, ~options: Tauri_Fs.readOptions=?) => promise<array<Tauri_Fs.dirEntry>> =
      Tauri_Fs.readDir
    let _mkdir: (string, ~options: Tauri_Fs.mkdirOptions=?) => promise<unit> =
      Tauri_Fs.mkdir
    let _remove: (string, ~options: Tauri_Fs.removeOptions=?) => promise<unit> =
      Tauri_Fs.remove
    Assert.isTrue(true)
  })

  test("Fs: metadata functions exist", async () => {
    let _lstat: (string, ~options: Tauri_Fs.readOptions=?) => promise<Tauri_Fs.fileInfo> =
      Tauri_Fs.lstat
    let _exists: (string, ~options: Tauri_Fs.readOptions=?) => promise<bool> =
      Tauri_Fs.exists
    Assert.isTrue(true)
  })
}
