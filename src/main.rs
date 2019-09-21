#[macro_use]
extern crate clap;

use clap::{App, AppSettings, Arg};
use std::fs::read_to_string;

pub mod lexer;
pub mod printer;
mod test;

fn main() {
    let args = App::new("verilog-format")
        .about("Verilog formatter")
        .author(crate_authors!())
        .version(crate_version!())
        .setting(AppSettings::ColoredHelp)
        .arg(
            Arg::with_name("file")
                .short("f")
                .long("file")
                .value_name("file")
                .help("Input file")
                .required(true)
                .takes_value(true),
        )
        .get_matches();

    let file = args.value_of("file").unwrap();
    let text = read_to_string(file).unwrap();
    let result = lexer::tokens(&text).unwrap();
    let printed_text = printer::printer(result.1).unwrap();
    println!("{}", printed_text);
}
