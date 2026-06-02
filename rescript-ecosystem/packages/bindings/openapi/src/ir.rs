// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

//! Intermediate Representation for ReScript codegen
//!
//! Transforms OpenAPI structures into a codegen-friendly IR that maps
//! directly to ReScript constructs.

use anyhow::{Context, Result};
use heck::{ToLowerCamelCase, ToPascalCase};
use openapiv3::{OpenAPI, ReferenceOr, Schema, SchemaKind, Type};
use std::collections::BTreeMap;

/// ReScript reserved keywords that cannot be used as field names
const RESERVED_KEYWORDS: &[&str] = &[
    "type", "let", "module", "open", "include", "external", "if", "else",
    "switch", "when", "rec", "and", "as", "exception", "try", "catch",
    "while", "for", "in", "to", "downto", "assert", "lazy", "private",
    "mutable", "constraint", "of", "true", "false", "or", "not", "mod",
    "land", "lor", "lxor", "lsl", "lsr", "asr", "await", "async",
];

/// Sanitize a field name to avoid ReScript reserved keywords
fn sanitize_field_name(name: &str) -> String {
    let lower_name = name.to_lower_camel_case();
    if RESERVED_KEYWORDS.contains(&lower_name.as_str()) {
        format!("{}_", lower_name)
    } else {
        lower_name
    }
}

/// Root IR node representing the entire API
#[derive(Debug)]
pub struct ApiSpec {
    pub title: String,
    pub version: String,
    pub description: Option<String>,
    pub types: Vec<TypeDef>,
    pub endpoints: Vec<Endpoint>,
}

/// A ReScript type definition
#[derive(Debug, Clone)]
pub enum TypeDef {
    /// Record type: type user = { name: string, age: int }
    Record {
        name: String,
        doc: Option<String>,
        fields: Vec<Field>,
    },
    /// Variant type: type status = | Active | Inactive
    Variant {
        name: String,
        doc: Option<String>,
        cases: Vec<VariantCase>,
    },
    /// Alias: type userId = string
    Alias {
        name: String,
        doc: Option<String>,
        target: RsType,
    },
}

impl TypeDef {
    pub fn name(&self) -> &str {
        match self {
            TypeDef::Record { name, .. } => name,
            TypeDef::Variant { name, .. } => name,
            TypeDef::Alias { name, .. } => name,
        }
    }
}

/// A field in a record type
#[derive(Debug, Clone)]
pub struct Field {
    pub name: String,
    pub original_name: String,
    pub ty: RsType,
    pub optional: bool,
    pub doc: Option<String>,
}

/// A case in a variant type
#[derive(Debug, Clone)]
pub struct VariantCase {
    pub name: String,
    pub original_name: String,
    pub payload: Option<RsType>,
}

/// ReScript type representation
#[derive(Debug, Clone)]
pub enum RsType {
    String,
    Int,
    Float,
    Bool,
    Unit,
    DateTime,
    Date,
    Option(Box<RsType>),
    Array(Box<RsType>),
    Dict(Box<RsType>),
    Json,
    Named(String),
    Tuple(Vec<RsType>),
    /// Inline string enum (polymorphic variant)
    StringEnum(Vec<String>),
}

impl RsType {
    /// Generate a ReScript type expression for this type
    pub fn to_rescript(&self) -> String {
        match self {
            RsType::String => "string".to_string(),
            RsType::Int => "int".to_string(),
            RsType::Float => "float".to_string(),
            RsType::Bool => "bool".to_string(),
            RsType::Unit => "unit".to_string(),
            RsType::DateTime | RsType::Date => "Date.t".to_string(),
            RsType::Option(inner) => format!("option<{}>", inner.to_rescript()),
            RsType::Array(inner) => format!("array<{}>", inner.to_rescript()),
            RsType::Dict(inner) => format!("Dict.t<{}>", inner.to_rescript()),
            RsType::Json => "JSON.t".to_string(),
            RsType::Named(name) => name.to_lower_camel_case(),
            RsType::Tuple(types) => {
                let inner: Vec<_> = types.iter().map(|t| t.to_rescript()).collect();
                format!("({})", inner.join(", "))
            }
            RsType::StringEnum(values) => {
                // Inline string enums always use polymorphic variants regardless of variant_mode,
                // since standard variants require a named type definition.
                let cases: Vec<_> = values
                    .iter()
                    .map(|v| format!("#\"{}\"", v))
                    .collect();
                format!("[{}]", cases.join(" | "))
            }
        }
    }

    /// Generate a rescript-schema expression for this type
    pub fn to_schema(&self) -> String {
        match self {
            RsType::String => "S.string".to_string(),
            RsType::Int => "S.int".to_string(),
            RsType::Float => "S.float".to_string(),
            RsType::Bool => "S.bool".to_string(),
            RsType::Unit => "S.unit".to_string(),
            RsType::DateTime => "S.datetime".to_string(),
            RsType::Date => "S.string".to_string(),
            RsType::Option(inner) => format!("S.option({})", inner.to_schema()),
            RsType::Array(inner) => format!("S.array({})", inner.to_schema()),
            RsType::Dict(inner) => format!("S.dict({})", inner.to_schema()),
            RsType::Json => "S.json".to_string(),
            RsType::Named(name) => format!("{}Schema", name.to_lower_camel_case()),
            RsType::Tuple(types) => {
                let schemas: Vec<_> = types.iter().map(|t| t.to_schema()).collect();
                format!("S.tuple(s => ({}))", schemas.join(", "))
            }
            RsType::StringEnum(values) => {
                let literals: Vec<_> = values
                    .iter()
                    .map(|v| format!("S.literal(#\"{}\")", v))
                    .collect();
                format!("S.union([{}])", literals.join(", "))
            }
        }
    }
}

/// HTTP endpoint definition
#[derive(Debug)]
pub struct Endpoint {
    pub operation_id: String,
    pub method: HttpMethod,
    pub path: String,
    pub doc: Option<String>,
    pub parameters: Vec<Parameter>,
    pub request_body: Option<RequestBody>,
    pub responses: Vec<Response>,
}

#[derive(Debug, Clone, Copy)]
pub enum HttpMethod {
    Get,
    Post,
    Put,
    Patch,
    Delete,
    Head,
    Options,
}

impl HttpMethod {
    pub fn as_str(&self) -> &'static str {
        match self {
            HttpMethod::Get => "GET",
            HttpMethod::Post => "POST",
            HttpMethod::Put => "PUT",
            HttpMethod::Patch => "PATCH",
            HttpMethod::Delete => "DELETE",
            HttpMethod::Head => "HEAD",
            HttpMethod::Options => "OPTIONS",
        }
    }
}

#[derive(Debug)]
pub struct Parameter {
    pub name: String,
    pub location: ParameterLocation,
    pub ty: RsType,
    pub required: bool,
    pub doc: Option<String>,
}

#[derive(Debug, Clone, Copy)]
pub enum ParameterLocation {
    Path,
    Query,
    Header,
    Cookie,
}

#[derive(Debug)]
pub struct RequestBody {
    pub ty: RsType,
    pub required: bool,
    pub content_type: String,
}

#[derive(Debug)]
pub struct Response {
    pub status: u16,
    pub ty: Option<RsType>,
    pub doc: Option<String>,
}

/// Lower OpenAPI spec to IR
pub fn lower(spec: &OpenAPI) -> Result<ApiSpec> {
    let mut lowerer = Lowerer::new(spec);
    lowerer.lower()
}

struct Lowerer<'a> {
    spec: &'a OpenAPI,
    types: BTreeMap<String, TypeDef>,
}

impl<'a> Lowerer<'a> {
    fn new(spec: &'a OpenAPI) -> Self {
        Self {
            spec,
            types: BTreeMap::new(),
        }
    }

    fn lower(&mut self) -> Result<ApiSpec> {
        // First pass: collect all schema types
        if let Some(components) = &self.spec.components {
            for (name, schema) in &components.schemas {
                if let ReferenceOr::Item(schema) = schema {
                    let type_def = self
                        .lower_schema(name, schema)
                        .with_context(|| format!("Failed to lower schema '{}'", name))?;
                    self.types.insert(name.clone(), type_def);
                }
            }
        }

        // Second pass: collect endpoints
        let mut endpoints = Vec::new();
        for (path, item) in self.spec.paths.iter() {
            if let ReferenceOr::Item(path_item) = item {
                for (method, op) in path_item.iter() {
                    let endpoint = self.lower_operation(path, method, op)?;
                    endpoints.push(endpoint);
                }
            }
        }

        Ok(ApiSpec {
            title: self.spec.info.title.clone(),
            version: self.spec.info.version.clone(),
            description: self.spec.info.description.clone(),
            types: self.types.values().cloned().collect(),
            endpoints,
        })
    }

    fn lower_schema(&self, name: &str, schema: &Schema) -> Result<TypeDef> {
        let doc = schema.schema_data.description.clone();
        let rs_name = name.to_pascal_case();

        match &schema.schema_kind {
            SchemaKind::Type(Type::Object(obj)) => {
                let mut fields = Vec::new();

                for (prop_name, prop_schema) in &obj.properties {
                    let required = obj.required.contains(prop_name);
                    let ty = self.boxed_schema_to_type(prop_schema)?;
                    let field_ty = if required {
                        ty
                    } else {
                        RsType::Option(Box::new(ty))
                    };

                    let field_doc = if let ReferenceOr::Item(s) = prop_schema {
                        s.schema_data.description.clone()
                    } else {
                        None
                    };

                    fields.push(Field {
                        name: sanitize_field_name(prop_name),
                        original_name: prop_name.clone(),
                        ty: field_ty,
                        optional: !required,
                        doc: field_doc,
                    });
                }

                Ok(TypeDef::Record {
                    name: rs_name,
                    doc,
                    fields,
                })
            }

            SchemaKind::Type(Type::String(string_type)) => {
                if !string_type.enumeration.is_empty() {
                    // String enum -> variant type
                    let cases = string_type
                        .enumeration
                        .iter()
                        .filter_map(|v| v.as_ref())
                        .map(|v| VariantCase {
                            name: v.to_pascal_case(),
                            original_name: v.clone(),
                            payload: None,
                        })
                        .collect();

                    Ok(TypeDef::Variant {
                        name: rs_name,
                        doc,
                        cases,
                    })
                } else {
                    Ok(TypeDef::Alias {
                        name: rs_name,
                        doc,
                        target: RsType::String,
                    })
                }
            }

            SchemaKind::OneOf { one_of } => {
                let cases = self.lower_variant_cases(one_of);
                Ok(TypeDef::Variant {
                    name: rs_name,
                    doc,
                    cases,
                })
            }

            SchemaKind::AnyOf { any_of } => {
                let cases = self.lower_variant_cases(any_of);
                Ok(TypeDef::Variant {
                    name: rs_name,
                    doc,
                    cases,
                })
            }

            _ => {
                // Default to alias
                let target = self.schema_kind_to_type(&schema.schema_kind)?;
                Ok(TypeDef::Alias {
                    name: rs_name,
                    doc,
                    target,
                })
            }
        }
    }

    fn schema_to_type(&self, schema: &ReferenceOr<Schema>) -> Result<RsType> {
        match schema {
            ReferenceOr::Reference { reference } => {
                let name = reference
                    .strip_prefix("#/components/schemas/")
                    .unwrap_or(reference);
                Ok(RsType::Named(name.to_pascal_case()))
            }
            ReferenceOr::Item(schema) => self.schema_kind_to_type(&schema.schema_kind),
        }
    }

    fn boxed_schema_to_type(&self, schema: &ReferenceOr<Box<Schema>>) -> Result<RsType> {
        match schema {
            ReferenceOr::Reference { reference } => {
                let name = reference
                    .strip_prefix("#/components/schemas/")
                    .unwrap_or(reference);
                Ok(RsType::Named(name.to_pascal_case()))
            }
            ReferenceOr::Item(schema) => self.schema_kind_to_type(&schema.schema_kind),
        }
    }

    /// Lower oneOf/anyOf schemas into variant cases
    ///
    /// Extracts meaningful names from $ref references (e.g., Cat from #/components/schemas/Cat)
    /// and falls back to Case1, Case2, etc. for inline schemas.
    fn lower_variant_cases(&self, schemas: &[ReferenceOr<Schema>]) -> Vec<VariantCase> {
        let mut cases = Vec::new();
        let mut fallback_index = 1;

        for schema in schemas {
            let (case_name, original_name, payload) = match schema {
                ReferenceOr::Reference { reference } => {
                    // Extract type name from $ref (e.g., #/components/schemas/Cat -> Cat)
                    let ref_name = reference
                        .strip_prefix("#/components/schemas/")
                        .unwrap_or(reference);
                    let name = ref_name.to_pascal_case();
                    let ty = RsType::Named(name.clone());
                    (name, ref_name.to_string(), Some(ty))
                }
                ReferenceOr::Item(inline_schema) => {
                    // For inline schemas, try to get a meaningful name from the title
                    // or fall back to Case1, Case2, etc.
                    let original_name = inline_schema
                        .schema_data
                        .title
                        .as_ref()
                        .map(|t| t.to_string())
                        .unwrap_or_else(|| {
                            let name = format!("Case{}", fallback_index);
                            fallback_index += 1;
                            name
                        });

                    let name = original_name.to_pascal_case();
                    let ty = self.schema_kind_to_type(&inline_schema.schema_kind).ok();
                    (name, original_name, ty)
                }
            };

            cases.push(VariantCase {
                name: case_name,
                original_name,
                payload,
            });
        }

        cases
    }

    fn schema_kind_to_type(&self, kind: &SchemaKind) -> Result<RsType> {
        match kind {
            SchemaKind::Type(Type::String(string_type)) => {
                // Check for inline string enum
                if !string_type.enumeration.is_empty() {
                    let values: Vec<String> = string_type
                        .enumeration
                        .iter()
                        .filter_map(|v| v.clone())
                        .collect();
                    Ok(RsType::StringEnum(values))
                } else {
                    // Check for specialized formats
                    match &string_type.format {
                        openapiv3::VariantOrUnknownOrEmpty::Item(openapiv3::StringFormat::DateTime) => {
                            Ok(RsType::DateTime)
                        }
                        openapiv3::VariantOrUnknownOrEmpty::Item(openapiv3::StringFormat::Date) => {
                            Ok(RsType::Date)
                        }
                        _ => Ok(RsType::String),
                    }
                }
            }
            SchemaKind::Type(Type::Integer(_)) => Ok(RsType::Int),
            SchemaKind::Type(Type::Number(_)) => Ok(RsType::Float),
            SchemaKind::Type(Type::Boolean(_)) => Ok(RsType::Bool),
            SchemaKind::Type(Type::Array(arr)) => {
                let item_type = arr
                    .items
                    .as_ref()
                    .map(|i| self.boxed_schema_to_type(i))
                    .transpose()?
                    .unwrap_or(RsType::Json);
                Ok(RsType::Array(Box::new(item_type)))
            }
            SchemaKind::Type(Type::Object(_)) => Ok(RsType::Json),
            SchemaKind::Any(_) => Ok(RsType::Json),
            _ => Ok(RsType::Json),
        }
    }

    fn lower_operation(
        &self,
        path: &str,
        method: &str,
        op: &openapiv3::Operation,
    ) -> Result<Endpoint> {
        let operation_id = op
            .operation_id
            .clone()
            .unwrap_or_else(|| format!("{}_{}", method, path.replace('/', "_")));

        let http_method = match method.to_uppercase().as_str() {
            "GET" => HttpMethod::Get,
            "POST" => HttpMethod::Post,
            "PUT" => HttpMethod::Put,
            "PATCH" => HttpMethod::Patch,
            "DELETE" => HttpMethod::Delete,
            "HEAD" => HttpMethod::Head,
            "OPTIONS" => HttpMethod::Options,
            _ => HttpMethod::Get,
        };

        let mut parameters = Vec::new();
        for param in &op.parameters {
            if let ReferenceOr::Item(param) = param {
                let location = match &param.parameter_data_ref() {
                    openapiv3::ParameterData {
                        name: _,
                        description: _,
                        required: _,
                        deprecated: _,
                        format:
                            openapiv3::ParameterSchemaOrContent::Schema(ReferenceOr::Item(_schema)),
                        example: _,
                        examples: _,
                        explode: _,
                        extensions: _,
                    } => match param {
                        openapiv3::Parameter::Path { .. } => ParameterLocation::Path,
                        openapiv3::Parameter::Query { .. } => ParameterLocation::Query,
                        openapiv3::Parameter::Header { .. } => ParameterLocation::Header,
                        openapiv3::Parameter::Cookie { .. } => ParameterLocation::Cookie,
                    },
                    _ => continue,
                };

                let param_data = param.parameter_data_ref();
                let ty = if let openapiv3::ParameterSchemaOrContent::Schema(schema) =
                    &param_data.format
                {
                    self.schema_to_type(schema)?
                } else {
                    RsType::String
                };

                parameters.push(Parameter {
                    name: param_data.name.to_lower_camel_case(),
                    location,
                    ty,
                    required: param_data.required,
                    doc: param_data.description.clone(),
                });
            }
        }

        let request_body = if let Some(ReferenceOr::Item(body)) = &op.request_body {
            body.content.get("application/json").map(|media| {
                let ty = media
                    .schema
                    .as_ref()
                    .and_then(|s| self.schema_to_type(s).ok())
                    .unwrap_or(RsType::Json);
                RequestBody {
                    ty,
                    required: body.required,
                    content_type: "application/json".to_string(),
                }
            })
        } else {
            None
        };

        let mut responses = Vec::new();
        for (status, response) in &op.responses.responses {
            if let ReferenceOr::Item(response) = response {
                let status_code = match status {
                    openapiv3::StatusCode::Code(code) => *code,
                    openapiv3::StatusCode::Range(_) => continue,
                };

                let ty = response.content.get("application/json").and_then(|media| {
                    media
                        .schema
                        .as_ref()
                        .and_then(|s| self.schema_to_type(s).ok())
                });

                responses.push(Response {
                    status: status_code,
                    ty,
                    doc: Some(response.description.clone()),
                });
            }
        }

        Ok(Endpoint {
            operation_id: operation_id.to_lower_camel_case(),
            method: http_method,
            path: path.to_string(),
            doc: op.description.clone().or(op.summary.clone()),
            parameters,
            request_body,
            responses,
        })
    }
}
