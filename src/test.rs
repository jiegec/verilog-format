use super::lexer;
use super::printer;
use std::fs::read_to_string;

#[cfg(test)]
use pretty_assertions::assert_eq;

#[test]
fn test_files() {
    for (orig, fmt) in &[
        ("./tests/Encoder.sv", "./tests/Encoder.fmt.sv"),
        ("./tests/comment.sv", "./tests/comment.fmt.sv"),
    ] {
        let text = read_to_string(orig).unwrap();
        let result = lexer::tokens(&text).unwrap();
        let printed_text = printer::printer(result.1).unwrap();
        let expected_text = read_to_string(fmt).unwrap();
        if printed_text != expected_text {
            println!("Expected:\n{}", expected_text);
            println!("Actual:\n{}", printed_text);
        }
        assert_eq!(
            printed_text.split("\n").collect::<Vec<_>>(),
            expected_text.split("\n").collect::<Vec<_>>()
        );
    }
}
