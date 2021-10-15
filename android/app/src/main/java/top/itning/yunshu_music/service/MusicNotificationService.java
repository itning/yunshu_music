package top.itning.yunshu_music.service;

import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
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

import java.io.File;

import io.flutter.util.PathUtils;
import top.itning.yunshu_music.MainActivity;
import top.itning.yunshu_music.R;


/**
 * @author itning
 * @since 2021/10/12 14:41
 */
public class MusicNotificationService {
    private static final String TAG = "MusicNotificationService";
    private final MediaSessionCompat session;
    private final MusicBrowserService context;
    private final NotificationManager notificationManager;

    public MusicNotificationService(@NonNull MediaSessionCompat session, @NonNull MusicBrowserService context) {
        this.session = session;
        this.context = context;
        notificationManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
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

            @Override
            public void onLoadFailed(@Nullable Drawable errorDrawable) {
                Log.w(TAG, "load cover failed, use default cover");
                File file = new File(PathUtils.getDataDirectory(context) + "/cover/default_cover.jpg");
                if (!file.exists()) {
                    Log.w(TAG, "unused default cover because file not exist. path: " + file.getPath());
                    return;
                }
                Glide.with(context).asBitmap().load(file).into(new CustomTarget<Bitmap>() {
                    @Override
                    public void onResourceReady(@NonNull Bitmap resource, @Nullable Transition<? super Bitmap> transition) {
                        updateNotification(description.getTitle(), description.getSubtitle(), description.getDescription(), resource);
                    }

                    @Override
                    public void onLoadCleared(@Nullable Drawable placeholder) {

                    }
                });
            }
        });
    }

    private void updateNotification(@Nullable CharSequence title, @Nullable CharSequence subTitle, @Nullable CharSequence subText, @Nullable Bitmap icon) {
        Log.d(TAG, "updateNotification");

        MediaControllerCompat controller = session.getController();
        int iconDrawable = R.drawable.play_black;
        @PlaybackStateCompat.MediaKeyAction long action = PlaybackStateCompat.ACTION_PLAY;
        if (controller.getPlaybackState().getState() == PlaybackStateCompat.STATE_PLAYING) {
            iconDrawable = R.drawable.pause_black;
            action = PlaybackStateCompat.ACTION_PAUSE;
        }

        Intent notificationIntent = new Intent(context, MainActivity.class);
        notificationIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
        notificationIntent.setAction(Intent.ACTION_MAIN);
        notificationIntent.addCategory(Intent.CATEGORY_LAUNCHER);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, "1")
                .setContentTitle(title)
                .setContentText(subTitle)
                .setSubText(subText)
                .setLargeIcon(icon)
                .setContentIntent(PendingIntent.getActivity(context, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE))
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setSmallIcon(R.mipmap.launcher_icon)
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

        Intent notificationIntent = new Intent(context, MainActivity.class);
        notificationIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
        notificationIntent.setAction(Intent.ACTION_MAIN);
        notificationIntent.addCategory(Intent.CATEGORY_LAUNCHER);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, "1")
                .setContentTitle(title)
                .setContentText(subTitle)
                .setSubText(subText)
                .setLargeIcon(icon)
                .setContentIntent(PendingIntent.getActivity(context, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE))
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setSmallIcon(R.mipmap.launcher_icon)
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
