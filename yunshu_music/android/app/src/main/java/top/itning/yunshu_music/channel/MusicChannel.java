package top.itning.yunshu_music.channel;

import java.util.Map;

import io.flutter.plugin.common.MethodChannel;
import top.itning.yunshu_music.service.MusicPlayDataService;

/**
 * @author itning
 * @since 2021/10/13 15:39
 */
public class MusicChannel {
    public static MethodChannel methodChannel;
    public static MusicPlayDataService musicPlayDataService = new MusicPlayDataService();

    public static Map<String, Object> authorizationData;

    public static boolean enableAuthorization() {
        if (null == authorizationData) {
            return false;
        }
        //noinspection DataFlowIssue
        return (boolean) authorizationData.getOrDefault("ENABLE", false);
    }

    public static String getAuthorizationValueAsString(String key) {
        if (null == authorizationData) {
            return null;
        }
        return (String) authorizationData.get(key);
    }
}
