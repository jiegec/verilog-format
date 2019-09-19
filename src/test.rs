use super::lexer;
use super::printer;
#[cfg(test)]
use pretty_assertions::assert_eq;

#[test]
fn test_encoder() {
    let text = include_str!("../tests/Encoder.sv");
    let result = lexer::tokens(text).unwrap();
    let printed_text = printer::printer(result.1).unwrap();
    let expected_text = include_str!("../tests/Encoder.fmt.sv");
    if printed_text != expected_text {
        println!("Expected:\n{}", expected_text);
        println!("Actual:\n{}", printed_text);
    }
    assert_eq!(printed_text.split("\n").collect::<Vec<_>>(), expected_text.split("\n").collect::<Vec<_>>());
}
