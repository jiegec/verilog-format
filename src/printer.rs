use super::lexer::{ParsedToken, Token};
use std::fmt::{Error, Write};

pub fn printer(tokens: Vec<ParsedToken>) -> Result<String, Error> {
    let mut result = String::new();
    let mut tab_level = 0;
    let mut upd_tab_level = 0;
    let mut paren_level = 0;
    let mut last_token = Token::None;
    let mut last_text_token = Token::None;
    let mut in_definition = false;
    for (slice, ref token) in tokens {
        // Maintain definition state
        if let Token::Module = token {
            in_definition = true;
        } else if let Token::Task = token {
            in_definition = true;
        } else if let Token::Semicolon = token {
            if in_definition {
                tab_level += 1;
            }
            in_definition = false;
        }

        // Tab level & paren level calculation
        match token {
            Token::Begin | Token::LBraces => {
                upd_tab_level += 1;
            }
            Token::LParen => {
                tab_level += 1;
                paren_level += 1;
            }
            Token::RParen => {
                tab_level -= 1;
                paren_level -= 1;
            }
            Token::End
            | Token::EndModule
            | Token::EndTask
            | Token::EndGenerate
            | Token::RBraces => {
                tab_level -= 1;
            }
            _ => {}
        }

        let new_line = match (&last_text_token, token) {
            (_, Token::Newline) => false,
            (Token::CompilerDirective, _) => true,
            (Token::Begin, _) => true,
            (_, Token::End) => true,
            (Token::End, Token::Else) => false,
            (Token::End, _) => true,
            (Token::EndTask, _) => true,
            (Token::Comma, Token::Comment) => {
                if let Token::Comma = last_token {
                    false
                } else {
                    // newline in between
                    true
                }
            }
            (Token::Comma, _) => paren_level > 0,
            (Token::Semicolon, _) => true,
            (Token::Comment, _) => true,
            (Token::LParen, Token::RParen) => false,
            (Token::LParen, _) => {
                if in_definition {
                    true
                } else {
                    false
                }
            }
            (Token::Identifier, Token::RParen) => false,
            _ => false,
        };

        //println!("{:#?} {:?} {} {}", token, slice, tab_level, new_line);
        if new_line {
            write!(result, "\n")?;
            for _ in 0..tab_level {
                write!(result, "    ")?;
            }
        }
        if upd_tab_level != 0 {
            tab_level += upd_tab_level;
            upd_tab_level = 0;
        }

        if !new_line {
            match (&last_text_token, token) {
                (Token::LParen, _)
                | (_, Token::RParen)
                | (Token::Identifier, Token::LBracket)
                | (Token::Sharp, Token::Number)
                | (Token::LBracket, _)
                | (Token::LBraces, _)
                | (_, Token::RBraces)
                | (_, Token::RBracket)
                | (Token::Number, Token::Colon)
                | (Token::Colon, Token::Number)
                | (Token::OpNot, _)
                | (_, Token::Semicolon)
                | (Token::Directive, Token::Number)
                | (Token::None, _)
                | (Token::Newline, _)
                | (Token::CompilerDirective, _)
                | (Token::Comment, _)
                | (Token::Dot, _)
                | (_, Token::Dot)
                | (_, Token::CompilerDirective)
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
