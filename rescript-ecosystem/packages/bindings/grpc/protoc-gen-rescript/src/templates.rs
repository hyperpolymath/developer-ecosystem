// SPDX-License-Identifier: MPL-2.0
//! ReScript code templates for generated output

/// Information about a message field
#[derive(Debug, Clone)]
pub struct FieldInfo {
    pub name: String,
    pub proto_name: String,
    pub number: i32,
    pub rescript_type: String,
    pub is_optional: bool,
    pub is_repeated: bool,
    pub is_message: bool,
    pub is_enum: bool,
    pub oneof_index: Option<i32>,
    /// Well-known type name if applicable (e.g., ".google.protobuf.Timestamp")
    pub well_known_type: Option<String>,
}

/// Information about a oneof field group
#[derive(Debug, Clone)]
pub struct OneOfInfo {
    pub name: String,
    pub rescript_name: String,
    pub fields: Vec<FieldInfo>,
}

impl FieldInfo {
    /// Get the full ReScript type including option/array wrappers
    pub fn full_type(&self) -> String {
        let base = &self.rescript_type;
        if self.is_repeated {
            format!("array<{}>", base)
        } else if self.is_optional {
            format!("option<{}>", base)
        } else {
            base.clone()
        }
    }

    /// Get the JSON encoder for this field's base type
    pub fn json_encoder(&self) -> String {
        // Check for well-known types first
        if let Some(ref wkt) = self.well_known_type {
            return self.wkt_json_encoder(wkt);
        }

        if self.is_message {
            format!("{}.toJson", self.rescript_type.trim_end_matches(".t"))
        } else if self.is_enum {
            // For enums, we need a lambda that converts then encodes
            let enum_name = self.rescript_type.trim_end_matches(".t");
            format!("v => Json.Encode.int({}.toInt(v))", enum_name)
        } else {
            match self.rescript_type.as_str() {
                "string" => "Json.Encode.string".to_string(),
                "int" => "Json.Encode.int".to_string(),
                "float" => "Json.Encode.float".to_string(),
                "bool" => "Json.Encode.bool".to_string(),
                "bigint" => "Json.Encode.int64".to_string(),
                "Js.Typed_array.Uint8Array.t" => "Json.Encode.bytes".to_string(),
                _ => "Json.Encode.string".to_string(),
            }
        }
    }

    /// Get the JSON decoder for this field's base type
    pub fn json_decoder(&self) -> String {
        // Check for well-known types first
        if let Some(ref wkt) = self.well_known_type {
            return self.wkt_json_decoder(wkt);
        }

        if self.is_message {
            format!("{}.fromJson", self.rescript_type.trim_end_matches(".t"))
        } else if self.is_enum {
            let enum_name = self.rescript_type.trim_end_matches(".t");
            format!("json => Json.Decode.int(json)->Option.flatMap({}.fromInt)", enum_name)
        } else {
            match self.rescript_type.as_str() {
                "string" => "Json.Decode.string".to_string(),
                "int" => "Json.Decode.int".to_string(),
                "float" => "Json.Decode.float".to_string(),
                "bool" => "Json.Decode.bool".to_string(),
                "bigint" => "Json.Decode.int64".to_string(),
                "Js.Typed_array.Uint8Array.t" => "Json.Decode.bytes".to_string(),
                _ => "Json.Decode.string".to_string(),
            }
        }
    }

    /// Get JSON encoder for well-known types
    fn wkt_json_encoder(&self, wkt: &str) -> String {
        match wkt {
            // Timestamp -> RFC3339 string
            ".google.protobuf.Timestamp" => "WellKnown.Timestamp.toJson".to_string(),
            // Duration -> "Xs" format
            ".google.protobuf.Duration" => "WellKnown.Duration.toJson".to_string(),
            // Empty -> {}
            ".google.protobuf.Empty" => "_ => Js.Json.object_(Js.Dict.empty())".to_string(),
            // Wrapper types -> just encode the wrapped value
            ".google.protobuf.DoubleValue" | ".google.protobuf.FloatValue" => {
                "Json.Encode.float".to_string()
            }
            ".google.protobuf.Int64Value"
            | ".google.protobuf.UInt64Value"
            | ".google.protobuf.SInt64Value" => "Json.Encode.int64".to_string(),
            ".google.protobuf.Int32Value"
            | ".google.protobuf.UInt32Value"
            | ".google.protobuf.SInt32Value" => "Json.Encode.int".to_string(),
            ".google.protobuf.BoolValue" => "Json.Encode.bool".to_string(),
            ".google.protobuf.StringValue" => "Json.Encode.string".to_string(),
            ".google.protobuf.BytesValue" => "Json.Encode.bytes".to_string(),
            // Struct types -> pass through as JSON
            ".google.protobuf.Struct" => "WellKnown.Struct.toJson".to_string(),
            ".google.protobuf.Value" => "v => v".to_string(),
            ".google.protobuf.ListValue" => "Js.Json.array".to_string(),
            ".google.protobuf.NullValue" => "_ => Js.Json.null".to_string(),
            // Any -> special encoding
            ".google.protobuf.Any" => "WellKnown.Any.toJson".to_string(),
            _ => "Json.Encode.string".to_string(),
        }
    }

    /// Get JSON decoder for well-known types
    fn wkt_json_decoder(&self, wkt: &str) -> String {
        match wkt {
            // Timestamp -> parse RFC3339 string
            ".google.protobuf.Timestamp" => "WellKnown.Timestamp.fromJson".to_string(),
            // Duration -> parse "Xs" format
            ".google.protobuf.Duration" => "WellKnown.Duration.fromJson".to_string(),
            // Empty -> always unit
            ".google.protobuf.Empty" => "_ => Some(())".to_string(),
            // Wrapper types -> decode as the wrapped type
            ".google.protobuf.DoubleValue" | ".google.protobuf.FloatValue" => {
                "Json.Decode.float".to_string()
            }
            ".google.protobuf.Int64Value"
            | ".google.protobuf.UInt64Value"
            | ".google.protobuf.SInt64Value" => "Json.Decode.int64".to_string(),
            ".google.protobuf.Int32Value"
            | ".google.protobuf.UInt32Value"
            | ".google.protobuf.SInt32Value" => "Json.Decode.int".to_string(),
            ".google.protobuf.BoolValue" => "Json.Decode.bool".to_string(),
            ".google.protobuf.StringValue" => "Json.Decode.string".to_string(),
            ".google.protobuf.BytesValue" => "Json.Decode.bytes".to_string(),
            // Struct types -> pass through
            ".google.protobuf.Struct" => "WellKnown.Struct.fromJson".to_string(),
            ".google.protobuf.Value" => "json => Some(json)".to_string(),
            ".google.protobuf.ListValue" => "Json.Decode.array(v => Some(v))".to_string(),
            ".google.protobuf.NullValue" => "_ => Some(Js.Null.empty)".to_string(),
            // Any -> special decoding
            ".google.protobuf.Any" => "WellKnown.Any.fromJson".to_string(),
            _ => "Json.Decode.string".to_string(),
        }
    }
}

/// Template for generating a ReScript module from a proto file
pub struct ModuleTemplate {
    pub package: String,
    pub source_file: String,
    pub modules: Vec<String>,
    pub use_wasm: bool,
}

impl ModuleTemplate {
    pub fn render(&self) -> String {
        let mut out = String::new();

        // Header comment
        out.push_str(&format!(
            "// Generated from {} by protoc-gen-rescript\n",
            self.source_file
        ));
        out.push_str("// SPDX-License-Identifier: MPL-2.0\n");
        out.push_str("// DO NOT EDIT - regenerate from .proto source\n\n");

        if !self.package.is_empty() {
            out.push_str(&format!("// Package: {}\n\n", self.package));
        }

        // WASM codec import if enabled
        if self.use_wasm {
            out.push_str("// WASM codec for encode/decode\n");
            out.push_str("@module(\"./proto_codec.wasm\")\n");
            out.push_str("external wasmCodec: Wasm.Instance.t = \"default\"\n\n");
        }

        // Render all modules (enums + messages)
        for module in &self.modules {
            out.push_str(module);
            out.push_str("\n\n");
        }

        out
    }
}

/// Template for generating a ReScript enum from proto enum
pub struct EnumTemplate {
    pub name: String,
    pub variants: Vec<(String, i32)>,
}

impl EnumTemplate {
    pub fn render(&self) -> String {
        let mut out = String::new();

        out.push_str(&format!("module {} = {{\n", self.name));

        // Polymorphic variant type
        out.push_str("  type t = [\n");
        for (variant, _) in &self.variants {
            out.push_str(&format!("    | #{}\n", variant));
        }
        out.push_str("  ]\n\n");

        // To int conversion
        out.push_str("  let toInt = (v: t): int => {\n");
        out.push_str("    switch v {\n");
        for (variant, number) in &self.variants {
            out.push_str(&format!("    | #{} => {}\n", variant, number));
        }
        out.push_str("    }\n");
        out.push_str("  }\n\n");

        // From int conversion
        out.push_str("  let fromInt = (i: int): option<t> => {\n");
        out.push_str("    switch i {\n");
        for (variant, number) in &self.variants {
            out.push_str(&format!("    | {} => Some(#{})\n", number, variant));
        }
        out.push_str("    | _ => None\n");
        out.push_str("    }\n");
        out.push_str("  }\n");

        out.push_str("}\n");

        out
    }
}

/// Template for generating a ReScript message module
pub struct MessageTemplate {
    pub name: String,
    pub fields: Vec<FieldInfo>,
    pub oneofs: Vec<OneOfInfo>,
    pub nested: Vec<String>,
    pub use_wasm: bool,
}

impl MessageTemplate {
    /// Get fields that are NOT part of any real oneof
    /// (proto3_optional fields have oneof_index but should be treated as regular fields)
    fn regular_fields(&self) -> Vec<&FieldInfo> {
        // Get all oneof indices that are "real" oneofs (not synthetic proto3_optional)
        let real_oneof_indices: std::collections::HashSet<i32> = self.oneofs
            .iter()
            .flat_map(|o| o.fields.iter().filter_map(|f| f.oneof_index))
            .collect();

        self.fields
            .iter()
            .filter(|f| match f.oneof_index {
                None => true,
                Some(idx) => !real_oneof_indices.contains(&idx),
            })
            .collect()
    }

    pub fn render(&self) -> String {
        let mut out = String::new();

        out.push_str(&format!("module {} = {{\n", self.name));

        // Nested types first
        for nested in &self.nested {
            // Indent nested content
            for line in nested.lines() {
                out.push_str(&format!("  {}\n", line));
            }
            out.push('\n');
        }

        // Generate oneof variant types (use lowercase for type name in ReScript)
        for oneof in &self.oneofs {
            out.push_str(&format!("  type {} =\n", oneof.name));
            for field in &oneof.fields {
                // Variant with payload
                out.push_str(&format!(
                    "    | {}({})\n",
                    capitalize_first(&field.name),
                    field.rescript_type
                ));
            }
            out.push('\n');
        }

        // Record type - exclude oneof fields from regular fields, add oneof as option
        out.push_str("  type t = {\n");
        for field in self.regular_fields() {
            out.push_str(&format!(
                "    {}: {},\n",
                field.name,
                field.full_type()
            ));
        }
        // Add oneof fields as option<oneofType>
        for oneof in &self.oneofs {
            out.push_str(&format!(
                "    {}: option<{}>,\n",
                oneof.name, oneof.name
            ));
        }
        out.push_str("  }\n\n");

        // Default value constructor
        out.push_str("  let make = (\n");
        let regular_fields = self.regular_fields();
        let total_params = regular_fields.len() + self.oneofs.len();

        for (i, field) in regular_fields.iter().enumerate() {
            let suffix = if i == total_params - 1 { "" } else { "," };

            if field.is_optional {
                out.push_str(&format!("    ~{}=?{}\n", field.name, suffix));
            } else if field.is_repeated {
                out.push_str(&format!("    ~{}=[]{}\n", field.name, suffix));
            } else {
                out.push_str(&format!("    ~{}{}\n", field.name, suffix));
            }
        }
        // Add oneof parameters (always optional)
        for (i, oneof) in self.oneofs.iter().enumerate() {
            let suffix = if regular_fields.len() + i == total_params - 1 { "" } else { "," };
            out.push_str(&format!("    ~{}=?{}\n", oneof.name, suffix));
        }
        out.push_str("  ): t => {\n");
        for field in &regular_fields {
            out.push_str(&format!("    {},\n", field.name));
        }
        for oneof in &self.oneofs {
            out.push_str(&format!("    {},\n", oneof.name));
        }
        out.push_str("  }\n");

        // JSON codec functions
        out.push_str(&self.render_json_codec());

        // WASM encode/decode stubs if enabled
        if self.use_wasm {
            out.push_str(&self.render_wasm_codec());
        }

        out.push_str("}\n");

        out
    }

    fn render_json_codec(&self) -> String {
        let mut out = String::new();
        let regular_fields = self.regular_fields();

        // toJson function
        out.push_str("\n  // JSON serialization\n");
        out.push_str("  let toJson = (msg: t): Js.Json.t => {\n");

        // Generate oneof encoder helpers inline (returns array<(string, Js.Json.t)>)
        for oneof in &self.oneofs {
            out.push_str(&format!(
                "    let {}Fields: array<(string, Js.Json.t)> = switch msg.{} {{\n",
                oneof.name, oneof.name
            ));
            out.push_str("    | None => []\n");
            for field in &oneof.fields {
                out.push_str(&format!(
                    "    | Some({}(v)) => [(\"{}\", {}(v))]\n",
                    capitalize_first(&field.name),
                    field.proto_name,
                    field.json_encoder()
                ));
            }
            out.push_str("    }\n");
        }

        out.push_str("    Json.Encode.object(Json.Encode.fields(\n");
        out.push_str("      [\n");

        // Required fields (excluding oneof fields)
        for field in &regular_fields {
            if !field.is_optional && !field.is_repeated {
                out.push_str(&format!(
                    "        Json.Encode.required(\"{}\", msg.{}, {}),\n",
                    field.proto_name,
                    field.name,
                    field.json_encoder()
                ));
            }
        }

        out.push_str("      ],\n");
        out.push_str("      [\n");

        // Optional and repeated fields (excluding oneof fields)
        for field in &regular_fields {
            if field.is_optional {
                out.push_str(&format!(
                    "        Json.Encode.optional(\"{}\", msg.{}, {}),\n",
                    field.proto_name,
                    field.name,
                    field.json_encoder()
                ));
            } else if field.is_repeated {
                out.push_str(&format!(
                    "        Json.Encode.repeated(\"{}\", msg.{}, {}),\n",
                    field.proto_name,
                    field.name,
                    field.json_encoder()
                ));
            }
        }

        // Add oneof fields (each is array<(string, Js.Json.t)>, matching optional field format)
        for oneof in &self.oneofs {
            out.push_str(&format!("        {}Fields,\n", oneof.name));
        }

        out.push_str("      ],\n");
        out.push_str("    ))\n");
        out.push_str("  }\n\n");

        // fromJson function
        out.push_str("  // JSON deserialization\n");
        out.push_str("  let fromJson = (json: Js.Json.t): option<t> => {\n");
        out.push_str("    switch Json.Decode.object(json) {\n");
        out.push_str("    | Some(obj) =>\n");

        // Build decode lines for regular fields
        let mut decode_lines = Vec::new();
        for field in &regular_fields {
            if field.is_repeated {
                decode_lines.push(format!(
                    "        let {} = Json.Decode.repeated(obj, \"{}\", {})->Result.getOr([])",
                    field.name, field.proto_name, field.json_decoder()
                ));
            } else if field.is_optional {
                decode_lines.push(format!(
                    "        let {} = Json.Decode.optional(obj, \"{}\", {})->Result.getOr(None)",
                    field.name, field.proto_name, field.json_decoder()
                ));
            } else {
                decode_lines.push(format!(
                    "        let {} = Json.Decode.required(obj, \"{}\", {})",
                    field.name, field.proto_name, field.json_decoder()
                ));
            }
        }

        for line in &decode_lines {
            out.push_str(line);
            out.push('\n');
        }

        // Decode oneof fields - try each field in order, first match wins
        for oneof in &self.oneofs {
            out.push_str(&format!("        let {} = {{\n", oneof.name));
            let field_count = oneof.fields.len();
            for (i, field) in oneof.fields.iter().enumerate() {
                let is_last = i == field_count - 1;
                if i == 0 {
                    out.push_str(&format!(
                        "          switch Json.Decode.optional(obj, \"{}\", {}) {{\n",
                        field.proto_name, field.json_decoder()
                    ));
                } else {
                    out.push_str(&format!(
                        "          | Ok(None) =>\n            switch Json.Decode.optional(obj, \"{}\", {}) {{\n",
                        field.proto_name, field.json_decoder()
                    ));
                }
                out.push_str(&format!(
                    "            | Ok(Some(v)) => Some({}(v))\n",
                    capitalize_first(&field.name)
                ));
                out.push_str("            | Error(_) => None\n");
                if is_last {
                    out.push_str("            | Ok(None) => None\n");
                }
            }
            // Close all the nested switches
            for _ in 0..field_count {
                out.push_str("            }\n");
            }
            out.push_str("        }\n");
        }

        // Check required fields and build result
        let required_fields_check: Vec<_> = regular_fields.iter()
            .filter(|f| !f.is_optional && !f.is_repeated)
            .collect();

        if required_fields_check.is_empty() {
            out.push_str("        Some({\n");
            for field in &regular_fields {
                out.push_str(&format!("          {},\n", field.name));
            }
            for oneof in &self.oneofs {
                out.push_str(&format!("          {},\n", oneof.name));
            }
            out.push_str("        })\n");
        } else {
            // Check all required fields are Ok
            out.push_str("        switch (");
            for (i, field) in required_fields_check.iter().enumerate() {
                if i > 0 {
                    out.push_str(", ");
                }
                out.push_str(&field.name);
            }
            out.push_str(") {\n");
            out.push_str("        | (");
            for (i, field) in required_fields_check.iter().enumerate() {
                if i > 0 {
                    out.push_str(", ");
                }
                out.push_str(&format!("Ok({})", field.name));
            }
            out.push_str(") =>\n");
            out.push_str("          Some({\n");
            for field in &regular_fields {
                out.push_str(&format!("            {},\n", field.name));
            }
            for oneof in &self.oneofs {
                out.push_str(&format!("            {},\n", oneof.name));
            }
            out.push_str("          })\n");
            out.push_str("        | _ => None\n");
            out.push_str("        }\n");
        }

        out.push_str("    | None => None\n");
        out.push_str("    }\n");
        out.push_str("  }\n");

        out
    }

    fn render_wasm_codec(&self) -> String {
        let mut out = String::new();
        let lower_name = self.name.to_lowercase();

        out.push_str("\n  // WASM codec functions\n");

        // Encode function
        out.push_str(&format!(
            "  let encode = async (msg: t): Js.Typed_array.Uint8Array.t => {{\n"
        ));
        out.push_str("    let exports = Wasm.Instance.exports(wasmCodec)\n");
        out.push_str("    let memory = %raw(`exports.memory`)\n");
        out.push_str("    let allocator = Wasm.Allocator.fromExports(exports)\n");
        out.push_str(&format!(
            "    let encodeFn: Wasm.Allocator.ptr => (Wasm.Allocator.ptr, int) = %raw(`exports.encode_{}`)\n",
            lower_name
        ));
        out.push_str("    // TODO: Serialize msg to memory, call encodeFn\n");
        out.push_str("    Js.Typed_array.Uint8Array.make([])\n");
        out.push_str("  }\n\n");

        // Decode function
        out.push_str(&format!(
            "  let decode = async (bytes: Js.Typed_array.Uint8Array.t): t => {{\n"
        ));
        out.push_str("    let exports = Wasm.Instance.exports(wasmCodec)\n");
        out.push_str("    let memory = %raw(`exports.memory`)\n");
        out.push_str("    let allocator = Wasm.Allocator.fromExports(exports)\n");
        out.push_str(&format!(
            "    let decodeFn: (Wasm.Allocator.ptr, int) => Wasm.Allocator.ptr = %raw(`exports.decode_{}`)\n",
            lower_name
        ));
        out.push_str("    // TODO: Copy bytes to memory, call decodeFn, deserialize result\n");
        out.push_str(&format!("    make(\n"));
        for field in &self.fields {
            if field.is_optional {
                out.push_str(&format!("      ~{}=None,\n", field.name));
            } else if field.is_repeated {
                out.push_str(&format!("      ~{}=[],\n", field.name));
            } else {
                // Default values for required fields
                let default = match field.rescript_type.as_str() {
                    "int" => "0",
                    "float" => "0.0",
                    "bool" => "false",
                    "string" => "\"\"",
                    _ => "Obj.magic(0)", // Placeholder for complex types
                };
                out.push_str(&format!("      ~{}={},\n", field.name, default));
            }
        }
        out.push_str("    )\n");
        out.push_str("  }\n");

        out
    }
}

/// Information about an RPC method
#[derive(Debug, Clone)]
pub struct MethodInfo {
    pub name: String,
    pub input_type: String,
    pub output_type: String,
    pub client_streaming: bool,
    pub server_streaming: bool,
}

/// Template for generating a gRPC-web service client
pub struct ServiceTemplate {
    pub name: String,
    pub methods: Vec<MethodInfo>,
}

impl ServiceTemplate {
    pub fn render(&self) -> String {
        let mut out = String::new();

        out.push_str(&format!("module {}Client = {{\n", self.name));

        // Client configuration type
        out.push_str("  // gRPC-web client configuration\n");
        out.push_str("  type config = {\n");
        out.push_str("    baseUrl: string,\n");
        out.push_str("    headers: option<Js.Dict.t<string>>,\n");
        out.push_str("  }\n\n");

        // Default config
        out.push_str("  let defaultConfig = {\n");
        out.push_str("    baseUrl: \"http://localhost:8080\",\n");
        out.push_str("    headers: None,\n");
        out.push_str("  }\n\n");

        // Error type
        out.push_str("  type error =\n");
        out.push_str("    | NetworkError(string)\n");
        out.push_str("    | GrpcError(int, string)\n");
        out.push_str("    | DecodeError(string)\n\n");

        // Helper function for making requests
        out.push_str("  // Internal fetch helper\n");
        out.push_str("  let call = async (\n");
        out.push_str("    ~config: config,\n");
        out.push_str("    ~method: string,\n");
        out.push_str("    ~request: Js.Json.t,\n");
        out.push_str("  ): result<Js.Json.t, error> => {\n");
        out.push_str("    let url = `${config.baseUrl}/${method}`\n");
        out.push_str("    let headers = Js.Dict.fromArray([\n");
        out.push_str("      (\"Content-Type\", \"application/json\"),\n");
        out.push_str("      (\"Accept\", \"application/json\"),\n");
        out.push_str("    ])\n");
        out.push_str("    // Merge custom headers\n");
        out.push_str("    switch config.headers {\n");
        out.push_str("    | Some(h) => Js.Dict.entries(h)->Array.forEach(((k, v)) => Js.Dict.set(headers, k, v))\n");
        out.push_str("    | None => ()\n");
        out.push_str("    }\n\n");
        out.push_str("    try {\n");
        out.push_str("      let response = await Fetch.fetch(\n");
        out.push_str("        url,\n");
        out.push_str("        {\n");
        out.push_str("          method: #POST,\n");
        out.push_str("          headers: Fetch.Headers.fromDict(headers),\n");
        out.push_str("          body: Fetch.Body.string(Js.Json.stringify(request)),\n");
        out.push_str("        },\n");
        out.push_str("      )\n");
        out.push_str("      if Fetch.Response.ok(response) {\n");
        out.push_str("        let json = await Fetch.Response.json(response)\n");
        out.push_str("        Ok(json)\n");
        out.push_str("      } else {\n");
        out.push_str("        let status = Fetch.Response.status(response)\n");
        out.push_str("        let text = await Fetch.Response.text(response)\n");
        out.push_str("        Error(GrpcError(status, text))\n");
        out.push_str("      }\n");
        out.push_str("    } catch {\n");
        out.push_str("    | Exn.Error(exn) => Error(NetworkError(Exn.message(exn)->Option.getOr(\"Unknown error\")))\n");
        out.push_str("    | _ => Error(NetworkError(\"Unknown error\"))\n");
        out.push_str("    }\n");
        out.push_str("  }\n\n");

        // Stream callback type for server streaming
        out.push_str("  // Stream handler for server-streaming RPCs\n");
        out.push_str("  type streamHandler<'a> = {\n");
        out.push_str("    onMessage: 'a => unit,\n");
        out.push_str("    onError: error => unit,\n");
        out.push_str("    onComplete: unit => unit,\n");
        out.push_str("  }\n\n");

        // Stream cancellation type
        out.push_str("  // Cancellation handle for streaming RPCs\n");
        out.push_str("  type streamCancel = {\n");
        out.push_str("    cancel: unit => unit,\n");
        out.push_str("  }\n\n");

        // Streaming call helper (for server-streaming)
        out.push_str("  // Internal streaming helper for server-streaming RPCs\n");
        out.push_str("  let callStream = (\n");
        out.push_str("    ~config: config,\n");
        out.push_str("    ~method: string,\n");
        out.push_str("    ~request: Js.Json.t,\n");
        out.push_str("    ~handler: streamHandler<Js.Json.t>,\n");
        out.push_str("  ): streamCancel => {\n");
        out.push_str("    let cancelled = ref(false)\n");
        out.push_str("    let url = `${config.baseUrl}/${method}`\n");
        out.push_str("    let headers = Js.Dict.fromArray([\n");
        out.push_str("      (\"Content-Type\", \"application/json\"),\n");
        out.push_str("      (\"Accept\", \"application/x-ndjson\"),\n");
        out.push_str("    ])\n");
        out.push_str("    switch config.headers {\n");
        out.push_str("    | Some(h) => Js.Dict.entries(h)->Array.forEach(((k, v)) => Js.Dict.set(headers, k, v))\n");
        out.push_str("    | None => ()\n");
        out.push_str("    }\n\n");
        out.push_str("    // Start the streaming request\n");
        out.push_str("    let _ = Streaming.fetchNdjson(\n");
        out.push_str("      ~url,\n");
        out.push_str("      ~method=#POST,\n");
        out.push_str("      ~headers,\n");
        out.push_str("      ~body=Js.Json.stringify(request),\n");
        out.push_str("      ~onMessage=json => {\n");
        out.push_str("        if !cancelled.contents {\n");
        out.push_str("          handler.onMessage(json)\n");
        out.push_str("        }\n");
        out.push_str("      },\n");
        out.push_str("      ~onError=msg => {\n");
        out.push_str("        if !cancelled.contents {\n");
        out.push_str("          handler.onError(NetworkError(msg))\n");
        out.push_str("        }\n");
        out.push_str("      },\n");
        out.push_str("      ~onComplete=() => {\n");
        out.push_str("        if !cancelled.contents {\n");
        out.push_str("          handler.onComplete()\n");
        out.push_str("        }\n");
        out.push_str("      },\n");
        out.push_str("    )\n\n");
        out.push_str("    {cancel: () => cancelled := true}\n");
        out.push_str("  }\n\n");

        // Generate each RPC method
        for method in &self.methods {
            out.push_str(&self.render_method(method));
            out.push('\n');
        }

        out.push_str("}\n\n");

        // Generate the server module
        out.push_str(&self.render_server());

        out
    }

    fn render_method(&self, method: &MethodInfo) -> String {
        if method.server_streaming && !method.client_streaming {
            self.render_server_streaming_method(method)
        } else if method.client_streaming && !method.server_streaming {
            self.render_client_streaming_method(method)
        } else if method.client_streaming && method.server_streaming {
            self.render_bidi_streaming_method(method)
        } else {
            self.render_unary_method(method)
        }
    }

    fn render_unary_method(&self, method: &MethodInfo) -> String {
        let mut out = String::new();

        // Method documentation comment
        out.push_str(&format!("  // {} RPC (unary)\n", method.name));

        // Method signature
        out.push_str(&format!(
            "  let {} = async (\n",
            to_camel_case(&method.name)
        ));
        out.push_str("    ~config: config=defaultConfig,\n");
        out.push_str(&format!("    ~request: {}.t,\n", method.input_type));
        out.push_str(&format!("  ): result<{}.t, error> => {{\n", method.output_type));

        // Encode request
        out.push_str(&format!(
            "    let requestJson = {}.toJson(request)\n",
            method.input_type
        ));

        // Make the call
        let rpc_path = format!("{}/{}", self.name, method.name);
        out.push_str(&format!(
            "    let response = await call(~config, ~method=\"{}\", ~request=requestJson)\n",
            rpc_path
        ));

        // Decode response
        out.push_str("    switch response {\n");
        out.push_str("    | Ok(json) =>\n");
        out.push_str(&format!(
            "      switch {}.fromJson(json) {{\n",
            method.output_type
        ));
        out.push_str("      | Some(msg) => Ok(msg)\n");
        out.push_str("      | None => Error(DecodeError(\"Failed to decode response\"))\n");
        out.push_str("      }\n");
        out.push_str("    | Error(e) => Error(e)\n");
        out.push_str("    }\n");
        out.push_str("  }\n");

        out
    }

    fn render_server_streaming_method(&self, method: &MethodInfo) -> String {
        let mut out = String::new();

        // Method documentation comment
        out.push_str(&format!("  // {} RPC (server streaming)\n", method.name));

        // Method signature - takes a handler for stream events
        out.push_str(&format!(
            "  let {} = (\n",
            to_camel_case(&method.name)
        ));
        out.push_str("    ~config: config=defaultConfig,\n");
        out.push_str(&format!("    ~request: {}.t,\n", method.input_type));
        out.push_str(&format!("    ~handler: streamHandler<{}.t>,\n", method.output_type));
        out.push_str("  ): streamCancel => {\n");

        // Encode request
        out.push_str(&format!(
            "    let requestJson = {}.toJson(request)\n",
            method.input_type
        ));

        // Make the streaming call
        let rpc_path = format!("{}/{}", self.name, method.name);
        out.push_str(&format!(
            "    callStream(\n      ~config,\n      ~method=\"{}\",\n      ~request=requestJson,\n      ~handler={{\n",
            rpc_path
        ));
        out.push_str("        onMessage: json => {\n");
        out.push_str(&format!(
            "          switch {}.fromJson(json) {{\n",
            method.output_type
        ));
        out.push_str("          | Some(msg) => handler.onMessage(msg)\n");
        out.push_str("          | None => handler.onError(DecodeError(\"Failed to decode stream message\"))\n");
        out.push_str("          }\n");
        out.push_str("        },\n");
        out.push_str("        onError: handler.onError,\n");
        out.push_str("        onComplete: handler.onComplete,\n");
        out.push_str("      },\n");
        out.push_str("    )\n");
        out.push_str("  }\n");

        out
    }

    fn render_client_streaming_method(&self, method: &MethodInfo) -> String {
        let mut out = String::new();

        // Client streaming is limited in gRPC-web, but we can simulate with array
        out.push_str(&format!("  // {} RPC (client streaming - batch mode)\n", method.name));
        out.push_str(&format!(
            "  let {} = async (\n",
            to_camel_case(&method.name)
        ));
        out.push_str("    ~config: config=defaultConfig,\n");
        out.push_str(&format!("    ~requests: array<{}.t>,\n", method.input_type));
        out.push_str(&format!("  ): result<{}.t, error> => {{\n", method.output_type));

        // Encode all requests as array
        out.push_str(&format!(
            "    let requestsJson = Js.Json.array(Array.map(requests, {}.toJson))\n",
            method.input_type
        ));

        let rpc_path = format!("{}/{}", self.name, method.name);
        out.push_str(&format!(
            "    let response = await call(~config, ~method=\"{}\", ~request=requestsJson)\n",
            rpc_path
        ));

        out.push_str("    switch response {\n");
        out.push_str("    | Ok(json) =>\n");
        out.push_str(&format!(
            "      switch {}.fromJson(json) {{\n",
            method.output_type
        ));
        out.push_str("      | Some(msg) => Ok(msg)\n");
        out.push_str("      | None => Error(DecodeError(\"Failed to decode response\"))\n");
        out.push_str("      }\n");
        out.push_str("    | Error(e) => Error(e)\n");
        out.push_str("    }\n");
        out.push_str("  }\n");

        out
    }

    fn render_bidi_streaming_method(&self, method: &MethodInfo) -> String {
        let mut out = String::new();

        // Bidirectional streaming is very limited in gRPC-web
        // We simulate with batch request + streaming response
        out.push_str(&format!("  // {} RPC (bidirectional streaming - batch/stream mode)\n", method.name));
        out.push_str(&format!(
            "  let {} = (\n",
            to_camel_case(&method.name)
        ));
        out.push_str("    ~config: config=defaultConfig,\n");
        out.push_str(&format!("    ~requests: array<{}.t>,\n", method.input_type));
        out.push_str(&format!("    ~handler: streamHandler<{}.t>,\n", method.output_type));
        out.push_str("  ): streamCancel => {\n");

        out.push_str(&format!(
            "    let requestsJson = Js.Json.array(Array.map(requests, {}.toJson))\n",
            method.input_type
        ));

        let rpc_path = format!("{}/{}", self.name, method.name);
        out.push_str(&format!(
            "    callStream(\n      ~config,\n      ~method=\"{}\",\n      ~request=requestsJson,\n      ~handler={{\n",
            rpc_path
        ));
        out.push_str("        onMessage: json => {\n");
        out.push_str(&format!(
            "          switch {}.fromJson(json) {{\n",
            method.output_type
        ));
        out.push_str("          | Some(msg) => handler.onMessage(msg)\n");
        out.push_str("          | None => handler.onError(DecodeError(\"Failed to decode stream message\"))\n");
        out.push_str("          }\n");
        out.push_str("        },\n");
        out.push_str("        onError: handler.onError,\n");
        out.push_str("        onComplete: handler.onComplete,\n");
        out.push_str("      },\n");
        out.push_str("    )\n");
        out.push_str("  }\n");

        out
    }

    /// Render the server-side handler module
    pub fn render_server(&self) -> String {
        let mut out = String::new();

        out.push_str(&format!("module {}Server = {{\n", self.name));

        // Error type for server errors
        out.push_str("  // Server error types\n");
        out.push_str("  type grpcStatus =\n");
        out.push_str("    | Ok\n");
        out.push_str("    | Cancelled\n");
        out.push_str("    | Unknown\n");
        out.push_str("    | InvalidArgument\n");
        out.push_str("    | DeadlineExceeded\n");
        out.push_str("    | NotFound\n");
        out.push_str("    | AlreadyExists\n");
        out.push_str("    | PermissionDenied\n");
        out.push_str("    | ResourceExhausted\n");
        out.push_str("    | FailedPrecondition\n");
        out.push_str("    | Aborted\n");
        out.push_str("    | OutOfRange\n");
        out.push_str("    | Unimplemented\n");
        out.push_str("    | Internal\n");
        out.push_str("    | Unavailable\n");
        out.push_str("    | DataLoss\n");
        out.push_str("    | Unauthenticated\n\n");

        out.push_str("  let statusToCode = (status: grpcStatus): int => {\n");
        out.push_str("    switch status {\n");
        out.push_str("    | Ok => 0\n");
        out.push_str("    | Cancelled => 1\n");
        out.push_str("    | Unknown => 2\n");
        out.push_str("    | InvalidArgument => 3\n");
        out.push_str("    | DeadlineExceeded => 4\n");
        out.push_str("    | NotFound => 5\n");
        out.push_str("    | AlreadyExists => 6\n");
        out.push_str("    | PermissionDenied => 7\n");
        out.push_str("    | ResourceExhausted => 8\n");
        out.push_str("    | FailedPrecondition => 9\n");
        out.push_str("    | Aborted => 10\n");
        out.push_str("    | OutOfRange => 11\n");
        out.push_str("    | Unimplemented => 12\n");
        out.push_str("    | Internal => 13\n");
        out.push_str("    | Unavailable => 14\n");
        out.push_str("    | DataLoss => 15\n");
        out.push_str("    | Unauthenticated => 16\n");
        out.push_str("    }\n");
        out.push_str("  }\n\n");

        // Request context type
        out.push_str("  // Request context with metadata\n");
        out.push_str("  type context = {\n");
        out.push_str("    headers: Js.Dict.t<string>,\n");
        out.push_str("    metadata: Js.Dict.t<string>,\n");
        out.push_str("  }\n\n");

        // Server error result type
        out.push_str("  type serverError = {\n");
        out.push_str("    status: grpcStatus,\n");
        out.push_str("    message: string,\n");
        out.push_str("  }\n\n");

        // Stream writer for server-streaming responses
        out.push_str("  // Stream writer for server-streaming responses\n");
        out.push_str("  type streamWriter<'a> = {\n");
        out.push_str("    send: 'a => promise<unit>,\n");
        out.push_str("    complete: unit => unit,\n");
        out.push_str("    error: serverError => unit,\n");
        out.push_str("  }\n\n");

        // Generate handler types for each method
        out.push_str("  // Handler type definitions\n");
        for method in &self.methods {
            out.push_str(&self.render_server_handler_type(method));
        }
        out.push('\n');

        // Generate the service definition type (all handlers together)
        out.push_str("  // Service implementation type\n");
        out.push_str("  type service = {\n");
        for method in &self.methods {
            let handler_name = to_camel_case(&method.name);
            out.push_str(&format!("    {}: {}Handler,\n", handler_name, handler_name));
        }
        out.push_str("  }\n\n");

        // Generate route handler
        out.push_str("  // Route method name to handler\n");
        out.push_str("  let methodNames = [\n");
        for method in &self.methods {
            let rpc_path = format!("{}/{}", self.name, method.name);
            out.push_str(&format!("    \"{}\",\n", rpc_path));
        }
        out.push_str("  ]\n\n");

        // Generate handleRequest function for JSON-based routing
        out.push_str("  // Handle incoming JSON request\n");
        out.push_str("  let handleRequest = async (\n");
        out.push_str("    ~service: service,\n");
        out.push_str("    ~method: string,\n");
        out.push_str("    ~body: Js.Json.t,\n");
        out.push_str("    ~context: context,\n");
        out.push_str("  ): result<Js.Json.t, serverError> => {\n");
        out.push_str("    switch method {\n");

        for method in &self.methods {
            // Only handle unary and client-streaming here (single response)
            if !method.server_streaming {
                let rpc_path = format!("{}/{}", self.name, method.name);
                let handler_name = to_camel_case(&method.name);
                out.push_str(&format!("    | \"{}\" =>\n", rpc_path));

                if method.client_streaming {
                    // Client streaming expects array of requests
                    out.push_str(&format!(
                        "      switch Js.Json.decodeArray(body) {{\n"
                    ));
                    out.push_str(&format!(
                        "      | Some(arr) =>\n"
                    ));
                    out.push_str(&format!(
                        "        let requests = Array.filterMap(arr, {}.fromJson)\n",
                        method.input_type
                    ));
                    out.push_str(&format!(
                        "        let response = await service.{}(~requests, ~context)\n",
                        handler_name
                    ));
                    out.push_str("        switch response {\n");
                    out.push_str(&format!(
                        "        | Ok(msg) => Ok({}.toJson(msg))\n",
                        method.output_type
                    ));
                    out.push_str("        | Error(e) => Error(e)\n");
                    out.push_str("        }\n");
                    out.push_str("      | None => Error({status: InvalidArgument, message: \"Expected array of requests\"})\n");
                    out.push_str("      }\n");
                } else {
                    // Unary - single request
                    out.push_str(&format!(
                        "      switch {}.fromJson(body) {{\n",
                        method.input_type
                    ));
                    out.push_str(&format!(
                        "      | Some(request) =>\n"
                    ));
                    out.push_str(&format!(
                        "        let response = await service.{}(~request, ~context)\n",
                        handler_name
                    ));
                    out.push_str("        switch response {\n");
                    out.push_str(&format!(
                        "        | Ok(msg) => Ok({}.toJson(msg))\n",
                        method.output_type
                    ));
                    out.push_str("        | Error(e) => Error(e)\n");
                    out.push_str("        }\n");
                    out.push_str("      | None => Error({status: InvalidArgument, message: \"Failed to decode request\"})\n");
                    out.push_str("      }\n");
                }
            }
        }

        out.push_str("    | _ => Error({status: Unimplemented, message: \"Method not found\"})\n");
        out.push_str("    }\n");
        out.push_str("  }\n\n");

        // Generate streaming request handler
        let has_streaming = self.methods.iter().any(|m| m.server_streaming);
        if has_streaming {
            out.push_str("  // Handle streaming request\n");
            out.push_str("  let handleStreamingRequest = (\n");
            out.push_str("    ~service: service,\n");
            out.push_str("    ~method: string,\n");
            out.push_str("    ~body: Js.Json.t,\n");
            out.push_str("    ~context: context,\n");
            out.push_str("    ~writer: streamWriter<Js.Json.t>,\n");
            out.push_str("  ): unit => {\n");
            out.push_str("    switch method {\n");

            for method in &self.methods {
                if method.server_streaming {
                    let rpc_path = format!("{}/{}", self.name, method.name);
                    let handler_name = to_camel_case(&method.name);
                    out.push_str(&format!("    | \"{}\" =>\n", rpc_path));

                    // Create typed stream writer
                    out.push_str(&format!(
                        "      let typedWriter: streamWriter<{}.t> = {{\n",
                        method.output_type
                    ));
                    out.push_str(&format!(
                        "        send: async msg => await writer.send({}.toJson(msg)),\n",
                        method.output_type
                    ));
                    out.push_str("        complete: writer.complete,\n");
                    out.push_str("        error: writer.error,\n");
                    out.push_str("      }\n");

                    if method.client_streaming {
                        // Bidirectional streaming
                        out.push_str("      switch Js.Json.decodeArray(body) {\n");
                        out.push_str("      | Some(arr) =>\n");
                        out.push_str(&format!(
                            "        let requests = Array.filterMap(arr, {}.fromJson)\n",
                            method.input_type
                        ));
                        out.push_str(&format!(
                            "        service.{}(~requests, ~context, ~writer=typedWriter)\n",
                            handler_name
                        ));
                        out.push_str("      | None => writer.error({status: InvalidArgument, message: \"Expected array of requests\"})\n");
                        out.push_str("      }\n");
                    } else {
                        // Server streaming (unary request)
                        out.push_str(&format!(
                            "      switch {}.fromJson(body) {{\n",
                            method.input_type
                        ));
                        out.push_str("      | Some(request) =>\n");
                        out.push_str(&format!(
                            "        service.{}(~request, ~context, ~writer=typedWriter)\n",
                            handler_name
                        ));
                        out.push_str("      | None => writer.error({status: InvalidArgument, message: \"Failed to decode request\"})\n");
                        out.push_str("      }\n");
                    }
                }
            }

            out.push_str("    | _ => writer.error({status: Unimplemented, message: \"Method not found\"})\n");
            out.push_str("    }\n");
            out.push_str("  }\n\n");
        }

        // Check if method is streaming
        out.push_str("  // Check if method requires streaming response\n");
        out.push_str("  let isStreamingMethod = (method: string): bool => {\n");
        out.push_str("    switch method {\n");
        for method in &self.methods {
            if method.server_streaming {
                let rpc_path = format!("{}/{}", self.name, method.name);
                out.push_str(&format!("    | \"{}\" => true\n", rpc_path));
            }
        }
        out.push_str("    | _ => false\n");
        out.push_str("    }\n");
        out.push_str("  }\n");

        out.push_str("}\n");

        out
    }

    fn render_server_handler_type(&self, method: &MethodInfo) -> String {
        let mut out = String::new();
        let handler_name = to_camel_case(&method.name);

        if method.server_streaming && method.client_streaming {
            // Bidirectional streaming
            out.push_str(&format!(
                "  type {}Handler = (~requests: array<{}.t>, ~context: context, ~writer: streamWriter<{}.t>) => unit\n",
                handler_name, method.input_type, method.output_type
            ));
        } else if method.server_streaming {
            // Server streaming
            out.push_str(&format!(
                "  type {}Handler = (~request: {}.t, ~context: context, ~writer: streamWriter<{}.t>) => unit\n",
                handler_name, method.input_type, method.output_type
            ));
        } else if method.client_streaming {
            // Client streaming
            out.push_str(&format!(
                "  type {}Handler = (~requests: array<{}.t>, ~context: context) => promise<result<{}.t, serverError>>\n",
                handler_name, method.input_type, method.output_type
            ));
        } else {
            // Unary
            out.push_str(&format!(
                "  type {}Handler = (~request: {}.t, ~context: context) => promise<result<{}.t, serverError>>\n",
                handler_name, method.input_type, method.output_type
            ));
        }

        out
    }
}

/// Capitalize the first letter of a string
fn capitalize_first(name: &str) -> String {
    let mut chars = name.chars();
    match chars.next() {
        None => String::new(),
        Some(c) => c.to_uppercase().collect::<String>() + chars.as_str(),
    }
}

/// Convert PascalCase or snake_case to camelCase
fn to_camel_case(name: &str) -> String {
    let mut result = String::new();
    let mut capitalize_next = false;
    let mut first = true;

    for c in name.chars() {
        if c == '_' {
            capitalize_next = true;
        } else if first {
            result.push(c.to_ascii_lowercase());
            first = false;
        } else if capitalize_next {
            result.push(c.to_ascii_uppercase());
            capitalize_next = false;
        } else {
            result.push(c);
        }
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_field_full_type() {
        let field = FieldInfo {
            name: "tags".to_string(),
            proto_name: "tags".to_string(),
            number: 1,
            rescript_type: "string".to_string(),
            is_optional: false,
            is_repeated: true,
            is_message: false,
            is_enum: false,
            oneof_index: None,
            well_known_type: None,
        };
        assert_eq!(field.full_type(), "array<string>");

        let optional = FieldInfo {
            is_optional: true,
            is_repeated: false,
            ..field.clone()
        };
        assert_eq!(optional.full_type(), "option<string>");
    }

    #[test]
    fn test_json_encoders() {
        let string_field = FieldInfo {
            name: "name".to_string(),
            proto_name: "name".to_string(),
            number: 1,
            rescript_type: "string".to_string(),
            is_optional: false,
            is_repeated: false,
            is_message: false,
            is_enum: false,
            oneof_index: None,
            well_known_type: None,
        };
        assert_eq!(string_field.json_encoder(), "Json.Encode.string");

        let enum_field = FieldInfo {
            name: "status".to_string(),
            proto_name: "status".to_string(),
            number: 2,
            rescript_type: "Status.t".to_string(),
            is_optional: false,
            is_repeated: false,
            is_message: false,
            is_enum: true,
            oneof_index: None,
            well_known_type: None,
        };
        assert_eq!(enum_field.json_encoder(), "v => Json.Encode.int(Status.toInt(v))");

        let msg_field = FieldInfo {
            name: "address".to_string(),
            proto_name: "address".to_string(),
            number: 3,
            rescript_type: "Address.t".to_string(),
            is_optional: true,
            is_repeated: false,
            is_message: true,
            is_enum: false,
            oneof_index: None,
            well_known_type: None,
        };
        assert_eq!(msg_field.json_encoder(), "Address.toJson");

        // Test well-known type encoder
        let timestamp_field = FieldInfo {
            name: "createdAt".to_string(),
            proto_name: "created_at".to_string(),
            number: 4,
            rescript_type: "Js.Date.t".to_string(),
            is_optional: true,
            is_repeated: false,
            is_message: true,
            is_enum: false,
            oneof_index: None,
            well_known_type: Some(".google.protobuf.Timestamp".to_string()),
        };
        assert_eq!(timestamp_field.json_encoder(), "WellKnown.Timestamp.toJson");
    }

    #[test]
    fn test_enum_template() {
        let template = EnumTemplate {
            name: "Status".to_string(),
            variants: vec![
                ("Unknown".to_string(), 0),
                ("Active".to_string(), 1),
                ("Inactive".to_string(), 2),
            ],
        };
        let output = template.render();
        assert!(output.contains("module Status"));
        assert!(output.contains("#Active"));
        assert!(output.contains("| 1 => Some(#Active)"));
    }
}
