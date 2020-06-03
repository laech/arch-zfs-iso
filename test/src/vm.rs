use crate::scancode;
use rand::random;
use std::{
    env::temp_dir,
    fs,
    io::{self, ErrorKind},
    path::{Path, PathBuf},
    process::Command,
    thread::sleep,
    time::Duration,
};

const SSH_IP: &str = "127.0.0.1";
const SSH_PORT: &str = "22222";

pub struct Vm {
    name: String,
    directory: PathBuf,
    private_key: PathBuf,
    public_key: PathBuf,
}

impl Vm {
    pub fn build(vm: &str) -> io::Result<Vm> {
        let dir = temp_dir().join(format!("test-{}", random::<u32>()));
        let private_key = dir.join("id_test");
        let public_key = dir.join("id_test.pub");

        fs::create_dir(&dir)?;
        let result = {
            delete_vm_if_exists(vm)?;
            vboxmanage_createvm(vm)?;
            vboxmanage_modifyvm_memory(vm)?;
            vboxmanage_config_hdd(vm, &dir)?;
            vboxmanage_config_ssh_port_forwarding(vm)?;
            Ok(Vm {
                name: vm.to_owned(),
                directory: dir.clone(),
                private_key,
                public_key,
            })
        };

        if result.is_err() {
            delete_vm_if_exists(vm)?;
            fs::remove_dir_all(&dir)?;
        }

        result
    }

    pub fn destroy(&self) -> io::Result<()> {
        vec![
            delete_vm_if_exists(&self.name),
            crate::fs::remove_dir_all_if_exists(&self.directory),
        ]
        .into_iter()
        .filter(|x| x.is_err())
        .next()
        .unwrap_or_else(|| Ok(()))
    }

    pub fn run(&self) -> io::Result<()> {
        gen_ssh_keypair(&self.private_key, &self.public_key)?;
        let public_key_str = String::from_utf8(fs::read(&self.public_key)?)
            .map(|x| x.trim().to_owned())
            .map_err(|e| io::Error::new(ErrorKind::Other, e))?;

        vboxmanage_startvm(&self.name)?;
        sleep(Duration::from_secs(10));

        send_keys(&self.name, "")?;
        wait_for_started(&self.name)?;

        send_keys(&self.name, "mkdir -p ~/.ssh")?;
        send_keys(
            &self.name,
            &format!("echo '{}' > ~/.ssh/authorized_keys", public_key_str),
        )?;
        send_keys(&self.name, "systemctl start sshd")?;

        // Wait for SSH to be ready
        sleep(Duration::from_secs(6));
        Ok(())
    }

    pub fn read_command(&self, command: &str) -> io::Result<String> {
        Command::new("ssh")
            .arg("-q")
            .arg("-i")
            .arg(&*self.private_key)
            .args(&["-o", "PasswordAuthentication=no"])
            .args(&["-o", "UserKnownHostsFile=/dev/null"])
            .args(&["-o", "StrictHostKeyChecking=no"])
            .args(&["-p", SSH_PORT])
            .args(&[&format!("root@{}", SSH_IP), command])
            .read(true)
    }

    pub fn attach_iso(&self, iso: impl AsRef<Path>) -> io::Result<()> {
        vboxmanage()
            .args(&["storagectl", &self.name])
            .args(&["--name", "IDE"])
            .args(&["--add", "ide"])
            .run()?;
        vboxmanage()
            .args(&["storageattach", &self.name])
            .args(&["--storagectl", "IDE"])
            .args(&["--port", "0"])
            .args(&["--device", "0"])
            .args(&["--type", "dvddrive"])
            .arg("--medium")
            .arg(iso.as_ref())
            .run()
    }
}

fn send_keys(vm: &str, command: &str) -> io::Result<()> {
    let mut codes = Vec::new();
    for c in format!("{}\n", command).chars() {
        codes.append(&mut scancode::get(c).ok_or_else(|| {
            io::Error::new(ErrorKind::Other, format!("No scancode for char: {}", c))
        })?);
    }
    vboxmanage()
        .args(&["controlvm", vm, "keyboardputscancode"])
        .args(codes)
        .run()
}

fn gen_ssh_keypair(private_key: impl AsRef<Path>, public_key: impl AsRef<Path>) -> io::Result<()> {
    crate::fs::remove_file_if_exists(private_key.as_ref())?;
    crate::fs::remove_file_if_exists(public_key.as_ref())?;
    Command::new("ssh-keygen")
        .args(&["-t", "ed25519"])
        .arg("-f")
        .arg(private_key.as_ref())
        .args(&["-N", ""])
        .arg("-q")
        .run()
}

fn wait_for_started(vm: &str) -> io::Result<()> {
    for i in 0..8 {
        log::info!("Booting ({})...", i);

        let ok = vboxmanage()
            .args(&["showvminfo", vm, "--log", "0"])
            .read(false)?
            .contains("DHCP offered IP address");

        // Wait for rest to initialize, even when log entry found
        sleep(Duration::from_secs(15));
        if ok {
            return Ok(());
        }
    }
    Err(io::Error::new(
        ErrorKind::TimedOut,
        format!("Timed out waiting for VM '{}' to be started", vm),
    ))
}

fn vboxmanage_createvm(vm: &str) -> io::Result<()> {
    vboxmanage()
        .arg("createvm")
        .args(&["--name", vm])
        .args(&["--ostype", "ArchLinux_64"])
        .args(&["--register"])
        .run()
}

fn vboxmanage_modifyvm_memory(vm: &str) -> io::Result<()> {
    vboxmanage()
        .args(&["modifyvm", vm])
        .args(&["--memory", "1024"])
        .run()
}

fn vboxmanage_config_ssh_port_forwarding(vm: &str) -> io::Result<()> {
    vboxmanage()
        .args(&["modifyvm", vm])
        .args(&[
            "--natpf1",
            &format!("guestssh,tcp,{},{},,22", SSH_IP, SSH_PORT),
        ])
        .run()
}

fn vboxmanage_config_hdd(vm: &str, dir: impl AsRef<Path>) -> io::Result<()> {
    let medium = dir.as_ref().join(format!("{}.vdi", vm));
    vboxmanage()
        .args(&["storagectl", vm])
        .args(&["--name", "SATA"])
        .args(&["--add", "sata"])
        .run()?;
    vboxmanage()
        .args(&["createmedium", "disk"])
        .arg("--filename")
        .arg(&medium)
        .args(&["--format", "VDI"])
        .args(&["--size", "1024"])
        .run()?;
    vboxmanage()
        .args(&["storageattach", vm])
        .args(&["--storagectl", "SATA"])
        .args(&["--port", "0"])
        .args(&["--device", "0"])
        .args(&["--type", "hdd"])
        .arg("--medium")
        .arg(&medium)
        .run()
}

fn delete_vm_if_exists(vm: &str) -> io::Result<()> {
    if vboxmanage_list_runningvms()?.contains(&vm.to_owned()) {
        vboxmanage_controlvm_poweroff(vm, Some(Duration::from_secs(2)))?;
    }
    if vboxmanage_list_vms()?.contains(&vm.to_owned()) {
        vboxmanage_unregistervm_delete(vm)?;
    }
    Ok(())
}

fn vboxmanage_startvm(vm: &str) -> io::Result<()> {
    vboxmanage().args(&["startvm", vm]).run()
}

fn vboxmanage_controlvm_poweroff(vm: &str, wait_duration: Option<Duration>) -> io::Result<()> {
    vboxmanage().args(&["controlvm", vm, "poweroff"]).run()?;
    if let Some(duration) = wait_duration {
        sleep(duration);
    }
    Ok(())
}

fn vboxmanage_unregistervm_delete(vm: &str) -> io::Result<()> {
    vboxmanage().args(&["unregistervm", vm, "--delete"]).run()
}

fn vboxmanage_list_vms() -> io::Result<Vec<String>> {
    vboxmanage()
        .args(&["list", "vms"])
        .read(true)
        .map(|s| parse_vm_names(&s[..]))
}

fn vboxmanage_list_runningvms() -> io::Result<Vec<String>> {
    vboxmanage()
        .args(&["list", "runningvms"])
        .read(true)
        .map(|s| parse_vm_names(&s[..]))
}

fn vboxmanage() -> Command {
    Command::new("vboxmanage")
}

fn parse_vm_names(content: &str) -> Vec<String> {
    content
        .lines()
        .filter_map(|line| parse_vm_name(line))
        .collect()
}

// Example output of listing VMs:
// "default" {f052aee7-9dab-44ca-9797-f2e429a72ce0}
// "Arch" {f6a2a54c-d485-4cf2-929e-82f4594aca0a}
fn parse_vm_name(line: &str) -> Option<String> {
    if line.is_empty() || line.as_bytes()[0] as char != '"' {
        return None;
    }
    if let Some(i) = line[1..].find("\" {") {
        return Some(line[1..i + 1].to_owned());
    }
    None
}

trait CommandExt {
    fn read(&mut self, log: bool) -> io::Result<String>;

    fn run(&mut self) -> io::Result<()> {
        self.read(true).map(|_| ())
    }
}

impl CommandExt for Command {
    fn read(&mut self, log: bool) -> io::Result<String> {
        log::info!("Executing {:?}", self);

        let result = self.output()?;
        if !result.status.success() {
            return Err(io::Error::new(
                ErrorKind::Other,
                String::from_utf8_lossy(result.stderr.as_ref()),
            ));
        }

        if log && !result.stdout.is_empty() {
            log::info!(
                "Output:\n{}",
                String::from_utf8_lossy(result.stdout.as_ref())
            );
        }

        String::from_utf8(result.stdout).map_err(|err| io::Error::new(ErrorKind::Other, err))
    }
}
