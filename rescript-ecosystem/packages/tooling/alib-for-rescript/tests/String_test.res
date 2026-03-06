// SPDX-License-Identifier: PMPL-1.0-or-later
open RescriptMocha
open Mocha

describe("String Operations", () => {
  describe("concat", () => {
    it("concatenates two strings", () => {
      Assert.equal(String.concat("Hello", " World"), "Hello World")
      Assert.equal(String.concat("", "test"), "test")
      Assert.equal(String.concat("test", ""), "test")
      Assert.equal(String.concat("a", "b"), "ab")
    })

    it("is associative", () => {
      Assert.equal(
        String.concat(String.concat("a", "b"), "c"),
        String.concat("a", String.concat("b", "c")),
      )
    })

    it("has empty string as identity", () => {
      Assert.equal(String.concat("test", ""), "test")
      Assert.equal(String.concat("", "test"), "test")
    })
  })

  describe("length", () => {
    it("returns the length of a string", () => {
      Assert.equal(String.length("Hello"), 5)
      Assert.equal(String.length(""), 0)
      Assert.equal(String.length("🎉"), 2) // ReScript counts UTF-16 code units
      Assert.equal(String.length("Test 123"), 8)
    })

    it("is non-negative", () => {
      Assert.ok(String.length("") >= 0)
      Assert.ok(String.length("test") >= 0)
    })

    it("satisfies concatenation property", () => {
      let a = "Hello"
      let b = " World"
      Assert.equal(String.length(String.concat(a, b)), String.length(a) + String.length(b))
    })
  })

  describe("substring", () => {
    it("extracts substrings", () => {
      Assert.equal(String.substring("Hello World", 0, 4), "Hello")
      Assert.equal(String.substring("Hello World", 6, 10), "World")
      Assert.equal(String.substring("Test", 0, 0), "T")
      Assert.equal(String.substring("Test", 2, 1), "")
    })
  })

  describe("indexOf", () => {
    it("finds substring position", () => {
      Assert.equal(String.indexOf("Hello World", "World"), 6)
      Assert.equal(String.indexOf("Hello World", "o"), 4)
      Assert.equal(String.indexOf("Test", "xyz"), -1)
      Assert.equal(String.indexOf("Test", ""), 0)
    })

    it("returns -1 when not found", () => {
      Assert.equal(String.indexOf("Hello", "xyz"), -1)
    })

    it("finds empty substring at start", () => {
      Assert.equal(String.indexOf("Test", ""), 0)
      Assert.equal(String.indexOf("", ""), 0)
    })
  })

  describe("contains", () => {
    it("checks if string contains substring", () => {
      Assert.equal(String.contains("Hello World", "World"), true)
      Assert.equal(String.contains("Hello World", "xyz"), false)
      Assert.equal(String.contains("Test", ""), true)
      Assert.equal(String.contains("", "Test"), false)
    })

    it("always contains empty string", () => {
      Assert.equal(String.contains("Test", ""), true)
      Assert.equal(String.contains("", ""), true)
    })

    it("is reflexive", () => {
      Assert.equal(String.contains("Hello", "Hello"), true)
    })
  })

  describe("startsWith", () => {
    it("checks if string starts with prefix", () => {
      Assert.equal(String.startsWith("Hello World", "Hello"), true)
      Assert.equal(String.startsWith("Hello World", "World"), false)
      Assert.equal(String.startsWith("Test", ""), true)
      Assert.equal(String.startsWith("", "Test"), false)
    })

    it("always starts with empty prefix", () => {
      Assert.equal(String.startsWith("Test", ""), true)
      Assert.equal(String.startsWith("", ""), true)
    })

    it("is reflexive", () => {
      Assert.equal(String.startsWith("Hello", "Hello"), true)
    })
  })

  describe("endsWith", () => {
    it("checks if string ends with suffix", () => {
      Assert.equal(String.endsWith("Hello World", "World"), true)
      Assert.equal(String.endsWith("Hello World", "Hello"), false)
      Assert.equal(String.endsWith("Test", ""), true)
      Assert.equal(String.endsWith("", "Test"), false)
    })

    it("always ends with empty suffix", () => {
      Assert.equal(String.endsWith("Test", ""), true)
      Assert.equal(String.endsWith("", ""), true)
    })

    it("is reflexive", () => {
      Assert.equal(String.endsWith("Hello", "Hello"), true)
    })
  })

  describe("toUppercase", () => {
    it("converts to uppercase", () => {
      Assert.equal(String.toUppercase("Hello World"), "HELLO WORLD")
      Assert.equal(String.toUppercase("test"), "TEST")
      Assert.equal(String.toUppercase("TEST"), "TEST")
      Assert.equal(String.toUppercase("café"), "CAFÉ")
    })

    it("is idempotent", () => {
      Assert.equal(String.toUppercase(String.toUppercase("test")), String.toUppercase("test"))
    })
  })

  describe("toLowercase", () => {
    it("converts to lowercase", () => {
      Assert.equal(String.toLowercase("Hello World"), "hello world")
      Assert.equal(String.toLowercase("TEST"), "test")
      Assert.equal(String.toLowercase("test"), "test")
      Assert.equal(String.toLowercase("CAFÉ"), "café")
    })

    it("is idempotent", () => {
      Assert.equal(String.toLowercase(String.toLowercase("TEST")), String.toLowercase("TEST"))
    })
  })

  describe("trim", () => {
    it("removes leading and trailing whitespace", () => {
      Assert.equal(String.trim("  Hello World  "), "Hello World")
      Assert.equal(String.trim("\n\tTest\n"), "Test")
      Assert.equal(String.trim("NoSpaces"), "NoSpaces")
      Assert.equal(String.trim("   "), "")
    })

    it("is idempotent", () => {
      Assert.equal(String.trim(String.trim("  test  ")), String.trim("  test  "))
    })

    it("preserves internal whitespace", () => {
      Assert.equal(String.trim("  Hello World  "), "Hello World")
    })
  })

  describe("split", () => {
    it("splits string by delimiter", () => {
      Assert.deepEqual(String.split("a,b,c", ","), ["a", "b", "c"])
      Assert.deepEqual(String.split("Hello World", " "), ["Hello", "World"])
      Assert.deepEqual(String.split("test", ","), ["test"])
      Assert.deepEqual(String.split("a,,b", ","), ["a", "", "b"])
    })

    it("splits by empty delimiter into characters", () => {
      Assert.deepEqual(String.split("abc", ""), ["a", "b", "c"])
    })

    it("returns single element when not found", () => {
      Assert.deepEqual(String.split("test", ","), ["test"])
    })
  })

  describe("join", () => {
    it("joins array with separator", () => {
      Assert.equal(String.join(["a", "b", "c"], ","), "a,b,c")
      Assert.equal(String.join(["Hello", "World"], " "), "Hello World")
      Assert.equal(String.join(["test"], ","), "test")
      Assert.equal(String.join([], ","), "")
    })

    it("returns empty string for empty array", () => {
      Assert.equal(String.join([], ","), "")
    })

    it("returns single element unchanged", () => {
      Assert.equal(String.join(["test"], ","), "test")
    })

    it("is inverse of split", () => {
      let original = "a,b,c"
      Assert.equal(String.join(String.split(original, ","), ","), original)
    })
  })

  describe("replace", () => {
    it("replaces all occurrences", () => {
      Assert.equal(String.replace("Hello World", "World", "Universe"), "Hello Universe")
      Assert.equal(String.replace("test test", "test", "demo"), "demo demo")
      Assert.equal(String.replace("Hello", "xyz", "abc"), "Hello")
      Assert.equal(String.replace("Hello", "l", ""), "Heo")
    })

    it("returns unchanged when not found", () => {
      Assert.equal(String.replace("Hello", "xyz", "abc"), "Hello")
    })

    it("returns unchanged when old is empty", () => {
      Assert.equal(String.replace("Hello", "", "x"), "Hello")
    })

    it("replaces multiple occurrences", () => {
      Assert.equal(String.replace("test test test", "test", "demo"), "demo demo demo")
    })
  })

  describe("isEmpty", () => {
    it("checks if string is empty", () => {
      Assert.equal(String.isEmpty(""), true)
      Assert.equal(String.isEmpty("test"), false)
      Assert.equal(String.isEmpty(" "), false)
    })

    it("is equivalent to length check", () => {
      Assert.equal(String.isEmpty(""), String.length("") == 0)
      Assert.equal(String.isEmpty("test"), String.length("test") == 0)
    })
  })
})
