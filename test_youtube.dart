// ignore_for_file: avoid_print
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

void main() {
  final url = 'https://youtu.be/VNURJVhcMQI?si=_c17NuuXrmPlxasq';
  final id = YoutubePlayer.convertUrlToId(url);
  print('Extracted ID: $id');
}
