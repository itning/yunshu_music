package top.itning.yunshu.music.yunshu_music;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
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

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

public class MusicPlayNotificationService extends Service {
    private static final String TAG = "MusicPlayNotification";

    private MainActivity.MusicControllerReceiver musicReceiver;
    private RemoteViews remoteViews;
    private NotificationManager manager;
    private Notification notification;

    public static class MessageEvent {
        String name;
        String singer;
        String coverBase64;
        Boolean play;

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

        public String getCoverBase64() {
            return coverBase64;
        }

        public void setCoverBase64(String coverBase64) {
            this.coverBase64 = coverBase64;
        }

        public Boolean isPlay() {
            return play;
        }

        public void setPlay(Boolean play) {
            this.play = play;
        }
    }

    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "onCreate()");

        EventBus.getDefault().register(this);

        manager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);

        registerMusicReceiver();

        generateRemoteViews();

        generateNotification();

        startForeground(1, notification);
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        EventBus.getDefault().unregister(this);
        stopForeground(true);
        if (musicReceiver != null) {
            unregisterReceiver(musicReceiver);
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "onStartCommand()");
        return START_REDELIVER_INTENT;
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        Log.d(TAG, "onBind()");
        return null;
    }

    private void registerMusicReceiver() {
        musicReceiver = new MainActivity.MusicControllerReceiver();
        IntentFilter intentFilter = new IntentFilter();
        intentFilter.addAction(PlayStatus.PREVIOUS.name());
        intentFilter.addAction(PlayStatus.PLAY_PAUSE.name());
        intentFilter.addAction(PlayStatus.NEXT.name());
        registerReceiver(musicReceiver, intentFilter);
    }

    public void generateNotification() {
        Intent notificationIntent = new Intent(getApplicationContext(), MainActivity.class);
        notificationIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
        notificationIntent.setAction(Intent.ACTION_MAIN);
        notificationIntent.addCategory(Intent.CATEGORY_LAUNCHER);
        Notification.Builder builder;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel("1", "播放通知", NotificationManager.IMPORTANCE_HIGH);
            manager.createNotificationChannel(channel);
            builder = new Notification.Builder(this.getApplicationContext(), "1");
        } else {
            builder = new Notification.Builder(this.getApplicationContext());
        }
        builder
                .setSmallIcon(R.mipmap.launcher_icon)
                .setCustomContentView(remoteViews)
                .setCustomBigContentView(remoteViews)
                .setContentIntent(PendingIntent.getActivity(this, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE))
                .setCategory(Notification.CATEGORY_TRANSPORT)
                .setOngoing(true)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setWhen(System.currentTimeMillis());

        notification = builder.build();
    }

    public enum PlayStatus {
        PREVIOUS,
        PLAY_PAUSE,
        NEXT
    }

    private void generateRemoteViews() {
        remoteViews = new RemoteViews(getPackageName(), R.layout.layout_widget);

        Intent intentPrev = new Intent(PlayStatus.PREVIOUS.name());
        PendingIntent prevPendingIntent = PendingIntent.getBroadcast(this, 0, intentPrev, PendingIntent.FLAG_IMMUTABLE);
        remoteViews.setOnClickPendingIntent(R.id.btn_notification_previous, prevPendingIntent);

        Intent intentPlay = new Intent(PlayStatus.PLAY_PAUSE.name());
        PendingIntent playPendingIntent = PendingIntent.getBroadcast(this, 0, intentPlay, PendingIntent.FLAG_IMMUTABLE);
        remoteViews.setOnClickPendingIntent(R.id.btn_notification_play, playPendingIntent);

        Intent intentNext = new Intent(PlayStatus.NEXT.name());
        PendingIntent nextPendingIntent = PendingIntent.getBroadcast(this, 0, intentNext, PendingIntent.FLAG_IMMUTABLE);

        remoteViews.setOnClickPendingIntent(R.id.btn_notification_next, nextPendingIntent);
    }

    private final MusicPlayNotificationService.MessageEvent lastEvent = new MusicPlayNotificationService.MessageEvent();

    @Subscribe(threadMode = ThreadMode.MAIN)
    public void onMessageEvent(MusicPlayNotificationService.MessageEvent event) {
        generateRemoteViews();

        if (null != event.getName()) {
            remoteViews.setTextViewText(R.id.music_name, event.getName());
            lastEvent.setName(event.getName());
        } else if (null != lastEvent.getName()) {
            remoteViews.setTextViewText(R.id.music_name, lastEvent.getName());
        }
        if (null != event.getSinger()) {
            remoteViews.setTextViewText(R.id.music_singer, event.getSinger());
            lastEvent.setSinger(event.getSinger());
        } else if (null != lastEvent.getSinger()) {
            remoteViews.setTextViewText(R.id.music_singer, lastEvent.getSinger());
        }

        if (null != event.getCoverBase64()) {
            byte[] decodedString = Base64.decode(event.getCoverBase64(), Base64.DEFAULT);
            Bitmap decodedByte = BitmapFactory.decodeByteArray(decodedString, 0, decodedString.length);
            remoteViews.setImageViewBitmap(R.id.music_cover, decodedByte);
            lastEvent.setCoverBase64(event.getCoverBase64());
            Log.d(TAG, "have " + decodedByte.toString());
        } else if (null != lastEvent.getCoverBase64()) {
            byte[] decodedString = Base64.decode(lastEvent.getCoverBase64(), Base64.DEFAULT);
            Bitmap decodedByte = BitmapFactory.decodeByteArray(decodedString, 0, decodedString.length);
            remoteViews.setImageViewBitmap(R.id.music_cover, decodedByte);
            Log.d(TAG, "lastEvent " + decodedByte.toString());
        } else {
            Log.d(TAG, "else");
            remoteViews.setImageViewResource(R.id.music_cover, R.drawable.default_cover);
        }

        if (null != event.isPlay()) {
            if (event.isPlay()) {
                remoteViews.setImageViewResource(R.id.btn_notification_play, R.drawable.pause_black);
            } else {
                remoteViews.setImageViewResource(R.id.btn_notification_play, R.drawable.play_black);
            }
            lastEvent.setPlay(event.isPlay());
        } else if (null != lastEvent.isPlay()) {
            if (lastEvent.isPlay()) {
                remoteViews.setImageViewResource(R.id.btn_notification_play, R.drawable.pause_black);
            } else {
                remoteViews.setImageViewResource(R.id.btn_notification_play, R.drawable.play_black);
            }
        }

        generateNotification();
        manager.notify(1, notification);
    }
}
