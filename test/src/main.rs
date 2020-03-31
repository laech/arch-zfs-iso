use crate::vm::Vm;
use std::error::Error;
use std::process::exit;
use std::{
    env::args,
    io::{self, ErrorKind},
    path::Path,
};

mod fs;
mod logger;
mod scancode;
mod vm;

fn main() -> Result<(), Box<dyn Error>> {
    let args = args();
    if args.len() != 2 {
        eprintln!("Usage: <this-program> <path-to-iso>");
        exit(1);
    }

    log::set_logger(&logger::Logger {})?;
    log::set_max_level(log::LevelFilter::Debug);

    test(&args.last().unwrap())?;
    log::info!("PASSED");
    Ok(())
}

fn test(iso: impl AsRef<Path>) -> io::Result<()> {
    let vm = Vm::build("arch-zfs-iso-test")?;
    vm.attach_iso(iso)?;
    vm.run()?;
    test_zfs_repo_key_is_signed(&vm)?;
    test_zfs_is_installed(&vm)?;
    vm.destroy()?;
    Ok(())
}

fn test_zfs_repo_key_is_signed(vm: &Vm) -> io::Result<()> {
    let output = vm.read_command("pacman-key --list-keys F75D9D76")?;
    if output.contains("[  full  ] ArchZFS Bot <buildbot@archzfs.com>")
        && output.contains("[  full  ] ArchZFS Bot <bot@archzfs.com>")
    {
        return Ok(());
    }
    Err(io::Error::new(
        ErrorKind::Other,
        format!("ArchZFS repo key not signed:\n{}", output),
    ))
}

fn test_zfs_is_installed(vm: &Vm) -> io::Result<()> {
    let output = vm.read_command("zpool list")?;
    if output.trim() == "no pools available" {
        return Ok(());
    }
    Err(io::Error::new(
        ErrorKind::Other,
        format!("Unexpected output:\n{}", output),
    ))
}
