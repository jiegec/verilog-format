use super::lexer::Token;
use std::collections::BTreeSet;
use std::fmt::{Error, Write};

pub fn printer(text: &str, mut lexer: logos::Lexer<Token, &str>) -> Result<String, Error> {
    let mut result = String::new();
    let mut tab_level = 0;
    let mut upd_tab_level = 0;
    let mut new_line = true;
    let mut last_post_space = false;
    let mut last_token = Token::Error;
    loop {
        let token = &lexer.token;
        if let Token::TokenEnd = token {
            break;
        } else if let Token::Error = token {
            eprintln!("Unknown token {:#?}", lexer.slice());
            break;
        }

        // Tab level calculation
        match token {
            Token::Begin | Token::LParen | Token::LBraces => {
                tab_level += 1;
            }
            Token::Module => {
                upd_tab_level += 1;
            }
            Token::End | Token::EndModule | Token::EndGenerate | Token::RParen | Token::RBraces => {
                tab_level -= 1;
            }
            _ => {}
        }
        if new_line {
            for _ in 0..tab_level {
                write!(result, "    ")?;
            }
        }

        if upd_tab_level != 0 {
            tab_level += upd_tab_level;
            upd_tab_level = 0;
        }

        if !new_line {
            match (last_token, token) {
                (Token::LParen, _)
                | (_, Token::RParen)
                | (Token::LBracket, _)
                | (_, Token::RBracket)
                | (Token::Number, Token::Colon)
                | (Token::Colon, Token::Number)
                | (Token::OpNot, _)
                | (_, Token::Semicolon)
                | (Token::Directive, Token::Number)
                | (_, Token::Comma) => {}
                _ => {
                    write!(result, " ")?;
                }
            }
        }

        write!(result, "{}", lexer.slice())?;

        if let Token::Comment = token {
            new_line = true;
        } else {
            new_line = false;
        }

        match token {
            Token::Semicolon | Token::Begin | Token::End | Token::Comma | Token::EndGenerate => {
                new_line = true;
                write!(result, "\n")?;
            }
            _ => {}
        }
        last_token = token.clone();
        lexer.advance();
    }

    return Ok(result);
}
