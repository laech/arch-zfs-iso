package arch.zfs.iso.test;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static java.util.Arrays.asList;
import static java.util.Collections.unmodifiableList;
import static java.util.Collections.unmodifiableMap;
import static java.util.stream.Collectors.toList;

// See http://www.win.tue.nl/~aeb/linux/kbd/scancodes-1.html
final class Scancodes {

    private static final int RELEASE_ADDER = 0x80;

    private static final int LEFT_SHIFT_PRESSED = 0x2a;
    private static final int LEFT_SHIFT_RELEASED = LEFT_SHIFT_PRESSED + RELEASE_ADDER;

    private static final Map<Character, List<Integer>> CODES;

    static {
        Map<Character, List<Integer>> codes = new HashMap<>();
        encode(codes, 0x1e, 'a', 'A');
        encode(codes, 0x30, 'b', 'B');
        encode(codes, 0x2e, 'c', 'C');
        encode(codes, 0x20, 'd', 'D');
        encode(codes, 0x12, 'e', 'E');
        encode(codes, 0x21, 'f', 'F');
        encode(codes, 0x22, 'g', 'G');
        encode(codes, 0x23, 'h', 'H');
        encode(codes, 0x17, 'i', 'I');
        encode(codes, 0x24, 'j', 'J');
        encode(codes, 0x25, 'k', 'K');
        encode(codes, 0x26, 'l', 'L');
        encode(codes, 0x32, 'm', 'M');
        encode(codes, 0x31, 'n', 'N');
        encode(codes, 0x18, 'o', 'O');
        encode(codes, 0x19, 'p', 'P');
        encode(codes, 0x10, 'q', 'Q');
        encode(codes, 0x13, 'r', 'R');
        encode(codes, 0x1f, 's', 'S');
        encode(codes, 0x14, 't', 'T');
        encode(codes, 0x16, 'u', 'U');
        encode(codes, 0x2f, 'v', 'V');
        encode(codes, 0x11, 'w', 'W');
        encode(codes, 0x2d, 'x', 'X');
        encode(codes, 0x15, 'y', 'Y');
        encode(codes, 0x2c, 'z', 'Z');
        encode(codes, 0x02, '1', '!');
        encode(codes, 0x03, '2', '@');
        encode(codes, 0x04, '3', '#');
        encode(codes, 0x05, '4', '$');
        encode(codes, 0x06, '5', '%');
        encode(codes, 0x07, '6', '^');
        encode(codes, 0x08, '7', '&');
        encode(codes, 0x09, '8', '*');
        encode(codes, 0x0a, '9', '(');
        encode(codes, 0x0b, '0', ')');
        encode(codes, 0x27, ';', ':');
        encode(codes, 0x0c, '-', '_');
        encode(codes, 0x0d, '=', '+');
        encode(codes, 0x2b, '\\', '|');
        encode(codes, 0x29, '`', '~');
        encode(codes, 0x33, ',', '<');
        encode(codes, 0x34, '.', '>');
        encode(codes, 0x35, '/', '?');
        encode(codes, 0x28, '\'', '"');
        encode(codes, 0x39, ' ', null);
        encode(codes, 0x1c, '\n', null);
        CODES = unmodifiableMap(codes);
    }

    private static void encode(
            Map<Character, List<Integer>> result,
            int codePressed,
            char normalCharacter,
            Character shiftedCharacter
    ) {
        List<Integer> normalCodeSequence = unmodifiableList(asList(
                codePressed,
                codePressed + RELEASE_ADDER
        ));
        if (result.put(normalCharacter, normalCodeSequence) != null) {
            throw new AssertionError("Character '" + normalCharacter + "'" +
                    " has multiple code sequences: " + normalCodeSequence + ", "
                    + result.get(normalCharacter));
        }
        if (shiftedCharacter != null) {
            List<Integer> shiftedCodeSequence = new ArrayList<>();
            shiftedCodeSequence.add(LEFT_SHIFT_PRESSED);
            shiftedCodeSequence.addAll(normalCodeSequence);
            shiftedCodeSequence.add(LEFT_SHIFT_RELEASED);
            shiftedCodeSequence = unmodifiableList(shiftedCodeSequence);

            if (result.put(shiftedCharacter, shiftedCodeSequence) != null) {
                throw new AssertionError("Character '" + shiftedCharacter + "'" +
                        " has multiple code sequences: " + shiftedCodeSequence + ", "
                        + result.get(shiftedCharacter));
            }
        }
    }

    static List<String> encode(char c) {
        List<Integer> codeSequence = CODES.get(c);
        if (codeSequence == null) {
            throw new IllegalArgumentException(
                    "No scancode found for char: '" + c + "'");
        }
        return unmodifiableList(codeSequence.stream()
                .map(code -> String.format("%02x", code))
                .collect(toList()));
    }
}
