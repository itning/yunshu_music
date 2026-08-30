package top.itning.yunshu_music.service;

import static top.itning.yunshu_music.channel.MusicChannel.musicPlayDataService;

import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.KeyEvent;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.media3.common.MediaItem;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Player;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.session.MediaSession;
import androidx.media3.session.SessionCommand;
import androidx.media3.session.SessionCommands;
import androidx.media3.session.SessionResult;

import com.google.common.util.concurrent.Futures;
import com.google.common.util.concurrent.ListenableFuture;

/**
 * Central playback + queue logic. Single-item engine: each play intent resolves the next song via
 * {@link MusicPlayDataService} and plays it fresh on a single-item ExoPlayer.
 */
@UnstableApi
public class MediaPlayerImpl implements MediaSession.Callback, Player.Listener {

    public static final String ACTION_PLAY_FROM_ID = "PLAY_FROM_ID";
    public static final String ACTION_SKIP_NEXT = "SKIP_NEXT";
    public static final String ACTION_SKIP_PREVIOUS = "SKIP_PREVIOUS";

    private static final String TAG = "MediaPlayerImpl";
    private final Context context;
    private final ExoPlayer player;

    public MediaPlayerImpl(@NonNull Context context, @NonNull ExoPlayer player) {
        this.context = context;
        this.player = player;
    }

    @NonNull
    @Override
    public MediaSession.ConnectionResult onConnect(@NonNull MediaSession session, @NonNull MediaSession.ControllerInfo controller) {
        SessionCommands commands = new SessionCommands.Builder()
                .add(new SessionCommand(ACTION_PLAY_FROM_ID, Bundle.EMPTY))
                .add(new SessionCommand(ACTION_SKIP_NEXT, Bundle.EMPTY))
                .add(new SessionCommand(ACTION_SKIP_PREVIOUS, Bundle.EMPTY))
                .build();
        return new MediaSession.ConnectionResult.AcceptedResultBuilder(session, controller)
                .setAvailableSessionCommands(commands)
                .build();
    }

    @NonNull
    @Override
    public ListenableFuture<SessionResult> onCustomCommand(
            @NonNull MediaSession session,
            @NonNull MediaSession.ControllerInfo controller,
            @NonNull SessionCommand command,
            @NonNull Bundle args) {
        String action = command.customAction;
        if (ACTION_PLAY_FROM_ID.equals(action)) {
            String id = args.getString("id");
            if (id != null) {
                handlePlayFromId(id);
            }
            return Futures.immediateFuture(new SessionResult(SessionResult.RESULT_SUCCESS));
        } else if (ACTION_SKIP_NEXT.equals(action)) {
            handleNext(true);
            return Futures.immediateFuture(new SessionResult(SessionResult.RESULT_SUCCESS));
        } else if (ACTION_SKIP_PREVIOUS.equals(action)) {
            handlePrevious(true);
            return Futures.immediateFuture(new SessionResult(SessionResult.RESULT_SUCCESS));
        }
        return Futures.immediateFuture(new SessionResult(SessionResult.RESULT_ERROR_NOT_SUPPORTED));
    }

    @Override
    public boolean onMediaButtonEvent(@NonNull MediaSession session, @NonNull MediaSession.ControllerInfo controllerInfo, @NonNull Intent intent) {
        KeyEvent keyEvent = null;
        Bundle extras = intent.getExtras();
        if (extras != null && extras.containsKey(Intent.EXTRA_KEY_EVENT)) {
            keyEvent = extras.getParcelable(Intent.EXTRA_KEY_EVENT);
        }
        int keyCode = keyEvent != null ? keyEvent.getKeyCode() : KeyEvent.KEYCODE_UNKNOWN;
        switch (keyCode) {
            case KeyEvent.KEYCODE_MEDIA_NEXT:
            case KeyEvent.KEYCODE_MEDIA_SKIP_FORWARD:
            case KeyEvent.KEYCODE_MEDIA_FAST_FORWARD:
                handleNext(true);
                return true;
            case KeyEvent.KEYCODE_MEDIA_PREVIOUS:
            case KeyEvent.KEYCODE_MEDIA_SKIP_BACKWARD:
            case KeyEvent.KEYCODE_MEDIA_REWIND:
                handlePrevious(true);
                return true;
            case KeyEvent.KEYCODE_HEADSETHOOK:
                if (player.isPlaying()) {
                    player.pause();
                } else {
                    player.play();
                }
                return true;
            default:
                return false;
        }
    }

    private void handlePlayFromId(String id) {
        Log.d(TAG, "handlePlayFromId " + id);
        musicPlayDataService.playFromMediaId(id);
        playCurrent();
    }

    private void handleNext(boolean userTrigger) {
        Log.d(TAG, "handleNext " + userTrigger);
        player.stop();
        musicPlayDataService.next(userTrigger);
        playCurrent();
    }

    private void handlePrevious(boolean userTrigger) {
        Log.d(TAG, "handlePrevious " + userTrigger);
        player.stop();
        musicPlayDataService.previous(userTrigger);
        playCurrent();
    }

    private void playCurrent() {
        MediaItem item = musicPlayDataService.getNowPlayMusic();
        if (item == null) {
            return;
        }
        player.setMediaItem(item);
        player.prepare();
        player.play();
    }

    @Override
    public void onPlaybackStateChanged(@androidx.media3.common.Player.State int playbackState) {
        if (playbackState == Player.STATE_ENDED) {
            player.stop();
            handleNext(false);
        }
    }

    @Override
    public void onPlayerError(@NonNull PlaybackException error) {
        Log.w(TAG, "onPlayerError ", error);
        Toast.makeText(context, error.getErrorCodeName(), Toast.LENGTH_LONG).show();
    }
}
