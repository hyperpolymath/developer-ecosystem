// Dependency graph for WASM module loading

type node = {
  id: string,
  name: string,
  dependencies: Belt.Set.String.t,
}

type t = {
  nodes: Js.Dict.t<node>,
  order: array<string>,
}

@ocaml.doc("Create a new dependency graph")
let make = (): t => {
  nodes: Js.Dict.empty(),
  order: [],
}

@ocaml.doc("Add a node to the graph")
let addNode = (graph: t, id: string, ~name: option<string>=?, ()): unit => {
  let nodeName = switch name {
  | Some(n) => n
  | None => id
  }
  
  switch Js.Dict.get(graph.nodes, id) {
  | Some(_) => ()
  | None =>
    Js.Dict.set(
      graph.nodes,
      id,
      {
        id: id,
        name: nodeName,
        dependencies: Belt.Set.String.empty,
      },
    )
  }
}

@ocaml.doc("Add a dependency between two nodes")
let addDependency = (graph: t, fromId: string, toId: string): unit => {
  switch Js.Dict.get(graph.nodes, fromId) {
  | Some(node) => {
      let newDeps = Belt.Set.String.add(node.dependencies, toId)
      Js.Dict.set(graph.nodes, fromId, {...node, dependencies: newDeps})
    }
  | None => ()
  }
}

@ocaml.doc("Topological sort of the graph")
let resolveOrder = (graph: t): array<string> => {
  let visited = ref(Belt.Set.String.empty)
  let order = []
  let nodes = Js.Dict.values(graph.nodes)

  let rec visit = (nodeId: string) => {
    if Belt.Set.String.has(visited.contents, nodeId) {
      ()
    } else {
      let node = Js.Dict.unsafeGet(graph.nodes, nodeId)
      visited := Belt.Set.String.add(visited.contents, nodeId)
      Belt.Set.String.forEach(node.dependencies, dep => {
        visit(dep)
      })
      let _ = Js.Array.push(nodeId, order)
    }
  }

  Belt.Array.forEach(nodes, node => {
    visit(node.id)
  })

  order
}
