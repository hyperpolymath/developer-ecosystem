(* SPDX-License-Identifier: PMPL-1.0-or-later *)
(* PPX transformer for return sugar syntax *)
(* Transforms %return.X(...) into standard ReScript control flow *)

open Ppxlib

let name = "return_sugar"

(* Helper to build if-else expression *)
let build_if ~loc condition then_expr else_expr =
  [%expr if [%e condition] then [%e then_expr] else [%e else_expr]]

(* Helper to build switch/pattern match *)
let build_switch ~loc expr error_case ok_case =
  let error_pattern = [%pat? Error e] in
  let ok_pattern = [%pat? Ok v] in
  [%expr
    match [%e expr] with
    | [%p error_pattern] -> [%e error_case]
    | [%p ok_pattern] -> [%e ok_case]
  ]

(* Transform %return.if(condition, value) *)
let expand_return_if ~ctxt condition value rest =
  let loc = Expansion_context.Extension.extension_point_loc ctxt in
  build_if ~loc condition value rest

(* Transform %return.error(result) *)
let expand_return_error ~ctxt result_expr rest =
  let loc = Expansion_context.Extension.extension_point_loc ctxt in
  let error_case = [%expr Error e] in
  build_switch ~loc result_expr error_case rest

(* Transform %return.none(option) *)
let expand_return_none ~ctxt option_expr rest =
  let loc = Expansion_context.Extension.extension_point_loc ctxt in
  let none_case = [%expr None] in
  let some_pattern = [%pat? Some v] in
  [%expr
    match [%e option_expr] with
    | None -> [%e none_case]
    | [%p some_pattern] -> [%e rest]
  ]

(* Main expression traversal *)
let rec transform_expr expr =
  match expr.pexp_desc with
  | Pexp_extension ({ txt = "return.if"; _ }, payload) ->
      (* Extract condition and value from payload *)
      (* TODO: Parse payload properly *)
      expr
  | Pexp_extension ({ txt = "return.error"; _ }, payload) ->
      (* Extract result expression from payload *)
      (* TODO: Parse payload properly *)
      expr
  | Pexp_extension ({ txt = "return.none"; _ }, payload) ->
      (* Extract option expression from payload *)
      (* TODO: Parse payload properly *)
      expr
  | _ -> expr

(* Expression mapper *)
let expr_mapper =
  object
    inherit Ast_traverse.map as super

    method! expression expr =
      let expr = super#expression expr in
      transform_expr expr
  end

(* Structure mapper *)
let structure_mapper =
  object
    inherit [Driver.Lint_error.t list] Ast_traverse.fold_map as super

    method! structure structure =
      let structure = super#structure structure in
      structure
  end

(* Register the PPX *)
let () =
  Driver.register_transformation
    ~extensions:[]
    name
