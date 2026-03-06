// SPDX-License-Identifier: MPL-2.0
//! Code generation logic for ReScript from protobuf descriptors

use std::collections::{HashMap, HashSet};

use anyhow::Result;
use prost_types::compiler::{code_generator_response, CodeGeneratorRequest, CodeGeneratorResponse};
use prost_types::{DescriptorProto, EnumDescriptorProto, FieldDescriptorProto, FileDescriptorProto};

use crate::templates::{EnumTemplate, FieldInfo, MessageTemplate, MethodInfo, ModuleTemplate, OneOfInfo, ServiceTemplate};
use crate::Options;
use prost_types::ServiceDescriptorProto;

pub struct Generator {
    options: Options,
}

impl Generator {
    pub fn new(options: Options) -> Self {
        Self { options }
    }

    pub fn generate(&self, request: &CodeGeneratorRequest) -> Result<CodeGeneratorResponse> {
        let mut response = CodeGeneratorResponse::default();

        // Set supported features
        response.supported_features = Some(
            code_generator_response::Feature::Proto3Optional as u64,
        );

        // Process each file to generate
        for file_name in &request.file_to_generate {
            // Find the file descriptor
            let file_desc = request
                .proto_file
                .iter()
                .find(|f| f.name.as_deref() == Some(file_name.as_str()));

            if let Some(desc) = file_desc {
                let generated = self.generate_file(desc)?;
                response.file.push(generated);
            }
        }

        Ok(response)
    }

    fn generate_file(&self, file: &FileDescriptorProto) -> Result<code_generator_response::File> {
        let file_name = file.name.as_deref().unwrap_or("unknown");
        let package = file.package.as_deref().unwrap_or("");

        // Convert file name to ReScript module name
        // e.g., "user.proto" -> "UserProto.res"
        let module_name = self.proto_to_module_name(file_name);

        let mut modules = Vec::new();

        // Generate enums first (they have no dependencies)
        for enum_desc in &file.enum_type {
            modules.push(self.generate_enum(enum_desc)?);
        }

        // Topologically sort messages by dependencies
        let sorted_messages = self.topological_sort_messages(&file.message_type);

        // Generate messages in dependency order
        for msg_desc in sorted_messages {
            modules.push(self.generate_message(msg_desc, &self.options)?);
        }

        // Generate services if grpc option is enabled
        if self.options.grpc {
            for service_desc in &file.service {
                modules.push(self.generate_service(service_desc)?);
            }
        }

        let template = ModuleTemplate {
            package: package.to_string(),
            source_file: file_name.to_string(),
            modules,
            use_wasm: self.options.wasm,
        };

        let content = template.render();

        Ok(code_generator_response::File {
            name: Some(format!("{}.res", module_name)),
            content: Some(content),
            ..Default::default()
        })
    }

    /// Topologically sort messages so dependencies come before dependents
    fn topological_sort_messages<'a>(
        &self,
        messages: &'a [DescriptorProto],
    ) -> Vec<&'a DescriptorProto> {
        // Build a map of message name -> message
        let msg_map: HashMap<&str, &DescriptorProto> = messages
            .iter()
            .filter_map(|m| m.name.as_deref().map(|n| (n, m)))
            .collect();

        // Build dependency graph: message name -> set of message names it depends on
        let mut deps: HashMap<&str, HashSet<&str>> = HashMap::new();
        for msg in messages {
            let name = msg.name.as_deref().unwrap_or("");
            let mut msg_deps = HashSet::new();

            for field in &msg.field {
                if let Some(type_name) = &field.type_name {
                    // Extract simple name from fully qualified name
                    let simple_name = type_name.rsplit('.').next().unwrap_or(type_name);
                    // Only add as dependency if it's a message in this file
                    if msg_map.contains_key(simple_name) && simple_name != name {
                        msg_deps.insert(simple_name);
                    }
                }
            }

            deps.insert(name, msg_deps);
        }

        // Kahn's algorithm for topological sort
        let mut result = Vec::new();
        let mut no_deps: Vec<&str> = deps
            .iter()
            .filter(|(_, d)| d.is_empty())
            .map(|(n, _)| *n)
            .collect();

        while let Some(name) = no_deps.pop() {
            if let Some(msg) = msg_map.get(name) {
                result.push(*msg);
            }

            // Remove this node from all dependency sets
            for (_, d) in deps.iter_mut() {
                d.remove(name);
            }

            // Find new nodes with no dependencies
            for (n, d) in deps.iter() {
                if d.is_empty() && !result.iter().any(|m| m.name.as_deref() == Some(*n)) && !no_deps.contains(n) {
                    no_deps.push(*n);
                }
            }
        }

        // If we didn't get all messages, there's a cycle - just append remaining
        for msg in messages {
            if !result.iter().any(|m| m.name == msg.name) {
                result.push(msg);
            }
        }

        result
    }

    fn generate_enum(&self, desc: &EnumDescriptorProto) -> Result<String> {
        let name = desc.name.as_deref().unwrap_or("UnknownEnum");

        let variants: Vec<(String, i32)> = desc
            .value
            .iter()
            .map(|v| {
                let variant_name = v.name.as_deref().unwrap_or("UNKNOWN");
                let number = v.number.unwrap_or(0);
                (self.to_rescript_variant(variant_name), number)
            })
            .collect();

        let template = EnumTemplate {
            name: self.to_rescript_type_name(name),
            variants,
        };

        Ok(template.render())
    }

    fn generate_message(&self, desc: &DescriptorProto, options: &Options) -> Result<String> {
        let name = desc.name.as_deref().unwrap_or("UnknownMessage");

        // Collect all fields with their oneof index
        let fields: Vec<FieldInfo> = desc
            .field
            .iter()
            .map(|f| self.field_to_info(f))
            .collect();

        // Build oneof information
        let mut oneofs: Vec<OneOfInfo> = Vec::new();
        for (idx, oneof_desc) in desc.oneof_decl.iter().enumerate() {
            let oneof_name = oneof_desc.name.as_deref().unwrap_or("unknownOneof");

            // Skip synthetic oneofs created for proto3 optional fields
            // A oneof with a single field that has proto3_optional is synthetic
            let oneof_fields: Vec<FieldInfo> = fields
                .iter()
                .filter(|f| f.oneof_index == Some(idx as i32))
                .cloned()
                .collect();

            // Check if this is a synthetic oneof (proto3 optional)
            if oneof_fields.len() == 1 {
                let field = desc.field.iter().find(|f| {
                    f.oneof_index == Some(idx as i32)
                });
                if let Some(f) = field {
                    if f.proto3_optional.unwrap_or(false) {
                        // This is a synthetic oneof for proto3 optional, skip it
                        continue;
                    }
                }
            }

            if !oneof_fields.is_empty() {
                oneofs.push(OneOfInfo {
                    name: self.to_rescript_field_name(oneof_name),
                    rescript_name: self.to_rescript_type_name(oneof_name),
                    fields: oneof_fields,
                });
            }
        }

        // Handle nested types
        let mut nested = Vec::new();
        for nested_enum in &desc.enum_type {
            nested.push(self.generate_enum(nested_enum)?);
        }
        for nested_msg in &desc.nested_type {
            // Skip map entry types (auto-generated)
            if nested_msg.options.as_ref().map(|o| o.map_entry()).unwrap_or(false) {
                continue;
            }
            nested.push(self.generate_message(nested_msg, options)?);
        }

        let template = MessageTemplate {
            name: self.to_rescript_type_name(name),
            fields,
            oneofs,
            nested,
            use_wasm: options.wasm,
        };

        Ok(template.render())
    }

    fn generate_service(&self, desc: &ServiceDescriptorProto) -> Result<String> {
        let name = desc.name.as_deref().unwrap_or("UnknownService");

        let methods: Vec<MethodInfo> = desc
            .method
            .iter()
            .map(|m| {
                let method_name = m.name.as_deref().unwrap_or("unknownMethod");
                let input = m.input_type.as_deref().unwrap_or(".Unknown");
                let output = m.output_type.as_deref().unwrap_or(".Unknown");

                // Extract simple type names from fully qualified names
                let input_simple = input.rsplit('.').next().unwrap_or(input);
                let output_simple = output.rsplit('.').next().unwrap_or(output);

                MethodInfo {
                    name: method_name.to_string(),
                    input_type: self.to_rescript_type_name(input_simple),
                    output_type: self.to_rescript_type_name(output_simple),
                    client_streaming: m.client_streaming.unwrap_or(false),
                    server_streaming: m.server_streaming.unwrap_or(false),
                }
            })
            .collect();

        let template = ServiceTemplate {
            name: self.to_rescript_type_name(name),
            methods,
        };

        Ok(template.render())
    }

    fn field_to_info(&self, field: &FieldDescriptorProto) -> FieldInfo {
        use prost_types::field_descriptor_proto::Type;

        let name = field.name.as_deref().unwrap_or("unknown");
        let number = field.number.unwrap_or(0);
        let is_repeated = field.label() == prost_types::field_descriptor_proto::Label::Repeated;

        let is_message = matches!(field.r#type(), Type::Message);
        let is_enum = matches!(field.r#type(), Type::Enum);

        // Get oneof index if this field is part of a oneof
        let oneof_index = field.oneof_index;

        // Check for well-known types
        let type_name = field.type_name.as_deref().unwrap_or("");
        let well_known_type = if self.is_well_known_type(type_name) {
            Some(type_name.to_string())
        } else {
            None
        };

        // In proto3:
        // - Scalar fields have default values (not optional) unless marked with `optional`
        // - Message fields are always optional (can be null)
        // - Repeated fields are arrays (not optional)
        // - Oneof fields are handled separately (not optional in the traditional sense)
        // - Well-known wrapper types are treated as optional scalars
        let is_optional = if is_repeated {
            false
        } else if oneof_index.is_some() && !field.proto3_optional.unwrap_or(false) {
            // Real oneof fields are not optional - the oneof itself is optional
            false
        } else if well_known_type.is_some() {
            // Well-known types (especially wrappers) are always optional
            true
        } else if is_message {
            true // Message fields are always optional in proto3
        } else {
            // Scalar fields: only optional if proto3_optional is set
            field.proto3_optional.unwrap_or(false)
        };

        let rescript_type = self.proto_type_to_rescript(field);

        FieldInfo {
            name: self.to_rescript_field_name(name),
            proto_name: name.to_string(),
            number,
            rescript_type,
            is_optional,
            is_repeated,
            is_message,
            is_enum,
            oneof_index,
            well_known_type,
        }
    }

    fn proto_type_to_rescript(&self, field: &FieldDescriptorProto) -> String {
        use prost_types::field_descriptor_proto::Type;

        match field.r#type() {
            Type::Double | Type::Float => "float".to_string(),
            Type::Int64 | Type::Uint64 | Type::Sint64 | Type::Fixed64 | Type::Sfixed64 => {
                "bigint".to_string()
            }
            Type::Int32 | Type::Uint32 | Type::Sint32 | Type::Fixed32 | Type::Sfixed32 => {
                "int".to_string()
            }
            Type::Bool => "bool".to_string(),
            Type::String => "string".to_string(),
            Type::Bytes => "Js.Typed_array.Uint8Array.t".to_string(),
            Type::Message | Type::Enum => {
                // Extract type name from fully qualified name
                let type_name = field.type_name.as_deref().unwrap_or("unknown");

                // Check for well-known types
                if let Some(wkt_type) = self.well_known_type_to_rescript(type_name) {
                    return wkt_type;
                }

                let simple_name = type_name.rsplit('.').next().unwrap_or(type_name);
                format!("{}.t", self.to_rescript_type_name(simple_name))
            }
            Type::Group => "unit".to_string(), // Deprecated, treat as unit
        }
    }

    /// Map well-known types to ReScript types
    fn well_known_type_to_rescript(&self, type_name: &str) -> Option<String> {
        match type_name {
            // Timestamp -> Js.Date.t
            ".google.protobuf.Timestamp" => Some("Js.Date.t".to_string()),
            // Duration -> float (seconds)
            ".google.protobuf.Duration" => Some("float".to_string()),
            // Empty -> unit
            ".google.protobuf.Empty" => Some("unit".to_string()),
            // Wrapper types -> unwrapped primitives
            ".google.protobuf.DoubleValue" | ".google.protobuf.FloatValue" => {
                Some("float".to_string())
            }
            ".google.protobuf.Int64Value"
            | ".google.protobuf.UInt64Value"
            | ".google.protobuf.SInt64Value" => Some("bigint".to_string()),
            ".google.protobuf.Int32Value"
            | ".google.protobuf.UInt32Value"
            | ".google.protobuf.SInt32Value" => Some("int".to_string()),
            ".google.protobuf.BoolValue" => Some("bool".to_string()),
            ".google.protobuf.StringValue" => Some("string".to_string()),
            ".google.protobuf.BytesValue" => Some("Js.Typed_array.Uint8Array.t".to_string()),
            // Struct types -> JSON types
            ".google.protobuf.Struct" => Some("Js.Dict.t<Js.Json.t>".to_string()),
            ".google.protobuf.Value" => Some("Js.Json.t".to_string()),
            ".google.protobuf.ListValue" => Some("array<Js.Json.t>".to_string()),
            ".google.protobuf.NullValue" => Some("Js.Null.t<unit>".to_string()),
            // Any -> special type with @type field
            ".google.protobuf.Any" => Some("WellKnown.Any.t".to_string()),
            _ => None,
        }
    }

    /// Check if a type is a well-known type
    fn is_well_known_type(&self, type_name: &str) -> bool {
        type_name.starts_with(".google.protobuf.")
    }

    fn proto_to_module_name(&self, file_name: &str) -> String {
        // "path/to/user.proto" -> "UserProto"
        let base = file_name
            .rsplit('/')
            .next()
            .unwrap_or(file_name)
            .trim_end_matches(".proto");

        let mut result = String::new();
        let mut capitalize_next = true;

        for c in base.chars() {
            if c == '_' || c == '-' {
                capitalize_next = true;
            } else if capitalize_next {
                result.push(c.to_ascii_uppercase());
                capitalize_next = false;
            } else {
                result.push(c);
            }
        }

        format!("{}Proto", result)
    }

    fn to_rescript_type_name(&self, name: &str) -> String {
        // PascalCase for type/module names
        let mut result = String::new();
        let mut capitalize_next = true;

        for c in name.chars() {
            if c == '_' {
                capitalize_next = true;
            } else if capitalize_next {
                result.push(c.to_ascii_uppercase());
                capitalize_next = false;
            } else {
                result.push(c);
            }
        }

        result
    }

    fn to_rescript_field_name(&self, name: &str) -> String {
        // camelCase for field names
        let mut result = String::new();
        let mut capitalize_next = false;

        for c in name.chars() {
            if c == '_' {
                capitalize_next = true;
            } else if capitalize_next {
                result.push(c.to_ascii_uppercase());
                capitalize_next = false;
            } else {
                result.push(c);
            }
        }

        // Escape ReScript keywords
        match result.as_str() {
            "type" | "open" | "let" | "module" | "switch" | "if" | "else" | "while" | "for"
            | "try" | "catch" | "as" | "and" | "or" | "true" | "false" | "rec" | "external"
            | "mutable" | "include" | "private" | "constraint" | "lazy" | "assert"
            | "exception" => {
                format!("{}_", result)
            }
            _ => result,
        }
    }

    fn to_rescript_variant(&self, name: &str) -> String {
        // Variant names should be PascalCase and start with uppercase
        let pascal = self.to_rescript_type_name(name);

        // Handle SCREAMING_SNAKE_CASE enum values
        if name.chars().all(|c| c.is_uppercase() || c == '_' || c.is_numeric()) {
            // SOME_VALUE -> SomeValue
            let mut result = String::new();
            let mut capitalize_next = true;

            for c in name.chars() {
                if c == '_' {
                    capitalize_next = true;
                } else if capitalize_next {
                    result.push(c.to_ascii_uppercase());
                    capitalize_next = false;
                } else {
                    result.push(c.to_ascii_lowercase());
                }
            }

            result
        } else {
            pascal
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_proto_to_module_name() {
        let generator = Generator::new(Options::default());
        assert_eq!(generator.proto_to_module_name("user.proto"), "UserProto");
        assert_eq!(
            generator.proto_to_module_name("path/to/user_service.proto"),
            "UserServiceProto"
        );
    }

    #[test]
    fn test_to_rescript_field_name() {
        let generator = Generator::new(Options::default());
        assert_eq!(generator.to_rescript_field_name("user_name"), "userName");
        assert_eq!(generator.to_rescript_field_name("type"), "type_");
    }

    #[test]
    fn test_to_rescript_variant() {
        let generator = Generator::new(Options::default());
        assert_eq!(generator.to_rescript_variant("SOME_VALUE"), "SomeValue");
        assert_eq!(generator.to_rescript_variant("Active"), "Active");
    }
}
