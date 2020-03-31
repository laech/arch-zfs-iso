use std::{
    fs,
    io::{self, ErrorKind},
    path::Path,
};

pub fn remove_file_if_exists(path: impl AsRef<Path>) -> io::Result<()> {
    ignore_not_found_error(path, fs::remove_file)
}

pub fn remove_dir_all_if_exists(path: impl AsRef<Path>) -> io::Result<()> {
    ignore_not_found_error(path, fs::remove_dir_all)
}

fn ignore_not_found_error<P: AsRef<Path>, R>(
    path: P,
    action: impl FnOnce(P) -> io::Result<R>,
) -> io::Result<()> {
    match action(path) {
        Err(e) if e.kind() != ErrorKind::NotFound => Err(e),
        _ => Ok(()),
    }
}
