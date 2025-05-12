use std::io::{self, Write};

/*
process stdin -> lsp_in
sock -> lsp_in

process

*/

fn main() -> io::Result<()> {
    let mut stdin = io::stdin().lines();
    let mut stdout = io::stdout();
    let mut stderr = io::stderr();
    eprintln!("Starting...");

    while let Some(Ok(line)) = stdin.next() {
        stdout.write_all(line.as_bytes())?;
        stderr.write_all(line.as_bytes())?;
    }

    Ok(())
}
