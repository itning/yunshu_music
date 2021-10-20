package top.itning.yunshu_music.util;

import java.util.concurrent.TimeUnit;

import okhttp3.OkHttpClient;

/**
 * @author itning
 * @since 2021/10/20 17:09
 */
public class HttpClient {
    public static final OkHttpClient OK_HTTP_CLIENT = okHttpClient();

    private static OkHttpClient okHttpClient() {
        return new OkHttpClient.Builder()
                // 设置ping信号发送时间间隔，该选项一般用于维持Websocket/Http2长连接，发送心跳包。默认值为0表示禁用心跳机制。
                .pingInterval(2, TimeUnit.SECONDS)
                .connectTimeout(10, TimeUnit.SECONDS)
                .readTimeout(10, TimeUnit.SECONDS)
                .writeTimeout(5, TimeUnit.SECONDS)
                // 是否允许OkHttp自动执行失败重连，默认为true。当设置为true时，okhttp会在以下几种可能的请求失败的情况下恢复连接并重新请求：1.IP地址不可达；2.过久的池化连接；3.代理服务器不可达。
                .retryOnConnectionFailure(true)
                .build();
    }
}
