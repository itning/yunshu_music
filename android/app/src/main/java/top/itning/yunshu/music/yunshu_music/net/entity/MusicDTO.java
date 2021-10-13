package top.itning.yunshu.music.yunshu_music.net.entity;

public class MusicDTO {
    private String musicId;

    private String name;

    private String singer;

    private String lyricId;

    private Integer type;

    public String getMusicId() {
        return musicId;
    }

    public void setMusicId(String musicId) {
        this.musicId = musicId;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getSinger() {
        return singer;
    }

    public void setSinger(String singer) {
        this.singer = singer;
    }

    public String getLyricId() {
        return lyricId;
    }

    public void setLyricId(String lyricId) {
        this.lyricId = lyricId;
    }

    public Integer getType() {
        return type;
    }

    public void setType(Integer type) {
        this.type = type;
    }

    @Override
    public String toString() {
        return "MusicDTO{" +
                "musicId='" + musicId + '\'' +
                ", name='" + name + '\'' +
                ", singer='" + singer + '\'' +
                ", lyricId='" + lyricId + '\'' +
                ", type=" + type +
                '}';
    }
}
