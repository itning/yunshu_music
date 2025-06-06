import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yunshu_music/method_channel/music_channel.dart';
import 'package:yunshu_music/provider/volume_data_model.dart';

class VolumeSlider extends StatelessWidget {
  const VolumeSlider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(Icons.volume_mute, size: 20.0, color: Colors.white),
        Selector<VolumeDataModel, double>(
          builder: (_, value, _) {
            return Slider(
              activeColor: Colors.white,
              inactiveColor: Colors.grey,
              value: value,
              max: 1.0,
              min: 0.0,
              onChanged: (value) async {
                await MusicChannel.get().setVolume(value);
              },
            );
          },
          selector: (_, model) => model.volume,
        ),
        const Icon(Icons.volume_up, size: 20.0, color: Colors.white),
      ],
    );
  }
}
