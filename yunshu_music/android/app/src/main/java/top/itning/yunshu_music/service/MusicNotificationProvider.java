package top.itning.yunshu_music.service;

import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.drawable.Drawable;
import android.net.Uri;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;
import androidx.core.graphics.drawable.IconCompat;
import androidx.media3.common.MediaItem;
import androidx.media3.common.Player;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.session.CommandButton;
import androidx.media3.session.MediaNotification;
import androidx.media3.session.MediaSession;
import androidx.media3.session.MediaStyleNotificationHelper;

import com.bumptech.glide.Glide;
import com.bumptech.glide.request.target.CustomTarget;
import com.bumptech.glide.request.transition.Transition;
import com.google.common.collect.ImmutableList;

import java.io.File;

import io.flutter.util.PathUtils;
import top.itning.yunshu_music.MainActivity;
import top.itning.yunshu_music.R;
import top.itning.yunshu_music.channel.MusicChannel;

/**
 * Custom notification provider: builds the previous/play-pause/next media notification and loads
 * cover art via Glide over the signed OkHttp (MusicAppGlideModule).
 */
@UnstableApi
public class MusicNotificationProvider implements MediaNotification.Provider {

    private final Context context;

    public MusicNotificationProvider(Context context) {
        this.context = context;
    }

    @NonNull
    @Override
    public MediaNotification createNotification(
            @NonNull MediaSession mediaSession,
            @NonNull ImmutableList<CommandButton> mediaButtonPreferences,
            @NonNull MediaNotification.ActionFactory actionFactory,
            @NonNull MediaNotification.Provider.Callback onNotificationChangedCallback) {

        MediaItem item = mediaSession.getPlayer().getCurrentMediaItem();
        String title = (item == null || item.mediaMetadata.title == null) ? "云舒音乐" : item.mediaMetadata.title.toString();
        CharSequence subTitle = item == null ? null : item.mediaMetadata.artist;
        boolean playing = mediaSession.getPlayer().getPlayWhenReady();
        int iconDrawable = playing ? R.drawable.pause_black : R.drawable.play_black;
        int playPauseCommand = Player.COMMAND_PLAY_PAUSE;

        NotificationCompat.Action prev = actionFactory.createCustomAction(
                mediaSession,
                IconCompat.createWithResource(context, R.drawable.outline_skip_previous),
                "上一曲",
                MediaPlayerImpl.ACTION_SKIP_PREVIOUS,
                Bundle.EMPTY);
        NotificationCompat.Action playPause = actionFactory.createMediaAction(
                mediaSession,
                IconCompat.createWithResource(context, iconDrawable),
                "播放/暂停",
                playPauseCommand);
        NotificationCompat.Action next = actionFactory.createCustomAction(
                mediaSession,
                IconCompat.createWithResource(context, R.drawable.outline_skip_next),
                "下一曲",
                MediaPlayerImpl.ACTION_SKIP_NEXT,
                Bundle.EMPTY);

        PendingIntent contentIntent = PendingIntent.getActivity(
                context, 0,
                new Intent(context, MainActivity.class)
                        .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
                        .setAction(Intent.ACTION_MAIN)
                        .addCategory(Intent.CATEGORY_LAUNCHER),
                PendingIntent.FLAG_IMMUTABLE);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, "1")
                .setContentTitle(title)
                .setContentText(subTitle)
                .setContentIntent(contentIntent)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setSmallIcon(R.mipmap.launcher_icon)
                .setDeleteIntent(actionFactory.createNotificationDismissalIntent(mediaSession))
                .addAction(prev)
                .addAction(playPause)
                .addAction(next)
                .setStyle(new MediaStyleNotificationHelper.MediaStyle(mediaSession)
                        .setShowActionsInCompactView(0, 1, 2)
                        .setShowCancelButton(true)
                        .setCancelButtonIntent(actionFactory.createNotificationDismissalIntent(mediaSession)));

        loadCover(mediaSession, builder, onNotificationChangedCallback);
        return new MediaNotification(1, builder.build());
    }

    private void loadCover(MediaSession mediaSession, NotificationCompat.Builder builder, MediaNotification.Provider.Callback callback) {
        MediaItem item = mediaSession.getPlayer().getCurrentMediaItem();
        if (item == null) {
            return;
        }
        Uri coverUri = MusicChannel.musicPlayDataService.getCoverUri(item);
        if (coverUri == null) {
            return;
        }
        Glide.with(context).asBitmap().load(coverUri).into(new CustomTarget<Bitmap>() {
            @Override
            public void onResourceReady(@NonNull Bitmap resource, @Nullable Transition<? super Bitmap> transition) {
                builder.setLargeIcon(resource);
                callback.onNotificationChanged(new MediaNotification(1, builder.build()));
            }

            @Override
            public void onLoadCleared(@Nullable Drawable placeholder) {
            }

            @Override
            public void onLoadFailed(@Nullable Drawable errorDrawable) {
                File file = new File(PathUtils.getDataDirectory(context) + "/cover/default_cover.jpg");
                if (!file.exists()) {
                    return;
                }
                Glide.with(context).asBitmap().load(file).into(new CustomTarget<Bitmap>() {
                    @Override
                    public void onResourceReady(@NonNull Bitmap resource, @Nullable Transition<? super Bitmap> transition) {
                        builder.setLargeIcon(resource);
                        callback.onNotificationChanged(new MediaNotification(1, builder.build()));
                    }

                    @Override
                    public void onLoadCleared(@Nullable Drawable placeholder) {
                    }
                });
            }
        });
    }

    @Override
    public boolean handleCustomCommand(@NonNull MediaSession session, @NonNull String action, @NonNull Bundle extras) {
        return false;
    }

    @NonNull
    @Override
    public MediaNotification.Provider.NotificationChannelInfo getNotificationChannelInfo() {
        // Channel is created in MainActivity.onCreate with id "1".
        return new MediaNotification.Provider.NotificationChannelInfo("1", "播放通知");
    }
}
