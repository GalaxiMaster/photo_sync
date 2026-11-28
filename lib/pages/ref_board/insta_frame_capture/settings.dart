import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_sync/pages/ref_board/insta_frame_capture/model.dart';

final serverResolverProvider = Provider<ServerResolver>((ref) => ServerResolver(
  dotenv.env['SERVER_URL']!,
  dotenv.env['API_TOKEN']!,
));