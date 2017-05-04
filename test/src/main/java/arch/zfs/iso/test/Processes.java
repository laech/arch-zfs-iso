package arch.zfs.iso.test;

import org.apache.commons.io.IOUtils;

import java.io.InputStream;
import java.util.concurrent.TimeoutException;

import static java.lang.ProcessBuilder.Redirect.INHERIT;
import static java.nio.charset.StandardCharsets.UTF_8;
import static java.util.concurrent.TimeUnit.MINUTES;

final class Processes {

    private Processes() {
    }

    private static void checkProcess(Process process)
            throws InterruptedException, TimeoutException {
        try {
            if (!process.waitFor(1, MINUTES)) {
                throw new TimeoutException();
            }
            if (process.exitValue() != 0) {
                throw new RuntimeException(
                        "Process existed with status "
                                + process.exitValue());
            }
        } finally {
            process.destroyForcibly();
        }
    }

    static void run(String... command) throws Exception {
        checkProcess(new ProcessBuilder(command).inheritIO().start());
    }

    static String call(String... command) throws Exception {
        Process process = new ProcessBuilder(command)
                .redirectError(INHERIT)
                .start();

        String content;
        try (InputStream in = process.getInputStream()) {
            content = IOUtils.toString(in, UTF_8);
        }

        checkProcess(process);

        return content;
    }
}
