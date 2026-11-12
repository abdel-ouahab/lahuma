import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lahuma/core/audio/now_playing.dart';

class _Source implements NowPlayingSource {
  _Source({this.hasNext = true, this.hasPrevious = true});

  @override
  final AudioPlayer player = AudioPlayer();
  @override
  bool hasNext;
  @override
  bool hasPrevious;

  final calls = <String>[];

  @override
  Future<void> play() async => calls.add('play');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> skipToNext() async => calls.add('next');
  @override
  Future<void> skipToPrevious() async => calls.add('previous');
  @override
  Future<void> stop() async => calls.add('stop');
}

const _fatiha = MediaItem(
    id: 'mp3/1/1', title: 'الفاتحة', artist: 'مشاري العفاسي');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('shows the surah and reciter with previous / play / next', () {
    final handler = NowPlayingHandler();
    final source = _Source();
    handler.show(source, _fatiha);

    expect(handler.mediaItem.value?.title, 'الفاتحة');
    expect(handler.mediaItem.value?.artist, 'مشاري العفاسي');
    final state = handler.playbackState.value;
    expect(state.controls, [
      MediaControl.skipToPrevious,
      MediaControl.play,
      MediaControl.skipToNext,
    ]);
    expect(state.androidCompactActionIndices, [0, 1, 2]);
    expect(state.systemActions, contains(MediaAction.seek));
  });

  test('leaves out skip buttons the player cannot honour', () {
    final handler = NowPlayingHandler();
    handler.show(_Source(hasNext: false, hasPrevious: false), _fatiha);
    expect(handler.playbackState.value.controls, [MediaControl.play]);
  });

  test('commands from the lock screen reach the player shown', () async {
    final handler = NowPlayingHandler();
    final first = _Source();
    final second = _Source();
    handler.show(first, _fatiha);
    handler.show(second,
        const MediaItem(id: 'lahuma/x/2', title: 'البقرة', artist: 'قارئ'));

    await handler.play();
    await handler.pause();
    await handler.skipToNext();
    await handler.skipToPrevious();
    expect(first.calls, isEmpty);
    expect(second.calls, ['play', 'pause', 'next', 'previous']);
    expect(handler.mediaItem.value?.title, 'البقرة');
  });

  test('stop ends the recitation and removes the card', () async {
    final handler = NowPlayingHandler();
    final source = _Source();
    handler.show(source, _fatiha);
    await handler.stop();
    expect(source.calls, ['stop']);
    expect(handler.mediaItem.value, isNull);
    expect(handler.playbackState.value.processingState,
        AudioProcessingState.idle);

    // Nothing shown: commands are ignored.
    await handler.play();
    expect(source.calls, ['stop']);
  });

  test('clearing another player leaves the shown card alone', () {
    final handler = NowPlayingHandler();
    final shown = _Source();
    handler.show(shown, _fatiha);
    handler.clear(_Source());
    expect(handler.mediaItem.value?.title, 'الفاتحة');
    handler.clearAll();
    expect(handler.mediaItem.value, isNull);
  });
}
