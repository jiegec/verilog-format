use super::lexer::{ParsedToken, Token};
use std::fmt::{Error, Write};

pub fn printer(tokens: Vec<ParsedToken>) -> Result<String, Error> {
    let mut result = String::new();
    let mut tab_level = 0;
    let mut last_token = Token::None;
    let mut last_text_token = Token::None;
    let mut in_port_definition = false;
    for (slice, ref token) in tokens {
        if let Token::Module = token {
            in_port_definition = true;
        } else if let Token::Semicolon = token {
            in_port_definition = false;
        }

        // Tab level calculation
        match token {
            Token::Begin | Token::LBraces => {
                tab_level += 1;
            }
            Token::LParen => {
                if !in_port_definition {
                    tab_level += 1;
                }
            }
            Token::RParen => {
                if !in_port_definition {
                    tab_level -= 1;
                }
            }
            Token::Module => {
                tab_level += 1;
            }
            Token::End | Token::EndModule | Token::EndGenerate | Token::RBraces => {
                tab_level -= 1;
            }
            _ => {}
        }

        let new_line = match (&last_text_token, token) {
            (_, Token::Newline) => false,
            (Token::Begin, _) => true,
            (_, Token::End) => true,
            (Token::End, Token::Else) => false,
            (Token::End, _) => true,
            (Token::Comma, _) => true,
            (Token::Semicolon, _) => true,
            (Token::LParen, _) => {
                if in_port_definition {
                    true
                } else {
                    false
                }
            },
            (Token::Identifier, Token::RParen) => false,
            _ => false,
        };

        if new_line {
            write!(result, "\n")?;
            for _ in 0..tab_level {
                write!(result, "    ")?;
            }
        }

        if !new_line {
            match (&last_text_token, token) {
                (Token::LParen, _)
                | (_, Token::RParen)
                | (Token::LBracket, _)
                | (_, Token::RBracket)
                | (Token::Number, Token::Colon)
                | (Token::Colon, Token::Number)
                | (Token::OpNot, _)
                | (_, Token::Semicolon)
                | (Token::Directive, Token::Number)
                | (Token::None, _)
                | (Token::Newline, _)
                | (_, Token::Newline)
                | (_, Token::Comma) => {}
                _ => {
                    write!(result, " ")?;
                }
            }
        }

        if let Token::Newline = token {
            if let Token::Newline = last_token {
                write!(result, "{}", slice)?;
            }
        } else {
            write!(result, "{}", slice)?;
            last_text_token = token.clone();
        }

        last_token = token.clone();
    }

    return Ok(result);
}
