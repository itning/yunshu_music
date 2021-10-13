package top.itning.yunshu.music.yunshu_music.channel;

import io.flutter.plugin.common.MethodChannel;
import top.itning.yunshu.music.yunshu_music.service.MusicPlayDataService;

/**
 * @author itning
 * @since 2021/10/13 15:39
 */
public class MusicChannel {
    public static MethodChannel methodChannel;
    public static MusicPlayDataService musicPlayDataService = new MusicPlayDataService();
}
