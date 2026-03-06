// Database integration example (using in-memory store)
// In production, would integrate with actual database drivers

// Simple in-memory database implementation
module Database = {
  type row = Js.Dict.t<Js.Json.t>
  type table = {
    name: string,
    rows: ref<array<row>>,
    primaryKey: string,
    nextId: ref<int>
  }

  type t = ref<Js.Dict.t<table>>

  let create = (): t => {
    ref(Js.Dict.empty())
  }

  let createTable = (db: t, name: string, ~primaryKey="id"): unit => {
    let table = {
      name,
      rows: ref([]),
      primaryKey,
      nextId: ref(1)
    }
    Js.Dict.set(db.contents, name, table)
  }

  let getTable = (db: t, name: string): option<table> => {
    Js.Dict.get(db.contents, name)
  }

  let insert = (db: t, tableName: string, data: row): option<int> => {
    switch getTable(db, tableName) {
    | None => None
    | Some(table) => {
        let id = table.nextId.contents
        table.nextId := id + 1

        // Add primary key
        Js.Dict.set(data, table.primaryKey, Js.Json.number(Int.toFloat(id)))

        // Insert row
        table.rows := Array.concat(table.rows.contents, [data])

        Some(id)
      }
    }
  }

  let findAll = (db: t, tableName: string): array<row> => {
    switch getTable(db, tableName) {
    | None => []
    | Some(table) => table.rows.contents
    }
  }

  let findById = (db: t, tableName: string, id: int): option<row> => {
    switch getTable(db, tableName) {
    | None => None
    | Some(table) => {
        table.rows.contents->Array.find(row => {
          switch Js.Dict.get(row, table.primaryKey) {
          | None => false
          | Some(idJson) => {
              switch Js.Json.decodeNumber(idJson) {
              | None => false
              | Some(rowId) => Float.toInt(rowId) === id
              }
            }
          }
        })
      }
    }
  }

  let update = (db: t, tableName: string, id: int, data: row): bool => {
    switch getTable(db, tableName) {
    | None => false
    | Some(table) => {
        let index = table.rows.contents->Array.findIndex(row => {
          switch Js.Dict.get(row, table.primaryKey) {
          | None => false
          | Some(idJson) => {
              switch Js.Json.decodeNumber(idJson) {
              | None => false
              | Some(rowId) => Float.toInt(rowId) === id
              }
            }
          }
        })

        if index === -1 {
          false
        } else {
          let currentRow = Array.getUnsafe(table.rows.contents, index)

          // Merge data
          Js.Dict.entries(data)->Array.forEach(((key, value)) => {
            Js.Dict.set(currentRow, key, value)
          })

          true
        }
      }
    }
  }

  let delete = (db: t, tableName: string, id: int): bool => {
    switch getTable(db, tableName) {
    | None => false
    | Some(table) => {
        let initialLength = Array.length(table.rows.contents)

        table.rows := table.rows.contents->Array.keep(row => {
          switch Js.Dict.get(row, table.primaryKey) {
          | None => true
          | Some(idJson) => {
              switch Js.Json.decodeNumber(idJson) {
              | None => true
              | Some(rowId) => Float.toInt(rowId) !== id
              }
            }
          }
        })

        Array.length(table.rows.contents) < initialLength
      }
    }
  }
}

// Initialize database
let db = Database.create()
Database.createTable(db, "products")

// Seed data
let seedData = () => {
  let products = [
    ("name", "Laptop", "price", 999.99, "stock", 10),
    ("name", "Mouse", "price", 29.99, "stock", 50),
    ("name", "Keyboard", "price", 79.99, "stock", 30),
  ]

  products->Array.forEach(((nameKey, name, priceKey, price, stockKey, stock)) => {
    let row = Js.Dict.empty()
    Js.Dict.set(row, nameKey, Js.Json.string(name))
    Js.Dict.set(row, priceKey, Js.Json.number(price))
    Js.Dict.set(row, stockKey, Js.Json.number(Int.toFloat(stock)))

    let _ = Database.insert(db, "products", row)
  })

  Deno.log("Database seeded with sample data")
}

seedData()

// HTTP Handlers
let handleListProducts = async (_req: Deno.request): promise<Deno.response> => {
  let products = Database.findAll(db, "products")
  let productsJson = products->Array.map(row => Js.Json.object_(row))

  Deno.Response.json(Js.Json.array(productsJson), ())
}

let handleGetProduct = async (req: Deno.request): promise<Deno.response> => {
  let url = Deno.Request.url(req)
  let urlObj = Deno.Url.make(url)
  let path = Deno.Url.pathname(urlObj)
  let parts = path->Js.String2.split("/")->Array.keep(p => p !== "")

  if Array.length(parts) >= 2 {
    let idStr = Array.getUnsafe(parts, 1)
    switch Int.fromString(idStr) {
    | None => Deno.Response.json(
        Js.Json.object_(Js.Dict.fromArray([
          ("error", Js.Json.string("Invalid ID"))
        ])),
        ~status=400,
        ()
      )
    | Some(id) => {
        switch Database.findById(db, "products", id) {
        | None => Deno.Response.json(
            Js.Json.object_(Js.Dict.fromArray([
              ("error", Js.Json.string("Product not found"))
            ])),
            ~status=404,
            ()
          )
        | Some(product) => Deno.Response.json(Js.Json.object_(product), ())
        }
      }
    }
  } else {
    Deno.Response.json(
      Js.Json.object_(Js.Dict.fromArray([
        ("error", Js.Json.string("ID required"))
      ])),
      ~status=400,
      ()
    )
  }
}

let handleCreateProduct = async (req: Deno.request): promise<Deno.response> => {
  try {
    let body = await Deno.Request.json(req)

    switch Js.Json.decodeObject(body) {
    | None => Deno.Response.json(
        Js.Json.object_(Js.Dict.fromArray([
          ("error", Js.Json.string("Invalid JSON"))
        ])),
        ~status=400,
        ()
      )
    | Some(data) => {
        switch Database.insert(db, "products", data) {
        | None => Deno.Response.json(
            Js.Json.object_(Js.Dict.fromArray([
              ("error", Js.Json.string("Failed to create product"))
            ])),
            ~status=500,
            ()
          )
        | Some(id) => {
            Js.Dict.set(data, "id", Js.Json.number(Int.toFloat(id)))
            Deno.Response.json(Js.Json.object_(data), ~status=201, ())
          }
        }
      }
    }
  } catch {
  | _ => Deno.Response.json(
      Js.Json.object_(Js.Dict.fromArray([
        ("error", Js.Json.string("Invalid request"))
      ])),
      ~status=400,
      ()
    )
  }
}

let handleUpdateProduct = async (req: Deno.request): promise<Deno.response> => {
  let url = Deno.Request.url(req)
  let urlObj = Deno.Url.make(url)
  let path = Deno.Url.pathname(urlObj)
  let parts = path->Js.String2.split("/")->Array.keep(p => p !== "")

  if Array.length(parts) >= 2 {
    let idStr = Array.getUnsafe(parts, 1)
    switch Int.fromString(idStr) {
    | None => Deno.Response.json(
        Js.Json.object_(Js.Dict.fromArray([
          ("error", Js.Json.string("Invalid ID"))
        ])),
        ~status=400,
        ()
      )
    | Some(id) => {
        try {
          let body = await Deno.Request.json(req)

          switch Js.Json.decodeObject(body) {
          | None => Deno.Response.json(
              Js.Json.object_(Js.Dict.fromArray([
                ("error", Js.Json.string("Invalid JSON"))
              ])),
              ~status=400,
              ()
            )
          | Some(data) => {
              let updated = Database.update(db, "products", id, data)

              if updated {
                switch Database.findById(db, "products", id) {
                | None => Deno.Response.json(
                    Js.Json.object_(Js.Dict.fromArray([
                      ("error", Js.Json.string("Product not found after update"))
                    ])),
                    ~status=500,
                    ()
                  )
                | Some(product) => Deno.Response.json(Js.Json.object_(product), ())
                }
              } else {
                Deno.Response.json(
                  Js.Json.object_(Js.Dict.fromArray([
                    ("error", Js.Json.string("Product not found"))
                  ])),
                  ~status=404,
                  ()
                )
              }
            }
          }
        } catch {
        | _ => Deno.Response.json(
            Js.Json.object_(Js.Dict.fromArray([
              ("error", Js.Json.string("Invalid request"))
            ])),
            ~status=400,
            ()
          )
        }
      }
    }
  } else {
    Deno.Response.json(
      Js.Json.object_(Js.Dict.fromArray([
        ("error", Js.Json.string("ID required"))
      ])),
      ~status=400,
      ()
    )
  }
}

let handleDeleteProduct = async (req: Deno.request): promise<Deno.response> => {
  let url = Deno.Request.url(req)
  let urlObj = Deno.Url.make(url)
  let path = Deno.Url.pathname(urlObj)
  let parts = path->Js.String2.split("/")->Array.keep(p => p !== "")

  if Array.length(parts) >= 2 {
    let idStr = Array.getUnsafe(parts, 1)
    switch Int.fromString(idStr) {
    | None => Deno.Response.json(
        Js.Json.object_(Js.Dict.fromArray([
          ("error", Js.Json.string("Invalid ID"))
        ])),
        ~status=400,
        ()
      )
    | Some(id) => {
        let deleted = Database.delete(db, "products", id)

        if deleted {
          Deno.Response.json(
            Js.Json.object_(Js.Dict.fromArray([
              ("message", Js.Json.string("Product deleted"))
            ])),
            ()
          )
        } else {
          Deno.Response.json(
            Js.Json.object_(Js.Dict.fromArray([
              ("error", Js.Json.string("Product not found"))
            ])),
            ~status=404,
            ()
          )
        }
      }
    }
  } else {
    Deno.Response.json(
      Js.Json.object_(Js.Dict.fromArray([
        ("error", Js.Json.string("ID required"))
      ])),
      ~status=400,
      ()
    )
  }
}

let router = Router.make()
  ->Router.use(Middleware.logger())
  ->Router.use(Middleware.cors())
  ->Router.get("/products", handleListProducts)
  ->Router.get("/products/:id", handleGetProduct)
  ->Router.post("/products", handleCreateProduct)
  ->Router.put("/products/:id", handleUpdateProduct)
  ->Router.del("/products/:id", handleDeleteProduct)
  ->Router.get("/", async _req => {
    Deno.Response.json(
      Js.Json.object_(Js.Dict.fromArray([
        ("message", Js.Json.string("Product Database API")),
        ("endpoints", Js.Json.array([
          Js.Json.string("GET /products"),
          Js.Json.string("GET /products/:id"),
          Js.Json.string("POST /products"),
          Js.Json.string("PUT /products/:id"),
          Js.Json.string("DELETE /products/:id")
        ]))
      ])),
      ()
    )
  })

Server.withRouter(~port=8000, router)
