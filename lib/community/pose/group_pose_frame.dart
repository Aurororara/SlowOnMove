import 'dart:convert';
import 'dart:typed_data';

const groupPoseTopic = 'slowonmove.pose.v1';
const groupPoseLifetime = Duration(seconds: 2);
const groupPoseConnections = <(int, int)>[
  (11, 12),
  (11, 13),
  (13, 15),
  (12, 14),
  (14, 16),
  (11, 23),
  (12, 24),
  (23, 24),
  (23, 25),
  (25, 27),
  (24, 26),
  (26, 28),
  (27, 29),
  (29, 31),
  (27, 31),
  (28, 30),
  (30, 32),
  (28, 32),
];
final groupPoseJointIds =
    groupPoseConnections.expand((p) => [p.$1, p.$2]).toSet();

enum GroupPoseStatus { waiting, tracking, noPose, paused, error, unsupported }

class GroupPosePoint {
  final int id;
  final double x;
  final double y;
  final double confidence;

  const GroupPosePoint(this.id, this.x, this.y, this.confidence);

  List<num> toJson() =>
      [id, _round(x, 1000), _round(y, 1000), _round(confidence, 100)];
  static double _round(double value, int scale) =>
      (value * scale).round() / scale;
}

class GroupPoseFrame {
  final GroupPoseStatus status;
  final double? score;
  final double aspectRatio;
  final List<GroupPosePoint> points;
  final String feedback;
  final DateTime sampledAt;

  GroupPoseFrame({
    required this.status,
    this.score,
    this.aspectRatio = 1,
    List<GroupPosePoint> points = const [],
    this.feedback = '',
    DateTime? sampledAt,
  })  : points = List.unmodifiable(points),
        sampledAt = sampledAt ?? DateTime.now();

  bool isFresh(DateTime now) => now.difference(sampledAt) <= groupPoseLifetime;
  bool canDisplayScore(DateTime now) =>
      status == GroupPoseStatus.tracking && score != null && isFresh(now);

  Uint8List encode(int sequence, DateTime now) =>
      Uint8List.fromList(utf8.encode(jsonEncode({
        'v': 1,
        'seq': sequence,
        'status': status.name,
        'score': score == null ? null : (score! * 10).round() / 10,
        'ratio': (aspectRatio * 1000).round() / 1000,
        'age': now.difference(sampledAt).inMilliseconds.clamp(0, 10000),
        'points': points.map((p) => p.toJson()).toList(),
        'feedback': feedback.length > 40 ? feedback.substring(0, 40) : feedback,
      })));

  /// Packets contain no trusted identity. Always use the SDK-authenticated sender.
  static ({int sequence, GroupPoseFrame frame})? decode(
      List<int> bytes, DateTime now) {
    if (bytes.length > 1200) {
      return null;
    }
    try {
      final data = jsonDecode(utf8.decode(bytes));
      if (data is! Map ||
          data['v'] != 1 ||
          data['seq'] is! int ||
          data['seq'] < 0) {
        return null;
      }
      final status = GroupPoseStatus.values.byName(data['status'] as String);
      final age = data['age'];
      final ratio = data['ratio'];
      final score = data['score'];
      final rawPoints = data['points'];
      final feedback = data['feedback'];
      if (age is! int ||
          age < 0 ||
          age > 10000 ||
          ratio is! num ||
          !ratio.isFinite ||
          ratio < 0.1 ||
          ratio > 10 ||
          rawPoints is! List ||
          rawPoints.length > groupPoseJointIds.length ||
          feedback is! String ||
          feedback.length > 40) {
        return null;
      }
      if (score != null &&
          (score is! num || !score.isFinite || score < 0 || score > 100)) {
        return null;
      }
      if ((status == GroupPoseStatus.tracking) != (score != null)) {
        return null;
      }
      final points = <GroupPosePoint>[];
      final seen = <int>{};
      for (final p in rawPoints) {
        if (p is! List ||
            p.length != 4 ||
            p[0] is! int ||
            !groupPoseJointIds.contains(p[0]) ||
            !seen.add(p[0])) {
          return null;
        }
        if (p.skip(1).any((v) => v is! num || !v.isFinite)) {
          return null;
        }
        if (p[1] < -1 ||
            p[1] > 2 ||
            p[2] < -1 ||
            p[2] > 2 ||
            p[3] < 0 ||
            p[3] > 1) {
          return null;
        }
        points.add(GroupPosePoint(p[0], (p[1] as num).toDouble(),
            (p[2] as num).toDouble(), (p[3] as num).toDouble()));
      }
      return (
        sequence: data['seq'] as int,
        frame: GroupPoseFrame(
          status: status,
          score: score == null ? null : (score as num).toDouble(),
          aspectRatio: ratio.toDouble(),
          points: points,
          feedback: feedback,
          sampledAt: now.subtract(Duration(milliseconds: age)),
        )
      );
    } catch (_) {
      return null;
    }
  }
}
