package top.itning.yunshu.music.yunshu_music.net.entity;

import java.util.List;

public class PageInfo<T> {
    private List<T> content;

    public List<T> getContent() {
        return content;
    }

    public void setContent(List<T> content) {
        this.content = content;
    }

    @Override
    public String toString() {
        return "PageInfo{" +
                "content=" + content +
                '}';
    }
}
