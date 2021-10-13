package top.itning.yunshu.music.yunshu_music.net;

import androidx.annotation.NonNull;

import java.util.concurrent.TimeUnit;

import okhttp3.OkHttpClient;
import retrofit2.Retrofit;
import retrofit2.converter.gson.GsonConverterFactory;

/**
 * @author itning
 */
public final class HttpHelper {

    private static Retrofit RETROFIT;

    /**
     * 初始化Retrofit
     */
    public static void initRetrofit() {
        String baseUrl = "http://49.235.109.242:8888/";

        OkHttpClient okHttpClient = new OkHttpClient.Builder()
                // 设置超时时间
                .connectTimeout(100L, TimeUnit.SECONDS)
                // 设置读写时间
                .readTimeout(100L, TimeUnit.SECONDS)
                .build();
        RETROFIT = new Retrofit.Builder()
                .baseUrl(baseUrl)
                .addConverterFactory(GsonConverterFactory.create())
                .client(okHttpClient)
                .build();
    }

    /**
     * 获取RETROFIT实例
     *
     * @param service 服务名
     * @param <T>     返回类型
     * @return 代理的实例
     */
    public static <T> T get(@NonNull final Class<T> service) {
        return RETROFIT.create(service);
    }
}