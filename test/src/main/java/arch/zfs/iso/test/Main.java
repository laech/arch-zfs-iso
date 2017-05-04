package arch.zfs.iso.test;

import java.nio.file.Path;
import java.nio.file.Paths;

class Main {

    public static void main(String[] args) throws Exception {

        if (args.length < 2) {
            System.err.println("Usage: java -jar <jar> <zfs-version> <iso>...");
            System.err.flush();
            return;
        }

        String zfsVersion = args[0];

        if (!zfsVersion.matches("\\d+\\.\\d+\\.\\d+\\.\\d+")) {
            System.err.println("Unexpected ZFS version: " + zfsVersion);
            System.err.flush();
            System.exit(1);
        }

        System.out.println("Expected ZFS version: " + zfsVersion);
        System.out.flush();

        boolean allPassed = true;
        for (int i = 1; i < args.length; i++) {
            allPassed &= test(zfsVersion, Paths.get(args[i]));
        }

        if (!allPassed) {
            System.err.println("\nFAILED\n");
            System.err.flush();
            System.exit(1);
        } else {
            System.out.println("\nPASSED\n");
        }
    }

    private static boolean test(String zfsVersion, Path iso) throws Exception {
        System.out.println();
        System.out.println("Testing: " + iso);
        System.out.flush();

        try (VirtualMachine vm = VirtualMachine.create("arch-zfs-iso-test")) {
            vm.attachIso(iso);
            vm.start();

            String kernelVersion = vm.execute("uname -r").trim();
            String actualStatus = vm.execute("dkms status").trim();
            String expectedStatus = "" +
                    "spl, " + zfsVersion + ", " + kernelVersion + ", x86_64: installed\n" +
                    "zfs, " + zfsVersion + ", " + kernelVersion + ", x86_64: installed";

            if (!expectedStatus.equals(actualStatus)) {
                System.err.println("Failed: " + iso);
                System.err.println("Expected:\n" + expectedStatus);
                System.err.println("Actual:\n" + actualStatus);
                System.err.flush();
                return false;
            } else {
                System.out.println("Passed: " + iso);
                System.out.flush();
                return true;
            }
        }
    }

}
