#!/usr/bin/env nix
//! ```cargo
//! [dependencies]
//! time = "0.1.25"
//! ```
/*
#!nix shell nixpkgs#rustc nixpkgs#rust-script nixpkgs#cargo --command rust-script
*/
fn main() {
    for argument in std::env::args().skip(1) {
        println!("{}", argument);
    }
    println!("{}", std::env::var("HOME").expect(""));
    println!("{}", time::now().rfc822z());
}
