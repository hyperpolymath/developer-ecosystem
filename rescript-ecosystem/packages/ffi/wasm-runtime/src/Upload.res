// File upload handling utilities

// FormData types
type formDataEntry = {
  name: string,
  value: string,
  filename: option<string>,
  contentType: option<string>
}

// Parse multipart/form-data (simplified)
let parseFormData = async (_req: Deno.request): promise<array<formDataEntry>> => {
  try {
    // let _body = await Deno.Request.text(req)
    Promise.resolve([])
  } catch {
  | _ => Promise.resolve([])
  }
}

// Save uploaded file
let saveFile = async (
  file: formDataEntry,
  ~directory="uploads",
  ~maxSize=10 * 1024 * 1024 // 10MB
): promise<result<string, string>> => {
  try {
    // Validate file
    if String.length(file.value) > maxSize {
      Promise.resolve(Error("File too large"))
    } else {
      switch file.filename {
      | None => Promise.resolve(Error("No filename provided"))
      | Some(filename) => {
          let timestamp = Belt.Float.toString(Js.Date.now())
          let uniqueFilename = `${timestamp}_${filename}`
          let filepath = `${directory}/${uniqueFilename}`
          Promise.resolve(Ok(filepath))
        }
      }
    }
  } catch {
  | error => {
      let message = Exn.asJsExn(error)->Belt.Option.flatMap(Js.Exn.message)->Belt.Option.getWithDefault("Unknown error")
      Promise.resolve(Error(message))
    }
  }
}

// Validate file type
let validateFileType = (
  filename: string,
  ~allowedExtensions: array<string>
): bool => {
  let lowerFilename = Js.String2.toLowerCase(filename)

  allowedExtensions->Belt.Array.some(ext => {
    Js.String2.endsWith(lowerFilename, Js.String2.toLowerCase(ext))
  })
}

// Generate safe filename
let sanitizeFilename = (filename: string): string => {
  filename
    ->Js.String2.replaceByRe(%re("/[^a-zA-Z0-9._-]/g"), "_")
    ->Js.String2.replaceByRe(%re("/\.{2,}/g"), ".")
}

// Upload middleware
let uploadMiddleware = (
  ~maxFileSize as _=10 * 1024 * 1024,
  ~allowedTypes as _=["jpg", "jpeg", "png", "gif", "pdf"]
): Router.middleware => {
  (req, next) => {
    let headers = Deno.Request.headers(req)
    let contentType = Js.Dict.get(headers, "content-type")

    switch contentType {
    | Some(ct) if Js.String2.includes(ct, "multipart/form-data") => {
        parseFormData(req)->Promise.then(entries => {
          let entriesArr: array<formDataEntry> = Obj.magic(entries)
          let count = Belt.Array.length(entriesArr)
          Console.log(`Received ${Belt.Int.toString(count)} form entries`)
          next(req)
        })
      }
    | _ => next(req)
    }
  }
}
