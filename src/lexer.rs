use nom::{
    branch::alt, bytes::complete::tag, character::complete::line_ending, combinator::map,
    error::ErrorKind, multi::many0, multi::many1, IResult,
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

fn compiler_directives(input: &str) -> IResult<&str, ParsedToken> {
    // 19. Compiler directives
    let re = Regex::new(r"^`(celldefine|default_nettype|define|else|elsif|endcelldefine|endif|ifdef|ifndef|include|line|nounconnected_drive|resetall|timescale|unconnected_drive|undef).*").unwrap();
    if let Some(matches) = re.find(input) {
        let res = input.split_at(matches.end());
        Ok((res.1, (res.0, Token::CompilerDirective)))
    } else {
        Err(nom::Err::Error((input, ErrorKind::RegexpMatches)))
    }
}

fn directives(input: &str) -> IResult<&str, ParsedToken> {
    let re = Regex::new(r"^`[a-zA-Z0-9_]+").unwrap();
    if let Some(matches) = re.find(input) {
        let res = input.split_at(matches.end());
        Ok((res.1, (res.0, Token::Directive)))
    } else {
        Err(nom::Err::Error((input, ErrorKind::RegexpMatches)))
    }
}

fn comment(input: &str) -> IResult<&str, ParsedToken> {
    let re = Regex::new(r"^//.*").unwrap();
    if let Some(matches) = re.find(input) {
        let res = input.split_at(matches.end());
        Ok((res.1, (res.0, Token::Comment)))
    } else {
        Err(nom::Err::Error((input, ErrorKind::RegexpMatches)))
    }
}

fn number(input: &str) -> IResult<&str, ParsedToken> {
    let re = Regex::new(r"^(([1-9][0-9_]*)?'[dDbBoOhH])?[0-9a-fA-F]+").unwrap();
    if let Some(matches) = re.find(input) {
        let res = input.split_at(matches.end());
        Ok((res.1, (res.0, Token::Number)))
    } else {
        Err(nom::Err::Error((input, ErrorKind::RegexpMatches)))
    }
}

fn identifier(input: &str) -> IResult<&str, ParsedToken> {
    let re = Regex::new(r"^[a-zA-Z$_][a-zA-Z0-9$_]*").unwrap();
    if let Some(matches) = re.find(input) {
        let res = input.split_at(matches.end());
        Ok((res.1, (res.0, Token::Identifier)))
    } else {
        Err(nom::Err::Error((input, ErrorKind::RegexpMatches)))
    }
}

fn string(input: &str) -> IResult<&str, ParsedToken> {
    let re = Regex::new("^\"[^\"]*\"").unwrap();
    if let Some(matches) = re.find(input) {
        let res = input.split_at(matches.end());
        Ok((res.1, (res.0, Token::Identifier)))
    } else {
        Err(nom::Err::Error((input, ErrorKind::RegexpMatches)))
    }
}

fn newline(input: &str) -> IResult<&str, ParsedToken> {
    map(line_ending, |p| (p, Token::Newline))(input)
}

fn keyword(input: &str) -> IResult<&str, ParsedToken> {
    let (input, res) = alt((
        map(tag("module"), |p| (p, Token::Module)),
        map(tag("endmodule"), |p| (p, Token::EndModule)),
        map(tag("generate"), |p| (p, Token::Generate)),
        map(tag("endgenerate"), |p| (p, Token::EndGenerate)),
        map(tag("task"), |p| (p, Token::Task)),
        map(tag("endtask"), |p| (p, Token::EndTask)),
        map(tag("begin"), |p| (p, Token::Begin)),
        map(tag("end"), |p| (p, Token::End)),
        map(tag("initial"), |p| (p, Token::Initial)),
        map(tag("wire"), |p| (p, Token::Wire)),
        map(tag("reg"), |p| (p, Token::Reg)),
        map(tag("logic"), |p| (p, Token::Logic)),
        map(tag("input"), |p| (p, Token::Input)),
        map(tag("output"), |p| (p, Token::Output)),
        map(tag("always_comb"), |p| (p, Token::AlwaysComb)),
        map(tag("always_ff"), |p| (p, Token::AlwaysFf)),
        map(tag("always"), |p| (p, Token::Always)),
        map(tag("if"), |p| (p, Token::If)),
        map(tag("else"), |p| (p, Token::Else)),
    ))(input)?;

    // handle variables named 'reg_abc'
    if let Some('_') = input.chars().next() {
        Err(nom::Err::Error((input, ErrorKind::Alt)))
    } else {
        Ok((input, res))
    }
}

fn delimiter(input: &str) -> IResult<&str, ParsedToken> {
    alt((
        map(tag("#"), |p| (p, Token::Sharp)),
        map(tag("("), |p| (p, Token::LParen)),
        map(tag(")"), |p| (p, Token::RParen)),
        map(tag("["), |p| (p, Token::LBracket)),
        map(tag("]"), |p| (p, Token::RBracket)),
        map(tag("{"), |p| (p, Token::LBraces)),
        map(tag("}"), |p| (p, Token::RBraces)),
        map(tag(":"), |p| (p, Token::Colon)),
        map(tag(","), |p| (p, Token::Comma)),
        map(tag(";"), |p| (p, Token::Semicolon)),
        map(tag("."), |p| (p, Token::Dot)),
    ))(input)
}

fn operator(input: &str) -> IResult<&str, ParsedToken> {
    alt((
        map(tag("=="), |p| (p, Token::OpEqualTo)),
        map(tag("="), |p| (p, Token::OpEqual)),
        map(tag("@"), |p| (p, Token::OpAt)),
        map(tag("/"), |p| (p, Token::OpDivide)),
        map(tag("-"), |p| (p, Token::OpMinus)),
        map(tag("!"), |p| (p, Token::OpNot)),
        map(tag("+"), |p| (p, Token::OpPlus)),
        map(tag("~"), |p| (p, Token::OpInvert)),
        map(tag("*"), |p| (p, Token::OpMultiply)),
        map(tag("?"), |p| (p, Token::OpChoice)),
        map(tag("<="), |p| (p, Token::OpAssign)),
        map(tag("<"), |p| (p, Token::OpLessThan)),
        map(tag(">="), |p| (p, Token::OpGreaterEqual)),
        map(tag(">"), |p| (p, Token::OpGreaterThan)),
        map(tag("&&"), |p| (p, Token::OpAnd)),
    ))(input)
}

fn token(input: &str) -> IResult<&str, ParsedToken> {
    let (input, _) = many0(alt((tag(" "), tag("\t"))))(input)?;
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
