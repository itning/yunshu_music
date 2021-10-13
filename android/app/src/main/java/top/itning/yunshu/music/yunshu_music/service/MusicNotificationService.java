package top.itning.yunshu.music.yunshu_music.service;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.drawable.Drawable;
import android.support.v4.media.MediaDescriptionCompat;
import android.support.v4.media.MediaMetadataCompat;
import android.support.v4.media.session.MediaControllerCompat;
import android.support.v4.media.session.MediaSessionCompat;
import android.support.v4.media.session.PlaybackStateCompat;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;
import androidx.media.session.MediaButtonReceiver;

import com.bumptech.glide.Glide;
import com.bumptech.glide.request.target.CustomTarget;
import com.bumptech.glide.request.transition.Transition;

import top.itning.yunshu.music.yunshu_music.R;


/**
 * @author itning
 * @since 2021/10/12 14:41
 */
public class MusicNotificationService {
    private static final String TAG = "MusicNotificationService";
    private final MediaSessionCompat session;
    private final MusicBrowserService context;

    public MusicNotificationService(@NonNull MediaSessionCompat session, @NonNull MusicBrowserService context) {
        this.session = session;
        this.context = context;
    }

    public void updateNotification() {
        MediaControllerCompat controller = session.getController();
        MediaMetadataCompat mediaMetadata = controller.getMetadata();
        MediaDescriptionCompat description = mediaMetadata.getDescription();
        Glide.with(context).asBitmap().load(description.getIconUri()).into(new CustomTarget<Bitmap>() {
            @Override
            public void onResourceReady(@NonNull Bitmap resource, @Nullable Transition<? super Bitmap> transition) {
                updateNotification(description.getTitle(), description.getSubtitle(), description.getDescription(), resource);
            }

            @Override
            public void onLoadCleared(@Nullable Drawable placeholder) {

            }
        });
    }

    private void updateNotification(@Nullable CharSequence title, @Nullable CharSequence subTitle, @Nullable CharSequence subText, @Nullable Bitmap icon) {
        Log.d(TAG, "updateNotification");
        MediaControllerCompat controller = session.getController();

        NotificationChannel channel = new NotificationChannel("1", "播放通知", NotificationManager.IMPORTANCE_LOW);
        NotificationManager notificationManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        notificationManager.createNotificationChannel(channel);
        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, "1");
        int iconDrawable = R.drawable.play_black;
        @PlaybackStateCompat.MediaKeyAction long action = PlaybackStateCompat.ACTION_PLAY;
        if (controller.getPlaybackState().getState() == PlaybackStateCompat.STATE_PLAYING) {
            iconDrawable = R.drawable.pause_black;
            action = PlaybackStateCompat.ACTION_PAUSE;
        }

        builder
                .setContentTitle(title)
                .setContentText(subTitle)
                .setSubText(subText)
                .setLargeIcon(icon)
                .setContentIntent(controller.getSessionActivity())
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setDeleteIntent(MediaButtonReceiver.buildMediaButtonPendingIntent(context,
                        PlaybackStateCompat.ACTION_STOP))
                .addAction(new NotificationCompat.Action(
                        R.drawable.outline_skip_previous, "上一曲",
                        MediaButtonReceiver.buildMediaButtonPendingIntent(context,
                                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS)))
                .addAction(new NotificationCompat.Action(
                        iconDrawable, "播放/暂停",
                        MediaButtonReceiver.buildMediaButtonPendingIntent(context, action)))
                .addAction(new NotificationCompat.Action(
                        R.drawable.outline_skip_next, "下一曲",
                        MediaButtonReceiver.buildMediaButtonPendingIntent(context,
                                PlaybackStateCompat.ACTION_SKIP_TO_NEXT)))
                .setStyle(new androidx.media.app.NotificationCompat.MediaStyle()
                        .setMediaSession(session.getSessionToken())
                        .setShowActionsInCompactView(0, 1, 2)
                        .setShowCancelButton(true)
                        .setCancelButtonIntent(MediaButtonReceiver.buildMediaButtonPendingIntent(context,
                                PlaybackStateCompat.ACTION_STOP)));

        notificationManager.notify(1, builder.build());
    }

    public void generateNotification(@Nullable String title, @Nullable String subTitle, @Nullable String subText, @Nullable Bitmap icon) {
        Log.d(TAG, "generateNotification");
        MediaControllerCompat controller = session.getController();

        NotificationChannel channel = new NotificationChannel("1", "播放通知", NotificationManager.IMPORTANCE_LOW);
        NotificationManager notificationManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        notificationManager.createNotificationChannel(channel);
        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, "1");

        builder
                .setContentTitle(title)
                .setContentText(subTitle)
                .setSubText(subText)
                .setLargeIcon(icon)
                .setContentIntent(controller.getSessionActivity())
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setDeleteIntent(MediaButtonReceiver.buildMediaButtonPendingIntent(context,
                        PlaybackStateCompat.ACTION_STOP))
                .addAction(new NotificationCompat.Action(
                        R.drawable.outline_skip_previous, "上一曲",
                        MediaButtonReceiver.buildMediaButtonPendingIntent(context,
                                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS)))
                .addAction(new NotificationCompat.Action(
                        R.drawable.play_black, "播放",
                        MediaButtonReceiver.buildMediaButtonPendingIntent(context,
                                PlaybackStateCompat.ACTION_PLAY)))
                .addAction(new NotificationCompat.Action(
                        R.drawable.outline_skip_next, "下一曲",
                        MediaButtonReceiver.buildMediaButtonPendingIntent(context,
                                PlaybackStateCompat.ACTION_SKIP_TO_NEXT)))
                .setStyle(new androidx.media.app.NotificationCompat.MediaStyle()
                        .setMediaSession(session.getSessionToken())
                        .setShowActionsInCompactView(0, 1, 2)
                        .setShowCancelButton(true)
                        .setCancelButtonIntent(MediaButtonReceiver.buildMediaButtonPendingIntent(context,
                                PlaybackStateCompat.ACTION_STOP)));

        context.startForeground(1, builder.build());
    }
}
