enum MusicPlayMode { SEQUENCE, RANDOMLY, LOOP }

extension MusicPlayModeExtension on MusicPlayMode {
  String name() {
    switch (index) {
      case 0:
        return 'SEQUENCE';
      case 1:
        return 'RANDOMLY';
      case 2:
        return 'LOOP';
      default:
        return 'SEQUENCE';
    }
  }
}

MusicPlayMode valueOf(String name) {
  switch (name) {
    case 'SEQUENCE':
      return MusicPlayMode.SEQUENCE;
    case 'RANDOMLY':
      return MusicPlayMode.RANDOMLY;
    case 'LOOP':
      return MusicPlayMode.LOOP;
    default:
      return MusicPlayMode.SEQUENCE;
  }
}
