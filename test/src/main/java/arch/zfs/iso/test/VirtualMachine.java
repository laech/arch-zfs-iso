package arch.zfs.iso.test;

import java.io.IOException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;

import static arch.zfs.iso.test.Processes.call;
import static arch.zfs.iso.test.Processes.run;
import static com.google.common.io.MoreFiles.deleteRecursively;
import static java.lang.Thread.sleep;
import static java.nio.charset.StandardCharsets.UTF_8;
import static java.nio.file.Files.*;
import static java.util.Collections.unmodifiableMap;
import static java.util.Objects.requireNonNull;

final class VirtualMachine implements AutoCloseable {

    private static final String SSH_HOST_IP = "127.0.0.1";
    private static final String SSH_HOST_PORT = "22222";

    private final String name;
    private final Path tempDirectory;
    private final Path sshPrivateKey;
    private final Path sshPublicKey;

    private VirtualMachine(String name, Path tempDirectory) {
        this.name = requireNonNull(name, "name");
        this.tempDirectory = requireNonNull(tempDirectory, "tempDirectory");
        this.sshPrivateKey = tempDirectory.resolve("id_test");
        this.sshPublicKey = Paths.get(sshPrivateKey.toString() + ".pub");
    }

    @Override
    public void close() throws Exception {
        deleteVmIfExists();
        deleteRecursively(tempDirectory);
    }

    static VirtualMachine create(String name) throws Exception {
        Path tempDirectory = createTempDirectory(name);
        try {

            VirtualMachine vm = new VirtualMachine(name, tempDirectory);
            vm.deleteVmIfExists();
            vm.createVm();
            vm.configVmRam();
            vm.configVmHdd();
            vm.configVmSshPortForwarding();
            return vm;

        } catch (Throwable e) {
            try {
                deleteRecursively(tempDirectory);
            } catch (Throwable suppressed) {
                e.addSuppressed(suppressed);
            }
            throw e;
        }
    }

    void start() throws Exception {
        generateSshKeyPair();
        startVm();
        sleep(3000);        // Wait for boot
        sendVmCommand("");  // Select default boot entry
        sleep(25000);       // Wait for boot to finish
        sendVmCommand("mkdir -p ~/.ssh");
        sendVmCommand("echo " + readSshPublicKey() + " > ~/.ssh/authorized_keys");
        sendVmCommand("systemctl start sshd");
        sleep(2000);        // Wait for sshd to start
    }

    void attachIso(Path iso) throws Exception {
        run("vboxmanage", "storagectl", name,
                "--name", "IDE",
                "--add", "ide"
        );
        run("vboxmanage", "storageattach", name,
                "--storagectl", "IDE",
                "--port", "0",
                "--device", "0",
                "--type", "dvddrive",
                "--medium", iso.toString()
        );
    }

    String execute(String command) throws Exception {
        return call("ssh",
                "-q",
                "-i", sshPrivateKey.toString(),
                "-o", "PasswordAuthentication=no",
                "-o", "UserKnownHostsFile=/dev/null",
                "-o", "StrictHostKeyChecking=no",
                "-p", SSH_HOST_PORT,
                "root@" + SSH_HOST_IP,
                command);
    }

    private String readSshPublicKey() throws IOException {
        return new String(readAllBytes(sshPublicKey), UTF_8).trim();
    }

    private void sendVmCommand(String command) throws Exception {

        List<Character> chars = new ArrayList<>();
        for (int i = 0; i < command.length(); i++) {
            chars.add(command.charAt(i));
        }
        chars.add('\n');

        for (Character c : chars) {
            List<String> parts = new ArrayList<>();
            parts.add("vboxmanage");
            parts.add("controlvm");
            parts.add(name);
            parts.add("keyboardputscancode");
            parts.addAll(Scancodes.encode(c));
            run(parts.toArray(new String[parts.size()]));
            // Sending multiple characters at a time will cause VirtualBox
            // to complain if command is too long
        }
    }

    private void generateSshKeyPair() throws Exception {
        deleteIfExists(sshPrivateKey);
        deleteIfExists(sshPublicKey);
        run("ssh-keygen",
                "-t", "ed25519",
                "-f", sshPrivateKey.toString(),
                "-N", "",
                "-q"
        );
    }

    private void createVm() throws Exception {
        run("vboxmanage", "createvm",
                "--name", name,
                "-ostype", "ArchLinux_64",
                "--register"
        );
    }

    private void configVmRam() throws Exception {
        run("vboxmanage", "modifyvm", name, "--memory", "512");
    }

    private void configVmSshPortForwarding() throws Exception {
        String forward = "guestssh,tcp," + SSH_HOST_IP + "," + SSH_HOST_PORT + ",,22";
        run("vboxmanage", "modifyvm", name, "--natpf1", forward);
    }

    private void configVmHdd() throws Exception {
        Path medium = tempDirectory.resolve(name + ".vdi").toAbsolutePath();
        run("vboxmanage", "storagectl", name,
                "--name", "SATA",
                "--add", "sata"
        );
        run("vboxmanage", "createmedium", "disk",
                "--filename", medium.toString(),
                "--format", "VDI",
                "--size", "1024"
        );
        run("vboxmanage", "storageattach", name,
                "--storagectl", "SATA",
                "--port", "0",
                "--device", "0",
                "--type", "hdd",
                "--medium", medium.toString()
        );
    }

    private void startVm() throws Exception {
        run("vboxmanage", "startvm", name);
    }

    private void deleteVmIfExists() throws Exception {
        if (listRunningVms().containsKey(name)) {
            run("vboxmanage", "controlvm", name, "poweroff");
            sleep(2000); // Wait for it to unlock before deleting
        }
        if (listVms().containsKey(name)) {
            run("vboxmanage", "unregistervm", name, "--delete");
        }
    }

    private Map<String, UUID> listRunningVms() throws Exception {
        return parseVmListOutput(call("vboxmanage", "list", "runningvms"));
    }

    private Map<String, UUID> listVms() throws Exception {
        return parseVmListOutput(call("vboxmanage", "list", "vms"));
    }

    private Map<String, UUID> parseVmListOutput(String vmList) throws IOException {
        /*
         * Expected format:
         * "my vm 1" {a0e93612-7253-42fd-aced-90c66e2962fd}
         * "my vm 2" {b23a5486-7824-482a-bbef-547984653ab5}
         */
        Map<String, UUID> vms = new HashMap<>();
        for (String line : vmList.split("\r?\n")) {
            if (line.isEmpty()) {
                continue;
            }

            int i = line.lastIndexOf(' ');
            if (i < 0) {
                throw new AssertionError("Unknown format: " + line);
            }

            String name = line.substring(0, i);
            String uuid = line.substring(i + 1);

            if (!(name.startsWith("\"")
                    && name.endsWith("\"")
                    && uuid.startsWith("{")
                    && uuid.endsWith("}"))) {
                throw new AssertionError("Unknown format: " + line);
            }

            name = name.substring(1, name.length() - 1);
            uuid = uuid.substring(1, uuid.length() - 1);

            if (vms.put(name, UUID.fromString(uuid)) != null) {
                throw new AssertionError("Unknown format: " + vmList);
            }
        }
        return unmodifiableMap(vms);
    }

}
