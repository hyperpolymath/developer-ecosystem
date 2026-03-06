module U64 = {
  type t
  @new external make: int => t = "Float64Array"
  @get external length: t => int = "length"
  @get external buffer: t => Js.Typed_array.ArrayBuffer.t = "buffer"
  @get_index external get: (t, int) => float = ""
  @set_index external set: (t, int, float) => unit = ""
}
