#[macro_use]
extern crate lalrpop_util;

mod test;
mod ast;

lalrpop_mod!(pub parser);

fn main() {
}
