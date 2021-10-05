package top.itning.yunshu.music.yunshu_music;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Build;
import android.os.IBinder;
import android.util.Base64;
import android.util.Log;
import android.widget.RemoteViews;

import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;

public class MusicPlayNotificationService extends Service {
    private static final String TAG = "MusicPlayNotification";

    private MainActivity.MusicControllerReceiver musicReceiver;
    private static RemoteViews remoteViews;
    private static NotificationManager manager;
    private static Notification notification;

    public static void setNowPlayMusicInfo(String name, String singer, String coverBase64) {
        remoteViews.setTextViewText(R.id.music_name, name);
        remoteViews.setTextViewText(R.id.music_singer, singer);
        if (null == coverBase64) {
            remoteViews.setImageViewResource(R.id.music_cover, R.drawable.default_cover);
        } else {
            byte[] decodedString = Base64.decode(coverBase64, Base64.DEFAULT);
            Bitmap decodedByte = BitmapFactory.decodeByteArray(decodedString, 0, decodedString.length);
            remoteViews.setImageViewBitmap(R.id.music_cover, decodedByte);
        }
        manager.notify(1, notification);
    }

    public static void setNowPlayMusicStatus(boolean play) {
        if (play) {
            remoteViews.setImageViewResource(R.id.btn_notification_play, R.drawable.pause_black);
        } else {
            remoteViews.setImageViewResource(R.id.btn_notification_play, R.drawable.play_black);
        }
        manager.notify(1, notification);
    }

    // TODO: 2021/10/6 处理API
    @RequiresApi(api = Build.VERSION_CODES.N)
    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "onCreate()");

        musicReceiver = new MainActivity.MusicControllerReceiver();
        IntentFilter intentFilter = new IntentFilter();
        intentFilter.addAction(PlayStatus.PREVIOUS.name());
        intentFilter.addAction(PlayStatus.PLAY_PAUSE.name());
        intentFilter.addAction(PlayStatus.NEXT.name());
        registerReceiver(musicReceiver, intentFilter);

        Intent notificationIntent = new Intent(getApplicationContext(), MainActivity.class);
        notificationIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
        notificationIntent.setAction(Intent.ACTION_MAIN);
        notificationIntent.addCategory(Intent.CATEGORY_LAUNCHER);

        Notification.Builder builder = new Notification
                .Builder(this.getApplicationContext())
                .setSmallIcon(R.mipmap.launcher_icon) // 设置状态栏内的小图标
                .setCustomContentView(generateRemoteViews())
                .setWhen(System.currentTimeMillis());// 设置该通知发生的时间
        builder.setContentIntent(PendingIntent.getActivity(this, 0, notificationIntent, PendingIntent.FLAG_UPDATE_CURRENT));

        manager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel("1", "播放通知", NotificationManager.IMPORTANCE_LOW);
            manager.createNotificationChannel(channel);
            builder.setChannelId("1");
        }
        notification = builder.build();
        startForeground(1, notification);
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (musicReceiver != null) {
            unregisterReceiver(musicReceiver);
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "onStartCommand()");
        return START_REDELIVER_INTENT;
    }

    public enum PlayStatus {
        PREVIOUS,
        PLAY_PAUSE,
        NEXT
    }

    private RemoteViews generateRemoteViews() {
        remoteViews = new RemoteViews(getPackageName(), R.layout.layout_widget);

        Intent intentPrev = new Intent(PlayStatus.PREVIOUS.name());
        PendingIntent prevPendingIntent = PendingIntent.getBroadcast(this, 0, intentPrev, 0);
        remoteViews.setOnClickPendingIntent(R.id.btn_notification_previous, prevPendingIntent);

        Intent intentPlay = new Intent(PlayStatus.PLAY_PAUSE.name());
        PendingIntent playPendingIntent = PendingIntent.getBroadcast(this, 0, intentPlay, 0);
        remoteViews.setOnClickPendingIntent(R.id.btn_notification_play, playPendingIntent);

        Intent intentNext = new Intent(PlayStatus.NEXT.name());
        PendingIntent nextPendingIntent = PendingIntent.getBroadcast(this, 0, intentNext, 0);
        remoteViews.setOnClickPendingIntent(R.id.btn_notification_next, nextPendingIntent);

        return remoteViews;
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        Log.d(TAG, "onBind()");
        return null;
    }
}
