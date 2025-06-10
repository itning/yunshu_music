package top.itning.yunshu_music.util;

import java.math.BigInteger;
import java.nio.charset.StandardCharsets;

public class SignUtils {
    public static String md5(String input) {
        try {
            java.security.MessageDigest md = java.security.MessageDigest.getInstance("MD5");
            byte[] messageDigest = md.digest(input.getBytes(StandardCharsets.UTF_8));
            BigInteger number = new BigInteger(1, messageDigest);
            StringBuilder md5str = new StringBuilder(number.toString(16));
            // Pad with leading zeros
            while (md5str.length() < 32) {
                md5str.insert(0, "0");
            }
            return md5str.toString();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}