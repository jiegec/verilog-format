#[macro_use]
extern crate criterion;

extern crate verilog_format;

use criterion::Criterion;
use criterion::black_box;

use verilog_format::lexer;
use verilog_format::printer;
use std::fs::read_to_string;

fn test(testcase: &str) {
    let input_path = format!("./tests/{}.sv", testcase);
    let expected_path = format!("./tests/{}.fmt.sv", testcase);
    let text = read_to_string(input_path).unwrap();
    let result = lexer::tokens(&text).unwrap();
    let printed_text = printer::printer(result.1).unwrap();
    let expected_text = read_to_string(expected_path).unwrap();
    assert_eq!(printed_text, expected_text);
}

fn criterion_benchmark(c: &mut Criterion) {
    c.bench_function("format test_cpu.sv", |b| b.iter(|| test(black_box("test_cpu"))));
}

criterion_group!(benches, criterion_benchmark);
criterion_main!(benches);