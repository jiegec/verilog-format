use super::lexer::Token;
use super::printer;
use logos::Logos;

#[test]
fn test_encoder() {
    let text = include_str!("../tests/Encoder.sv");
    let lexer = Token::lexer(text);
    print!("{}", printer::printer(text, lexer).unwrap());
}

#[test]
fn test_port() {
    let text = include_str!("../tests/port.sv");
    let lexer = Token::lexer(text);
    print!("{}", printer::printer(text, lexer).unwrap());
}
