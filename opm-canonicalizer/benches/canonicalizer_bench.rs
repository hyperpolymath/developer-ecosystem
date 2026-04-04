// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// canonicalizer_bench.rs — Criterion benchmarks for opm-canonicalizer.

use criterion::{black_box, criterion_group, criterion_main, Criterion};
use opm_canonicalizer::canonicalize;

fn bench_null(c: &mut Criterion) {
    c.bench_function("canonicalize_null", |b| {
        b.iter(|| canonicalize(black_box("null")).unwrap())
    });
}

fn bench_simple_object(c: &mut Criterion) {
    let input = r#"{"z":3,"a":1,"m":2}"#;
    c.bench_function("canonicalize_simple_object", |b| {
        b.iter(|| canonicalize(black_box(input)).unwrap())
    });
}

fn bench_nested_object(c: &mut Criterion) {
    let input = r#"{"z":{"d":4,"c":3},"a":{"b":2,"a":1},"m":[3,1,2]}"#;
    c.bench_function("canonicalize_nested_object", |b| {
        b.iter(|| canonicalize(black_box(input)).unwrap())
    });
}

fn bench_array_of_ints(c: &mut Criterion) {
    let input = "[100,99,98,97,96,95,94,93,92,91,90]";
    c.bench_function("canonicalize_array_of_ints", |b| {
        b.iter(|| canonicalize(black_box(input)).unwrap())
    });
}

fn bench_string_with_escapes(c: &mut Criterion) {
    let input = r#""hello\nworld\ttab\"quote\\backslash""#;
    c.bench_function("canonicalize_string_with_escapes", |b| {
        b.iter(|| canonicalize(black_box(input)).unwrap())
    });
}

criterion_group!(
    benches,
    bench_null,
    bench_simple_object,
    bench_nested_object,
    bench_array_of_ints,
    bench_string_with_escapes,
);
criterion_main!(benches);
