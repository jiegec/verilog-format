use nom::{
    branch::alt,
    bytes::complete::tag,
    character::complete::{line_ending, space1},
    combinator::map,
    error::ErrorKind,
    multi::{many0, many1},
    IResult,
};
use regex::Regex;

#[derive(Debug, PartialEq, Clone)]
pub enum Token {
    // Types
    Number,
    Identifier,
    String,
    CompilerDirective,
    Directive,
    Comment,
    Newline,

    // Keywords
    Module,
    EndModule,
    Begin,
    End,
    Parameter,
    Generate,
    EndGenerate,
    Task,
    EndTask,
    Initial,
    Input,
    Output,
    Assign,
    Posedge,
    Wire,
    Reg,
    Logic,
    If,
    Else,
    Always,
    AlwaysComb,
    AlwaysFf,

    // Delimiter
    Sharp,
    LParen, // ()
    RParen,
    LBracket, // []
    RBracket,
    LBraces, // {}
    RBraces,
    Colon,
    Comma,
    Semicolon,
    Dot,

    // Operators
    OpEqual,
    OpAt,
    OpDivide,
    OpMinus,
    OpNot,
    OpPlus,
    OpInvert,
    OpMultiply,
    OpChoice,
    OpEqualTo,
    OpAssign,
    OpLessThan,
    OpGreaterThan,
    OpLeftShift,
    OpGreaterEqual,
    OpAnd,

    None,
}

pub type ParsedToken<'a> = (&'a str, Token);

macro_rules! parse_one {
    ( fn: $fn:ident => $token:ident ) => {{
        map($fn, |p| (p, Token::$token))
    }};
    ( op: $op:literal => $token:ident ) => {{
        map(tag($op), |p| (p, Token::$token))
    }};
    ( word: $word:literal => $token:ident ) => {{
        fn foo(input: &str) -> IResult<&str, ParsedToken> {
            let (rest, o1) = tag($word)(input)?;
            // handle identifiers like 'reg_abc'
            match rest.chars().next() {
                Some(c) if c == '_' || c.is_alphanumeric() => {
                    Err(nom::Err::Error((input, ErrorKind::Tag)))
                }
                _ => Ok((rest, (o1, Token::$token))),
            }
        }
        foo
    }};
    ( regex: $regex:literal => $token:ident ) => {{
        fn foo(input: &str) -> IResult<&str, ParsedToken> {
            lazy_static! {
                static ref RE: Regex = Regex::new($regex).unwrap();
            }
            if let Some(matches) = RE.find(input) {
                let (matched, rest) = input.split_at(matches.end());
                Ok((rest, (matched, Token::$token)))
            } else {
                Err(nom::Err::Error((input, ErrorKind::RegexpMatches)))
            }
        }
        foo
    }};
}

macro_rules! parse_token {
    ( $type:ident : $arg:tt => $token:ident ) => {
        parse_one!($type: $arg => $token)
    };
    ( $( $type:ident : $arg:tt => $token:ident ),* $(,)? ) => {
        ( $( parse_one!($type: $arg => $token) ),* )
    };
}

fn keyword(input: &str) -> IResult<&str, ParsedToken> {
    alt(parse_token!(
        word: "module" => Module,
        word: "endmodule" => EndModule,
        word: "generate" => Generate,
        word: "endgenerate" => EndGenerate,
        word: "task" => Task,
        word: "endtask" => EndTask,
        word: "begin" => Begin,
        word: "end" => End,
        word: "initial" => Initial,
        word: "wire" => Wire,
        word: "reg" => Reg,
        word: "logic" => Logic,
        word: "input" => Input,
        word: "output" => Output,
        word: "always_comb" => AlwaysComb,
        word: "always_ff" => AlwaysFf,
        word: "always" => Always,
        word: "if" => If,
        word: "else" => Else,
    ))(input)
}

fn delimiter(input: &str) -> IResult<&str, ParsedToken> {
    alt(parse_token!(
        op: "#" => Sharp,
        op: "(" => LParen,
        op: ")" => RParen,
        op: "[" => LBracket,
        op: "]" => RBracket,
        op: "{" => LBraces,
        op: "}" => RBraces,
        op: ":" => Colon,
        op: "," => Comma,
        op: ";" => Semicolon,
        op: "." => Dot,
    ))(input)
}

fn operator(input: &str) -> IResult<&str, ParsedToken> {
    alt(parse_token!(
        op: "==" => OpEqualTo,
        op: "=" => OpEqual,
        op: "@" => OpAt,
        op: "/" => OpDivide,
        op: "-" => OpMinus,
        op: "!" => OpNot,
        op: "+" => OpPlus,
        op: "~" => OpInvert,
        op: "*" => OpMultiply,
        op: "?" => OpChoice,
        op: "<=" => OpAssign,
        op: "<" => OpLessThan,
        op: ">=" => OpGreaterEqual,
        op: ">" => OpGreaterThan,
        op: "&&" => OpAnd,
    ))(input)
}

fn token(input: &str) -> IResult<&str, ParsedToken> {
    let (input, _) = many0(space1)(input)?;

    let compiler_directives = parse_token!(regex: r"^`(celldefine|default_nettype|define|else|elsif|endcelldefine|endif|ifdef|ifndef|include|line|nounconnected_drive|resetall|timescale|unconnected_drive|undef).*"
        => CompilerDirective);
    let directives = parse_token!(regex: r"^`[a-zA-Z0-9_]+" => Directive);
    let comment = parse_token!(regex: r"^//.*" => Comment);
    let number = parse_token!(regex: r"^(([1-9][0-9_]*)?'[dDbBoOhH])?[0-9a-fA-F]+" => Number);
    let identifier = parse_token!(regex: r"^[a-zA-Z$_][a-zA-Z0-9$_]*" => Identifier);
    let string = parse_token!(regex: "^\"[^\"]*\"" => String);
    let newline = parse_token!(fn: line_ending => Newline);

    alt((
        keyword,
        string,
        delimiter,
        newline,
        identifier,
        number,
        comment,
        operator,
        compiler_directives,
        directives,
    ))(input)
}

pub fn tokens(input: &str) -> IResult<&str, Vec<ParsedToken>> {
    many1(token)(input)
}
