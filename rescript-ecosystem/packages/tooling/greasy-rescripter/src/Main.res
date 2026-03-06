// src/Main.res
@val external window: 'a = "window"

let greet = (name: string) => {
  Js.log("Greasy-Rescripter: Initialising logic for " ++ name)
}

let init = () => {
  greet("Browser Environment")
  // Functional logic goes here
}

init()
