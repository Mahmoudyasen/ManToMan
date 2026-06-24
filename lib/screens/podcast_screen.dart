import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Podcast tab. The admin broadcasts episodes; the community listens with an
/// inline player (play/pause + scrub).
class PodcastScreen extends StatefulWidget {
  final VoidCallback onMenu;
  const PodcastScreen({super.key, required this.onMenu});

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> {
  final AudioPlayer _player = AudioPlayer();
  String? _playingId;
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playingId = null;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle(PodcastEpisode ep) async {
    if (_playingId == ep.id) {
      if (_state == PlayerState.playing) {
        await _player.pause();
      } else {
        await _player.resume();
      }
      return;
    }
    setState(() {
      _loading = true;
      _playingId = ep.id;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    try {
      await _player.stop();
      await _player.play(UrlSource(ep.audioUrl));
    } catch (_) {
      if (mounted) {
        setState(() => _playingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play this episode.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final admin = store.isAdmin;
    final episodes = store.podcasts;

    return Column(
      children: [
        ScreenHeader(
          title: 'The Podcast',
          subtitle: 'LISTEN TO THE SHOW',
          onMenu: widget.onMenu,
          trailing: admin
              ? GestureDetector(
                  onTap: _addEpisodeSheet,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                        gradient: C.accentGradient, shape: BoxShape.circle),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 26),
                  ),
                )
              : null,
        ),
        Expanded(
          child: episodes.isEmpty
              ? EmptyState(
                  icon: Icons.podcasts_rounded,
                  title: 'No episodes yet',
                  message: admin
                      ? 'Tap + to broadcast your first episode.'
                      : 'The admin hasn\'t published an episode yet.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 140),
                  physics: const BouncingScrollPhysics(),
                  itemCount: episodes.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _episodeCard(episodes[i], admin),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _episodeCard(PodcastEpisode ep, bool admin) {
    final isCurrent = _playingId == ep.id;
    final isPlaying = isCurrent && _state == PlayerState.playing;
    final total = _duration.inMilliseconds;
    final progress =
        (isCurrent && total > 0) ? _position.inMilliseconds / total : 0.0;

    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: C.cardGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.graphic_eq_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ep.title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: C.ink)),
                    const SizedBox(height: 4),
                    Text(timeAgo(ep.createdAt),
                        style: const TextStyle(fontSize: 12, color: C.muted)),
                  ],
                ),
              ),
              if (admin)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: C.muted, size: 20),
                  onPressed: () {
                    if (isCurrent) _player.stop();
                    store.removeEpisode(ep.id);
                  },
                ),
            ],
          ),
          if (ep.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(ep.description,
                style: const TextStyle(
                    fontSize: 13.5, height: 1.45, color: C.muted)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              GestureDetector(
                onTap: () => _toggle(ep),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                      gradient: C.accentGradient, shape: BoxShape.circle),
                  child: _loading && isCurrent
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        activeTrackColor: C.violetMid,
                        inactiveTrackColor: C.chip,
                        thumbColor: C.violetMid,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: progress.clamp(0.0, 1.0),
                        onChanged: isCurrent && total > 0
                            ? (v) => _player.seek(Duration(
                                milliseconds: (v * total).round()))
                            : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isCurrent ? _fmt(_position) : '0:00',
                              style: const TextStyle(
                                  fontSize: 11, color: C.muted)),
                          Text(isCurrent ? _fmt(_duration) : '--:--',
                              style: const TextStyle(
                                  fontSize: 11, color: C.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addEpisodeSheet() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                      color: C.chip, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 18),
              const Text('Broadcast an episode',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: C.ink)),
              const SizedBox(height: 18),
              AppField(
                  controller: titleCtrl,
                  hint: 'Episode title',
                  icon: Icons.title_rounded,
                  action: TextInputAction.next),
              const SizedBox(height: 12),
              AppField(
                  controller: descCtrl,
                  hint: 'Short description',
                  icon: Icons.notes_rounded,
                  maxLines: 3),
              const SizedBox(height: 12),
              AppField(
                  controller: urlCtrl,
                  hint: 'Audio URL (.mp3)',
                  icon: Icons.link_rounded),
              const SizedBox(height: 20),
              PillButton(
                label: 'Publish episode',
                icon: Icons.podcasts_rounded,
                onTap: () {
                  if (titleCtrl.text.trim().isEmpty ||
                      urlCtrl.text.trim().isEmpty) {
                    return;
                  }
                  store.addEpisode(
                      titleCtrl.text, descCtrl.text, urlCtrl.text);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
