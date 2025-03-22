use clap::{crate_authors, crate_version, Arg, Command};
use std::fs::read_to_string;

pub mod lexer;
pub mod printer;
#[cfg(test)]
mod test;

fn main() {
    let args = Command::new("verilog-format")
        .about("Verilog formatter")
        .author(crate_authors!())
        .version(crate_version!())
        .arg(
            Arg::new("file")
                .short('f')
                .long("file")
                .value_name("file")
                .help("Input file")
                .required(true)
                .num_args(1)
        )
        .get_matches();

    let file: &String = args.get_one("file").unwrap();
    let text = read_to_string(file).unwrap();
    let result = lexer::tokens(&text).unwrap();
    let printed_text = printer::printer(result.1).unwrap();
    println!("{}", printed_text);
}
