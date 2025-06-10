package top.itning.yunshu_music.util;

import android.util.Log;

import androidx.annotation.NonNull;

import java.io.IOException;
import java.util.concurrent.TimeUnit;

import okhttp3.Call;
import okhttp3.HttpUrl;
import okhttp3.Interceptor;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import top.itning.yunshu_music.channel.MusicChannel;

/**
 * @author itning
 * @since 2021/10/20 17:09
 */
public class HttpClient {

    private static final String TAG = "HttpClient";

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
                .addInterceptor(new Interceptor() {
                    @NonNull
                    @Override
                    public Response intercept(@NonNull Chain chain) throws IOException {
                        Request original = chain.request();
                        if (!MusicChannel.enableAuthorization()) {
                            return chain.proceed(original);
                        }
                        String signParamName = MusicChannel.getAuthorizationValueAsString("SIGN_PARAM");
                        String timeParamName = MusicChannel.getAuthorizationValueAsString("TIME_PARAM");
                        String pkey = MusicChannel.getAuthorizationValueAsString("SIGN");

                        HttpUrl originalUrl = original.url();
                        long timestamp = System.currentTimeMillis();
                        String path = originalUrl.encodedPath();
                        String signStr = pkey + path + timestamp;
                        String signature = SignUtils.md5(signStr);

                        // 构建新的查询参数
                        HttpUrl.Builder newUrlBuilder = originalUrl.newBuilder()
                                .addQueryParameter(signParamName, signature)
                                .addQueryParameter(timeParamName, String.valueOf(timestamp));

                        // 构建新请求
                        Request newRequest = original.newBuilder()
                                .url(newUrlBuilder.build())
                                .build();

                        Log.d(TAG, "Signed URL: " + newUrlBuilder.build());

                        return chain.proceed(newRequest);
                    }
                })
                .build();
    }

    public static Call.Factory getCallFactory() {
        return OK_HTTP_CLIENT;
    }
}
