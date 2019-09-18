use super::parser;

#[test]
fn test_encoder() {
    parser::ModuleParser::new().parse(include_str!("../tests/Encoder.sv")).unwrap();
}
