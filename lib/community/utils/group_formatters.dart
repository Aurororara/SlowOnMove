String groupMetricUnit(String exerciseType) {
  switch (exerciseType) {
    case 'mixed':
      return '次活動';
    case 'squat':
      return '次深蹲';
    case 'slow_jogging':
    default:
      return '次慢跑';
  }
}

String groupWeeklyGoalLabel(
  String exerciseType,
  int current,
  int target,
) {
  return '$current/$target ${groupMetricUnit(exerciseType)}';
}
