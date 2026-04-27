#![allow(clippy::unwrap_used, clippy::expect_used)]
#![allow(dead_code)]

use std::{collections::HashMap, fs, path::PathBuf};

use heck::ToShoutySnakeCase;
use proc_macro::TokenStream;
use quote::{ format_ident, quote };
use syn::{ Data, DeriveInput, Fields, ItemImpl, Lit, LitStr, Type, parse_macro_input };

#[proc_macro_derive(EnumParam)]
pub fn derive_enum_param(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);
    let name = input.ident;

    let Data::Enum(data_enum) = input.data else {
        panic!("EnumParam can only be derived for enums");
    };

    let variants: Vec<_> = data_enum.variants.into_iter().collect();

    // Extract variant identifiers and strings for use in generated code
    let variant_idents: Vec<_> = variants
        .iter()
        .map(|v| v.ident.clone())
        .collect();
    let variant_strings: Vec<_> = variants
        .iter()
        .map(|v| v.ident.to_string())
        .collect();

    // Fallback to the first variant if #[default] is missing
    let mut default_variant = variants
        .first()
        .expect("Enum must have at least one variant")
        .ident.clone();
    for variant in &variants {
        if variant.attrs.iter().any(|attr| attr.path().is_ident("default")) {
            default_variant = variant.ident.clone();
            break;
        }
    }

    let expanded =
        quote! {
        impl ::karbeat_plugin_types::parameter::EnumParam for #name {
            #[inline(always)]
            fn to_index(self) -> usize {
                self as usize
            }

            #[inline(always)]
            fn from_index(index: usize) -> Self {
                // Generate an array of all variants
                let variants = [ #( #name::#variant_idents ),* ];
                
                if index < variants.len() {
                    variants[index]
                } else {
                    #name::#default_variant
                }
            }

            fn variants() -> &'static [&'static str] {
                // Generate the array of string slices
                &[ #( #variant_strings ),* ]
            }
        }
    };

    TokenStream::from(expanded)
}

struct ParamDef {
    field_name: syn::Ident,
    original_type: Type,
    id: u32,
    name: String,
    group: String,
    min: f32,
    max: f32,
    step: f32,
    default: f32,
}

/// # Overview
///
/// Macro to generate implementation for getter, setter, and automation
///
/// # How to Use
///
/// Put attribute macro on labelled parameters using `#[nested]` if
/// it is a non-primitive type, or in other words "custom type".
/// Else, just use the `#[param(id=your_id, name=your_name, group=your_group, min=your_min_value
/// max=your_max_value, default=your_default_value, step=your_step_value)]`.
/// For nested value, your custom type should also implement AutoParams. you can achieve
/// the same result by using the `#[karbeat_plugin]` macro again in your custom type
#[proc_macro_attribute]
pub fn karbeat_plugin(_attr: TokenStream, item: TokenStream) -> TokenStream {
    let mut ast = parse_macro_input!(item as DeriveInput);
    let struct_name = &ast.ident;
    let enum_name = format_ident!("{}ParamIds", struct_name);
    let (impl_generics, ty_generics, where_clause) = ast.generics.split_for_impl();
    let mut params = Vec::new();
    let mut nested_fields: Vec<(syn::Ident, bool)> = Vec::new();
    let mut used_ids: HashMap<u32, syn::Ident> = HashMap::new();
    if let Data::Struct(data_struct) = &mut ast.data {
        if let Fields::Named(fields) = &mut data_struct.fields {
            for field in fields.named.iter_mut() {
                let field_ident = field.ident.clone().unwrap();
                let mut is_param = false;

                let mut macro_error: Option<syn::Error> = None;

                for attr in &field.attrs {
                    if attr.path().is_ident("param") {
                        is_param = true;
                        let mut p_id = 0;
                        let mut p_name = String::new();
                        let mut p_group = String::new();
                        let mut p_min = 0.0;
                        let mut p_max = 1.0;
                        let mut p_default = 0.0;
                        let mut p_step = 0.0;

                        let res = attr.parse_nested_meta(|meta| {
                            if meta.path.is_ident("id") {
                                let value = meta.value()?.parse::<Lit>()?;
                                if let Lit::Int(lit_int) = value {
                                    let parsed_id = lit_int.base10_parse()?;

                                    if let Some(existing_field) = used_ids.get(&parsed_id) {
                                        return Err(
                                            syn::Error::new_spanned(
                                                &lit_int, // Points the error exactly at the duplicate number!
                                                format!(
                                                    "Parameter ID collision! ID {} is already used by field `{}`.",
                                                    parsed_id,
                                                    existing_field
                                                )
                                            )
                                        );
                                    }

                                    // Register the ID
                                    used_ids.insert(parsed_id, field_ident.clone());
                                    p_id = parsed_id;
                                }
                            } else if meta.path.is_ident("name") {
                                let value = meta.value()?.parse::<Lit>()?;
                                if let Lit::Str(lit_str) = value {
                                    p_name = lit_str.value();
                                }
                            } else if meta.path.is_ident("group") {
                                let value = meta.value()?.parse::<Lit>()?;
                                if let Lit::Str(lit_str) = value {
                                    p_group = lit_str.value();
                                }
                            } else if meta.path.is_ident("min") {
                                let value = meta.value()?.parse::<Lit>()?;
                                if let Lit::Float(lit_float) = value {
                                    p_min = lit_float.base10_parse()?;
                                }
                            } else if meta.path.is_ident("max") {
                                let value = meta.value()?.parse::<Lit>()?;
                                if let Lit::Float(lit_float) = value {
                                    p_max = lit_float.base10_parse()?;
                                }
                            } else if meta.path.is_ident("default") {
                                let value = meta.value()?.parse::<Lit>()?;
                                if let Lit::Float(lit_float) = value {
                                    p_default = lit_float.base10_parse()?;
                                }
                            }  else if meta.path.is_ident("step") {
                                let value = meta.value()?.parse::<Lit>()?;
                                if let Lit::Float(lit_float) = value {
                                    p_step = lit_float.base10_parse()?;
                                }
                            }
                            else {
                                return Err(
                                    syn::Error::new_spanned(
                                        &meta.path,
                                        format!("{:?} is not a valid parameter", meta.path)
                                    )
                                );
                            }
                            Ok(())
                        });

                        if let Err(e) = res {
                            macro_error = Some(e);
                        }

                        params.push(ParamDef {
                            field_name: field_ident.clone(),
                            original_type: field.ty.clone(),
                            id: p_id,
                            name: p_name,
                            group: p_group,
                            min: p_min,
                            max: p_max,
                            step: p_step,
                            default: p_default,
                        });
                    } else if attr.path().is_ident("nested") {
                        let is_iterable = match &field.ty {
                            Type::Array(_) | Type::Slice(_) => true,
                            Type::Path(p) => {
                                if let Some(segment) = p.path.segments.last() {
                                    let id = segment.ident.to_string();
                                    id == "Vec" || id == "VecDeque" || id == "Option"
                                } else {
                                    false
                                }
                            }
                            _ => false,
                        };
                        nested_fields.push((field_ident.clone(), is_iterable));
                    }
                }

                if let Some(err) = macro_error {
                    return TokenStream::from(err.to_compile_error());
                }

                if is_param {
                    let orig_ty = &field.ty;
                    let new_ty: Type = syn::parse_quote!(Param<#orig_ty>);
                    field.ty = new_ty;
                }

                // Remove the custom attributes so the Rust compiler doesn't panic
                field.attrs.retain(
                    |attr| !attr.path().is_ident("param") && !attr.path().is_ident("nested")
                );
            }
        }
    }

    let enum_variants = params.iter().map(|p| {
        let variant_name = format_ident!("{}", p.name.replace(" ", ""));
        let id = p.id;
        quote! { #variant_name = #id }
    });

    let set_match_arms = params.iter().map(|p| {
        let field = &p.field_name;
        let id = p.id;
        quote! { #id => { self.#field.set_base(value); return; } }
    });

    let nested_set_stmts = nested_fields.iter().map(|(f, is_iterable)| {
        if *is_iterable {
            quote! {
                for item in &mut self.#f {
                    if item.auto_get_parameter(id).is_some() {
                        item.auto_set_parameter(id, value);
                        return;
                    }
                }
            }
        } else {
            quote! {
                if self.#f.auto_get_parameter(id).is_some() {
                    self.#f.auto_set_parameter(id, value);
                    return;
                }
            }
        }
    });

    let get_match_arms = params.iter().map(|p| {
        let field = &p.field_name;
        let id = p.id;
        quote! { #id => return Some(self.#field.get_base().to_f32()), }
    });

    let nested_get_stmts = nested_fields.iter().map(|(f, is_iterable)| {
        if *is_iterable {
            quote! {
                for item in &self.#f {
                    if let Some(v) = item.auto_get_parameter(id) {
                        return Some(v);
                    }
                }
            }
        } else {
            quote! {
                if let Some(v) = self.#f.auto_get_parameter(id) {
                    return Some(v);
                }
            }
        }
    });

    let apply_auto_arms = params.iter().map(|p| {
        let field = &p.field_name;
        let id = p.id;
        quote! { #id => { self.#field.apply_automation(value); return; } }
    });

    let nested_apply_stmts = nested_fields.iter().map(|(f, is_iterable)| {
        if *is_iterable {
            quote! {
                for item in &mut self.#f {
                    if item.auto_get_parameter(id).is_some() {
                        item.auto_apply_automation(id, value);
                        return;
                    }
                }
            }
        } else {
            quote! {
                if self.#f.auto_get_parameter(id).is_some() {
                    self.#f.auto_apply_automation(id, value);
                    return;
                }
            }
        }
    });

    let clear_auto_arms = params.iter().map(|p| {
        let field = &p.field_name;
        let id = p.id;
        quote! { #id => { self.#field.clear_automation(); return; } }
    });

    let nested_clear_stmts = nested_fields.iter().map(|(f, is_iterable)| {
        if *is_iterable {
            quote! {
                for item in &mut self.#f {
                    if item.auto_get_parameter(id).is_some() {
                        item.auto_clear_automation(id);
                        return;
                    }
                }
            }
        } else {
            quote! {
                if self.#f.auto_get_parameter(id).is_some() {
                    self.#f.auto_clear_automation(id);
                    return;
                }
            }
        }
    });

    let spec_pushes = params.iter().map(|p| {
        let field = &p.field_name;
        quote! { specs.push(self.#field.to_spec()); }
    });

    let nested_spec_stmts = nested_fields.iter().map(|(f, is_iterable)| {
        if *is_iterable {
            quote! {
                for item in &self.#f {
                    specs.extend(item.auto_get_parameter_specs());
                }
            }
        } else {
            quote! {
                specs.extend(self.#f.auto_get_parameter_specs());
            }
        }
    });

    let type_checks = params.iter().map(|p| {
        let ty = &p.original_type;

        quote! {
            const _: () = {
                // Define a function that demands the ParamType trait
                fn assert_implements_param_type<T: karbeat_plugin_types::parameter::ParamType>() {}
                
                // Attempt to call it with the field's type. 
                // If it doesn't implement the trait, the compiler throws a massive error here!
                let _ = assert_implements_param_type::<#ty>;
            };
        }
    });

    let mut default_field_inits = Vec::new();

    if let Data::Struct(data_struct) = &ast.data {
        if let Fields::Named(fields) = &data_struct.fields {
            for field in fields.named.iter() {
                let field_ident = field.ident.as_ref().unwrap();

                // If the field is in our parsed parameters list, initialize it fully
                if let Some(p) = params.iter().find(|p| &p.field_name == field_ident) {
                    let id = p.id;
                    let name = &p.name;
                    let group = &p.group;
                    let default_val = p.default;
                    let min = p.min;
                    let max = p.max;
                    let step = p.step;
                    let ty = &p.original_type;

                    // Convert the AST Type to a string to check what it is
                    let ty_str = quote!(#ty).to_string().replace(" ", "");

                    let param_init = if ty_str == "f32" {
                        quote! {
                            karbeat_plugin_types::parameter::Param::new_f32(#id, #name, #group, #default_val, #min, #max, #step)
                        }
                    } else if ty_str == "bool" {
                        quote! {
                            // Convert float default (e.g. 0.0 or 1.0) back to bool
                            karbeat_plugin_types::parameter::Param::new_bool(#id, #name, #group, #default_val > 0.5)
                        }
                    } else {
                        quote! {
                            // Treat anything else as an Enum, using the EnumParam trait to cast the default
                            karbeat_plugin_types::parameter::Param::new_enum(
                                #id, 
                                #name, 
                                #group, 
                                <#ty as karbeat_plugin_types::parameter::EnumParam>::from_index(#default_val as usize)
                            )
                        }
                    };

                    default_field_inits.push(
                        quote! {
                        #field_ident: #param_init
                    }
                    );
                } else {
                    // For #[nested] or standard fields, fallback to standard default
                    default_field_inits.push(
                        quote! {
                        #field_ident: std::default::Default::default()
                    }
                    );
                }
            }
        }
    }

    let expanded =
        quote! {
        #ast

        #[repr(u32)]
        pub enum #enum_name {
            #(#enum_variants),*
        }

        #(#type_checks)*

        // Generate a base constructor instead of the Default trait
        impl #struct_name {
            /// Creates an instance with all `#[param]` fields initialized to their macro defaults.
            pub fn base_default() -> Self {
                Self {
                    #(#default_field_inits),*
                }
            }
        }

        const _: () = {
            use karbeat_plugin_types::parameter::ParamType;
            use karbeat_plugin_types::parameter::EnumParam;
            use karbeat_plugin_types::parameter::AutoParams;
            impl #impl_generics AutoParams for #struct_name #ty_generics #where_clause {
                fn auto_set_parameter(&mut self, id: u32, value: f32) {
                    match id {
                        #(#set_match_arms)*
                        _ => {}
                    }
                    #(#nested_set_stmts)*
                }

                fn auto_get_parameter(&self, id: u32) -> Option<f32> {
                    match id {
                        #(#get_match_arms)*
                        _ => {}
                    }
                    #(#nested_get_stmts)*
                    None
                }

                fn auto_apply_automation(&mut self, id: u32, value: f32) {
                    match id {
                        #(#apply_auto_arms)*
                        _ => {}
                    }
                    #(#nested_apply_stmts)*
                }

                fn auto_clear_automation(&mut self, id: u32) {
                    match id {
                        #(#clear_auto_arms)*
                        _ => {}
                    }
                    #(#nested_clear_stmts)*
                }

                fn auto_get_parameter_specs(&self) -> Vec<karbeat_plugin_types::parameter::ParameterSpec> {
                    let mut specs = Vec::new();
                    #(#spec_pushes)*
                    #(#nested_spec_stmts)*
                    specs
                }
            }
        };
    };
    TokenStream::from(expanded)
}

/// Inject auto implementation for parameter routing
///
/// ## Attributes
/// To inject side effect for any value modification, you
/// are able to inject it by specifying a side effect function
/// in the struct implementation
///
/// For example:
///
/// ```rust, ignore
/// impl WavetableSynthEngine {
///     pub fn side_effect_func(&mut self) {
///         do_something()
///     }
/// }
///
/// #[inject_plugin_routing(side_effect_func)]
/// impl RawSynthEngine for WavetableSynthEngine {
///     fn process() {
///         // ...
///     }
/// }
/// ```
///
/// With this, it will generate the implementation for parameter routing together with provided side effect
#[proc_macro_attribute]
pub fn inject_plugin_routing(attr: TokenStream, item: TokenStream) -> TokenStream {
    // Check if the user provided a side-effect function (e.g., #[inject_plugin_routing(handle_side_effects)])
    let mut side_effect_call = quote! {};
    if !attr.is_empty() {
        let ident = syn::parse_macro_input!(attr as syn::Ident);
        // If they provided a function name, we generate the call: `self.function_name(id);`
        side_effect_call = quote! { self.#ident(id); };
    }

    // Parse the trait impl block the user wrote
    let item_impl = parse_macro_input!(item as ItemImpl);

    let generics = &item_impl.generics;
    let trait_path = &item_impl.trait_
        .as_ref()
        .expect("This macro must be applied to a trait implementation").1;
    let self_ty = &item_impl.self_ty;
    let items = &item_impl.items;

    // Generate the boilerplate methods using their AutoParams implementation
    let injected_code =
        quote! {
        fn set_custom_parameter(&mut self, id: u32, value: f32) {
            self.auto_set_parameter(id, value);
            #side_effect_call
        }

        fn get_custom_parameter(&self, id: u32) -> Option<f32> {
            self.auto_get_parameter(id)
        }

        fn apply_automation(&mut self, id: u32, value: f32) {
            self.auto_apply_automation(id, value);
            #side_effect_call
        }
        
        fn clear_automation(&mut self, id: u32) {
            self.auto_clear_automation(id);
            #side_effect_call
        }

        fn get_parameter_specs(&self) -> Vec<karbeat_plugin_types::ParameterSpec> {
            self.auto_get_parameter_specs()
        }

        fn custom_default_parameters() -> std::collections::HashMap<u32, f32> where Self: Sized {
            let mut map = std::collections::HashMap::new();
            for spec in Self::default().auto_get_parameter_specs() {
                map.insert(spec.id, spec.default_value);
            }
            map
        }
    };

    // Rebuild the impl block: Original User Methods + Injected Boilerplate
    let expanded =
        quote! {
        impl #generics #trait_path for #self_ty {
            // Keep the user's manual process(), name(), prepare(), etc.
            #(#items)*
            
            // Inject the magic
            #injected_code
        }
    };

    TokenStream::from(expanded)
}

/// Macro to generate implementation of AutoParams. the parameter must use the Param<T> struct
#[proc_macro_derive(AutoParams, attributes(skip))]
pub fn derive_auto_params(input: TokenStream) -> TokenStream {
    let input_derive = parse_macro_input!(input as DeriveInput);

    let name = &input_derive.ident;

    let (impl_generics, ty_generics, where_clause) = input_derive.generics.split_for_impl();
    let fields = match &input_derive.data {
        Data::Struct(data_struct) => match &data_struct.fields {
            Fields::Named(fields_named) => &fields_named.named,
            _ => panic!("AutoParams can only be derived on structs with named fields"),
        },
        _ => panic!("AutoParams can only be derived on structs"),
    };

    let mut param_fields = Vec::new();

    for field in fields.iter() {
        let is_nested = field.attrs.iter().any(|attr| attr.path().is_ident("skip"));
    
        if !is_nested {
            let mut is_valid_param = false;

            if let Type::Path(type_path) = &field.ty {
                if let Some(segment) = type_path.path.segments.last() {
                    if segment.ident == "Param" {
                        is_valid_param = true;
                    }
                }
            }

            if !is_valid_param {
                let error_msg = format!(
                    "AutoParams requires field '{}' to be of type `karbeat_plugin_types::Param<T>`. \n\
                    If this is a sub-module or standard field, ignore it with `#[skip]`.",
                    field.ident.as_ref().unwrap()
                );
                
                return syn::Error::new_spanned(&field.ty, error_msg)
                    .to_compile_error()
                    .into();
            }

            param_fields.push(field);
        }
    }

    let get_arms = param_fields.iter().map(|f| {
        let fname = &f.ident;
        quote! {
            if self.#fname.id == id {
                return Some(self.#fname.get_base().to_f32());
            }
        }
    });

    let set_arms = param_fields.iter().map(|f| {
        let fname = &f.ident;
        quote! {
            if self.#fname.id == id {
                self.#fname.set_base(value);
                return;
            }
        }
    });

    let apply_arms = param_fields.iter().map(|f| {
        let fname = &f.ident;
        quote! {
            if self.#fname.id == id {
                self.#fname.apply_automation(value);
                return;
            }
        }
    });

    let clear_arms = param_fields.iter().map(|f| {
        let fname = &f.ident;
        quote! {
            if self.#fname.id == id {
                self.#fname.clear_automation();
                return;
            }
        }
    });

    let spec_arms = param_fields.iter().map(|f| {
        let fname = &f.ident;
        quote! {
            self.#fname.to_spec()
        }
    });

    let expanded = quote! {
        const _: () = {
            use karbeat_plugin_types::ParamType;
            use karbeat_plugin_types::parameter::{AutoParams, ParameterSpec};

            impl #impl_generics AutoParams for #name #ty_generics #where_clause {
                fn auto_get_parameter(&self, id: u32) -> Option<f32> {
                    #(#get_arms)*
                    None
                }

                fn auto_set_parameter(&mut self, id: u32, value: f32) {
                    #(#set_arms)*
                }

                fn auto_apply_automation(&mut self, id: u32, value: f32) {
                    #(#apply_arms)*
                }

                fn auto_clear_automation(&mut self, id: u32) {
                    #(#clear_arms)*
                }

                fn auto_get_parameter_specs(&self) -> Vec<ParameterSpec> {
                    vec![
                        #(#spec_arms),*
                    ]
                }
            }
        };
    };

    TokenStream::from(expanded)
}

#[proc_macro]
pub fn build_dynamic_registry(input: TokenStream) -> TokenStream {
    let dir_lit = parse_macro_input!(input as LitStr);
    let rel_dir = dir_lit.value();

    let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR not set");
    let base_path = PathBuf::from(manifest_dir).join(&rel_dir);

    let synths_path = base_path.join("synths");
    let effects_path = base_path.join("effects");

    let mut generator_inserts = Vec::new();
    let mut effect_inserts = Vec::new();
    let mut file_trackers = Vec::new();
    let mut associated_constants = Vec::new(); // <-- NEW: Store the generated constants

    let mut process_directory = |dir_path: &PathBuf, is_synth: bool| {
        if let Ok(entries) = fs::read_dir(dir_path) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().and_then(|s| s.to_str()) != Some("json") {
                    continue;
                }

                let json_data = fs::read_to_string(&path).unwrap();
                let manifest: serde_json::Value = serde_json::from_str(&json_data)
                    .unwrap_or_else(|_| panic!("Invalid JSON in {:?}", path));

                let id = manifest["id"].as_u64().expect("Missing id") as u32;
                let name = manifest["name"].as_str().expect("Missing name");
                
                let internal_type_str = manifest["internal_type"]
                .as_str()
                    .expect("Missing 'internal_type' in manifest!");
                let internal_ident = format_ident!("{}", internal_type_str);

                let shouty_name = internal_type_str.to_owned().to_shouty_snake_case();
                let const_prefix = if is_synth { "GEN_" } else { "EFF_" };
                let const_ident = format_ident!("{}{}", const_prefix, shouty_name);

                associated_constants.push(quote! {
                    pub const #const_ident: u32 = #id;
                });

                let mut param_tokens = Vec::new();
                if let Some(params) = manifest["parameters"].as_array() {
                    for p in params {
                        let p_id = p["id"].as_u64().unwrap() as u32;
                        let p_name = p["name"].as_str().unwrap();
                        let p_group = p["group"].as_str().unwrap();
                        let default_val = p["default_value"].as_f64().unwrap() as f32;
                        let min = p["min"].as_f64().unwrap() as f32;
                        let max = p["max"].as_f64().unwrap() as f32;
                        let step = p["step"].as_f64().unwrap() as f32;
                        
                        let val_type_str = p["value_type"].as_str().unwrap();
                        let val_type_ident = format_ident!("{}", val_type_str);

                        let choices_tokens = if let Some(choices) = p["choices"].as_array() {
                            let c_strs = choices.iter().map(|c| c.as_str().unwrap());
                            quote! { vec![ #(#c_strs.to_string()),* ] }
                        } else {
                            quote! { vec![] }
                        };

                        param_tokens.push(quote! {
                            karbeat_plugin_types::ParameterSpec {
                                id: #p_id,
                                name: #p_name.to_string(),
                                group: #p_group.to_string(),
                                default_value: #default_val,
                                min: #min,
                                max: #max,
                                step: #step,
                                value_type: karbeat_plugin_types::ParamType::#val_type_ident,
                                choices: #choices_tokens,
                            }
                        });
                    }
                }

                let abs_path_str = path.to_str().unwrap();
                file_trackers.push(quote! {
                    const _: &[u8] = include_bytes!(#abs_path_str);
                });

                let insert_stmt = quote! {
                    let specs = vec![ #(#param_tokens),* ];
                    let factory: Box<dyn Fn() -> Box<_> + Send + Sync> = Box::new(|| Box::new( <#internal_ident>::build() ));
                    
                    let registered = RegisteredPlugin {
                        name: #name.to_string(),
                        factory,
                        parameter_specs: specs,
                    };
                };

                if is_synth {
                    generator_inserts.push(quote! {
                        #insert_stmt
                        registry.generators.insert(#id, registered);
                    });
                } else {
                    effect_inserts.push(quote! {
                        #insert_stmt
                        registry.effects.insert(#id, registered);
                    });
                }
            }
        }
    };

    process_directory(&synths_path, true);
    process_directory(&effects_path, false);

    // 2. Assemble the final output, now including the constants!
    let expanded = quote! {
        // Automatically inject the compiled constants
        #(#associated_constants)*

        pub fn new_with_defaults() -> Self {
            let mut registry = Self::new();
            
            // Inject file trackers to ensure macro hygiene and hot-reloading
            #(#file_trackers)*

            // Inject the dynamic bindings
            #(#generator_inserts)*
            #(#effect_inserts)*

            registry
        }
    };

    TokenStream::from(expanded)
}