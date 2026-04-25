from django.db.models import Avg, Sum
from django.utils import timezone

from core.models import Member, TrainingLog


EXERCISE_TYPE_MAP = {
    "slow_jogging": "超慢跑",
    "squat": "深蹲",
}

PERIOD_ALL = "all"
PERIOD_WEEK = "week"
PERIOD_MONTH = "month"

POSTURE_WEIGHT = 0.7
CALORIE_WEIGHT = 0.3


def get_period_start_date(period):
    today = timezone.now().date()

    if period == PERIOD_WEEK:
        return today - timezone.timedelta(days=today.weekday())

    if period == PERIOD_MONTH:
        return today.replace(day=1)

    return None


def get_training_queryset(member=None, exercise_type=None, period=PERIOD_ALL):
    queryset = TrainingLog.objects.all()

    if member is not None:
        queryset = queryset.filter(member=member)

    if exercise_type:
        queryset = queryset.filter(exercise_type=exercise_type)

    start_date = get_period_start_date(period)
    if start_date:
        queryset = queryset.filter(start_time__date__gte=start_date)

    return queryset


def get_average_posture_score(member, exercise_type=None, period=PERIOD_ALL):
    result = get_training_queryset(
        member=member,
        exercise_type=exercise_type,
        period=period,
    ).aggregate(avg_posture=Avg("posture_score"))

    return result["avg_posture"] or 0


def get_total_calories(member, exercise_type=None, period=PERIOD_ALL):
    result = get_training_queryset(
        member=member,
        exercise_type=exercise_type,
        period=period,
    ).aggregate(total_calories=Sum("calories"))

    return result["total_calories"] or 0


def get_member_calories_map(exercise_type=None, period=PERIOD_ALL):
    queryset = get_training_queryset(
        exercise_type=exercise_type,
        period=period,
    )

    result = queryset.values("member").annotate(
        total_calories=Sum("calories")
    )

    return {
        item["member"]: item["total_calories"] or 0
        for item in result
    }


def calculate_calorie_score(total_calories, max_calories):
    if max_calories <= 0:
        return 0

    score = (total_calories / max_calories) * 100

    return min(score, 100)


def calculate_leaderboard_score(posture_score, calorie_score):
    posture_score = min(posture_score, 100)
    calorie_score = min(calorie_score, 100)

    score = posture_score * POSTURE_WEIGHT + calorie_score * CALORIE_WEIGHT

    return round(min(score, 100), 2)


def get_leaderboard(exercise_type=None, period=PERIOD_ALL):
    members = Member.objects.all()
    leaderboard = []

    calories_map = get_member_calories_map(
        exercise_type=exercise_type,
        period=period,
    )

    max_calories = max(calories_map.values(), default=0)

    for member in members:
        posture_score = get_average_posture_score(
            member=member,
            exercise_type=exercise_type,
            period=period,
        )

        total_calories = calories_map.get(member.id, 0)
        calorie_score = calculate_calorie_score(total_calories, max_calories)

        score = calculate_leaderboard_score(
            posture_score=posture_score,
            calorie_score=calorie_score,
        )

        leaderboard.append({
            "member_id": member.id,
            "username": member.username,
            "posture_score": round(posture_score, 2),
            "total_calories": round(total_calories, 2),
            "calorie_score": round(calorie_score, 2),
            "score": score,
        })

    leaderboard.sort(key=lambda item: item["score"], reverse=True)

    for index, item in enumerate(leaderboard):
        item["rank"] = index + 1

    return leaderboard