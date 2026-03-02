// Authentication microservice example

type user = {
  id: int,
  username: string,
  email: string,
  passwordHash: string,
  createdAt: float
}

let users: ref<array<user>> = ref([])
let nextUserId = ref(1)

// Simple hash function (use proper crypto in production!)
let hashPassword = (password: string): string => {
  `hashed_${password}`
}

// Register endpoint
let register = async (req: Deno.request): promise<Deno.response> => {
  try {
    let body = await Deno.Request.json(req)

    let (username, email, password) = switch Js.Json.decodeObject(body) {
    | None => (None, None, None)
    | Some(obj) => {
        let username = Js.Dict.get(obj, "username")->Option.flatMap(Js.Json.decodeString)
        let email = Js.Dict.get(obj, "email")->Option.flatMap(Js.Json.decodeString)
        let password = Js.Dict.get(obj, "password")->Option.flatMap(Js.Json.decodeString)
        (username, email, password)
      }
    }

    switch (username, email, password) {
    | (Some(u), Some(e), Some(p)) => {
        // Check if user exists
        let exists = users.contents->Array.some(user => user.username === u || user.email === e)

        if exists {
          Promise.resolve(Deno.Response.json(
            Js.Json.object_(Js.Dict.fromArray([
              ("error", Js.Json.string("User already exists"))
            ])),
            ~status=400,
            ()
          ))
        } else {
          let newUser: user = {
            id: nextUserId.contents,
            username: u,
            email: e,
            passwordHash: hashPassword(p),
            createdAt: Deno.now()
          }

          nextUserId := nextUserId.contents + 1
          users := Array.concat(users.contents, [newUser])

          Promise.resolve(Deno.Response.json(
            Js.Json.object_(Js.Dict.fromArray([
              ("id", Js.Json.number(Int.toFloat(newUser.id))),
              ("username", Js.Json.string(newUser.username)),
              ("email", Js.Json.string(newUser.email)),
              ("token", Js.Json.string(`fake_jwt_token_${Int.toString(newUser.id)}`))
            ])),
            ~status=201,
            ()
          ))
        }
      }
    | _ => {
        Promise.resolve(Deno.Response.json(
          Js.Json.object_(Js.Dict.fromArray([
            ("error", Js.Json.string("Missing required fields"))
          ])),
          ~status=400,
          ()
        ))
      }
    }
  } catch {
  | _ => {
      Promise.resolve(Deno.Response.json(
        Js.Json.object_(Js.Dict.fromArray([
          ("error", Js.Json.string("Invalid request"))
        ])),
        ~status=400,
        ()
      ))
    }
  }
}

// Login endpoint
let login = async (req: Deno.request): promise<Deno.response> => {
  try {
    let body = await Deno.Request.json(req)

    let (username, password) = switch Js.Json.decodeObject(body) {
    | None => (None, None)
    | Some(obj) => {
        let username = Js.Dict.get(obj, "username")->Option.flatMap(Js.Json.decodeString)
        let password = Js.Dict.get(obj, "password")->Option.flatMap(Js.Json.decodeString)
        (username, password)
      }
    }

    switch (username, password) {
    | (Some(u), Some(p)) => {
        let user = users.contents->Array.find(user =>
          user.username === u && user.passwordHash === hashPassword(p)
        )

        switch user {
        | Some(foundUser) => {
            Promise.resolve(Deno.Response.json(
              Js.Json.object_(Js.Dict.fromArray([
                ("id", Js.Json.number(Int.toFloat(foundUser.id))),
                ("username", Js.Json.string(foundUser.username)),
                ("token", Js.Json.string(`fake_jwt_token_${Int.toString(foundUser.id)}`))
              ])),
              ()
            ))
          }
        | None => {
            Promise.resolve(Deno.Response.json(
              Js.Json.object_(Js.Dict.fromArray([
                ("error", Js.Json.string("Invalid credentials"))
              ])),
              ~status=401,
              ()
            ))
          }
        }
      }
    | _ => {
        Promise.resolve(Deno.Response.json(
          Js.Json.object_(Js.Dict.fromArray([
            ("error", Js.Json.string("Missing credentials"))
          ])),
          ~status=400,
          ()
        ))
      }
    }
  } catch {
  | _ => {
      Promise.resolve(Deno.Response.json(
        Js.Json.object_(Js.Dict.fromArray([
          ("error", Js.Json.string("Invalid request"))
        ])),
        ~status=400,
        ()
      ))
    }
  }
}

let router = Router.make()
  ->Router.use(Middleware.logger())
  ->Router.use(Middleware.cors())
  ->Router.post("/register", register)
  ->Router.post("/login", login)
  ->Router.get("/", async _req => {
    Deno.Response.json(
      Js.Json.object_(Js.Dict.fromArray([
        ("service", Js.Json.string("auth-service")),
        ("version", Js.Json.string("1.0.0"))
      ])),
      ()
    )
  })

Server.withRouter(~port=8001, router)
