use logos::Logos;
#[derive(Logos, Debug, PartialEq, Clone)]
pub enum Token {
    // Special
    #[end]
    TokenEnd,

    #[error]
    Error,

    // Types
    #[regex = "(([1-9][0-9_]*)?'[dDbBoOhH])?[0-9a-fA-F_]+(ns|ps)?"]
    Number,

    #[regex = "[a-zA-Z_][a-zA-z0-9$_]*"]
    Identifier,

    #[regex = "\"[^\"]*\""]
    String,

    #[regex = "`[a-zA-Z0-9_]+"]
    Directive,

    #[regex = "//.*\n"]
    Comment,

    // Keywords
    #[token = "module"]
    Module,

    #[token = "endmodule"]
    EndModule,

    #[token = "begin"]
    Begin,

    #[token = "end"]
    End,

    #[token = "parameter"]
    Parameter,

    #[token = "generate"]
    Generate,

    #[token = "endgenerate"]
    EndGenerate,

    #[token = "input"]
    Input,

    #[token = "output"]
    Output,

    #[token = "assign"]
    Assign,

    #[token = "posedge"]
    Posedge,

    #[token = "wire"]
    Wire,

    #[token = "reg"]
    Reg,

    #[token = "logic"]
    Logic,

    #[token = "if"]
    If,

    #[token = "else"]
    Else,

    // Delimiter
    #[token = "#"]
    Sharp,

    #[token = "("]
    LParen,

    #[token = ")"]
    RParen,

    #[token = "["]
    LBracket,

    #[token = "]"]
    RBracket,

    #[token = "{"]
    LBraces,

    #[token = "}"]
    RBraces,

    #[token = ":"]
    Colon,

    #[token = ","]
    Comma,

    #[token = ";"]
    Semicolon,

    #[token = "."]
    Dot,

    #[token = "="]
    Equal,

    #[token = "@"]
    At,

    // Operators
    #[token = "/"]
    OpDivide,

    #[token = "-"]
    OpMinus,

    #[token = "!"]
    OpNot,

    #[token = "+"]
    OpPlus,

    #[token = "~"]
    OpInvert,

    #[token = "*"]
    OpMultiply,

    #[token = "?"]
    OpChoice,

    #[token = "=="]
    OpEqual,

    #[token = "<="]
    OpAssign,

    #[token = "<"]
    OpLessThan,

    #[token = ">"]
    OpGreaterThan,

    #[token = "<<"]
    OpLeftShift,

    #[token = ">="]
    OpGreaterEqual,

    #[token = "&&"]
    OpAnd,

}
