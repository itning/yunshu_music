import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:yunshu_music/provider/music_data_model.dart';
import 'package:yunshu_music/provider/play_status_model.dart';

class PlayerPageController extends StatelessWidget {
  const PlayerPageController({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          color: Colors.white,
          iconSize: 35,
          icon: const Icon(Icons.skip_previous_outlined),
          onPressed: () {
            Provider.of<MusicDataModel>(context, listen: false).toPrevious();
          },
        ),
        Selector<PlayStatusModel, Tuple2<bool, ProcessingState>>(
          selector: (_, status) =>
              Tuple2(status.isPlayNow, status.processingState),
          builder: (BuildContext context, status, Widget? child) {
            if (status.item2 == ProcessingState.loading) {
              return const SizedBox(
                width: 25.0,
                height: 25.0,
                child: CircularProgressIndicator(
                  backgroundColor: Colors.grey,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              );
            }
            return status.item1
                ? IconButton(
                    color: Colors.white,
                    iconSize: 35,
                    icon: const Icon(Icons.pause),
                    onPressed: () {
                      PlayStatusModel playStatusModel =
                          context.read<PlayStatusModel>();
                      playStatusModel.setPlay(false);
                    },
                  )
                : IconButton(
                    color: Colors.white,
                    iconSize: 35,
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () {
                      PlayStatusModel playStatusModel =
                          context.read<PlayStatusModel>();
                      playStatusModel.setPlay(true);
                    },
                  );
          },
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_outlined),
          color: Colors.white,
          iconSize: 35,
          onPressed: () {
            Provider.of<MusicDataModel>(context, listen: false).toNext();
          },
        ),
      ],
    );
  }
}
