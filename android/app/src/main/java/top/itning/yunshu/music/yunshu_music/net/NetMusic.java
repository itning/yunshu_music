package top.itning.yunshu.music.yunshu_music.net;

import retrofit2.Call;
import retrofit2.http.GET;
import top.itning.yunshu.music.yunshu_music.net.entity.MusicDTO;
import top.itning.yunshu.music.yunshu_music.net.entity.PageInfo;
import top.itning.yunshu.music.yunshu_music.net.entity.RestModel;

public interface NetMusic {
    @GET("music?size=3000")
    Call<RestModel<PageInfo<MusicDTO>>> get();
}
