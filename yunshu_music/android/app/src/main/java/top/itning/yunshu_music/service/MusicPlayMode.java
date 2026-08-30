package top.itning.yunshu_music.service;

/**
 * @author itning
 * @since 2021/10/12 15:05
 */
public enum MusicPlayMode {
    SEQUENCE,
    RANDOMLY,
    LOOP,
    ;

    public static MusicPlayMode getNext(MusicPlayMode nowMode) {
        switch (nowMode) {
            case SEQUENCE:
                return MusicPlayMode.RANDOMLY;
            case RANDOMLY:
                return MusicPlayMode.LOOP;
            case LOOP:
            default:
                return MusicPlayMode.SEQUENCE;
        }
    }
}
