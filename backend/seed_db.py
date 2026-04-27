import os
import django
import datetime
import random
from django.utils import timezone

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "slow_on_move.settings")
django.setup()

from core.models import Member, BodyRecord, TrainingLog, CommunityPost


def create_training_log(user, exercise_type, start_time, posture_score, calories):
    end_time = start_time + datetime.timedelta(minutes=60)

    TrainingLog.objects.get_or_create(
        member=user,
        exercise_type=exercise_type,
        start_time=start_time,
        defaults={
            "end_time": end_time,
            "total_mins": 60,
            "posture_score": posture_score,
            "calories": calories,
        }
    )


def seed():
    print("Starting database seeding...")

    users_data = [
        {"username": "test_user_001", "email": "catherine@example.com", "days": 35, "base_score": 98},
        {"username": "sarah", "email": "sarah@example.com", "days": 30, "base_score": 95},
        {"username": "mike", "email": "mike@example.com", "days": 25, "base_score": 92},
        {"username": "emma", "email": "emma@example.com", "days": 20, "base_score": 89},
        {"username": "olivia", "email": "olivia@example.com", "days": 15, "base_score": 87},
        {"username": "james", "email": "james@example.com", "days": 10, "base_score": 85},
    ]

    now = timezone.now()

    for user_index, data in enumerate(users_data):
        user, created = Member.objects.get_or_create(
            username=data["username"],
            defaults={
                "email": data["email"],
                "date_joined": now - datetime.timedelta(days=data["days"]),
            }
        )

        if created:
            user.set_password("password123")
            user.save()
            print(f"Created user: {user.username}")
        else:
            print(f"User {user.username} already exists.")

        BodyRecord.objects.get_or_create(
            member=user,
            record_date=datetime.date.today(),
            defaults={
                "height": random.randint(160, 180),
                "weight": random.randint(55, 80),
            }
        )

        # =========================
        # 本週資料
        # =========================
        for i in range(3):
            start_time = now - datetime.timedelta(days=i, hours=1)

            create_training_log(
                user=user,
                exercise_type="slow_jogging",
                start_time=start_time,
                posture_score=data["base_score"] - i,
                calories=260 + user_index * 20 + random.randint(0, 40),
            )

            create_training_log(
                user=user,
                exercise_type="squat",
                start_time=start_time - datetime.timedelta(hours=2),
                posture_score=data["base_score"] - i - 3,
                calories=120 + user_index * 15 + random.randint(0, 30),
            )

        # =========================
        # 本月資料，但不是本週
        # =========================
        for i in range(2):
            start_time = now - datetime.timedelta(days=10 + i, hours=1)

            create_training_log(
                user=user,
                exercise_type="slow_jogging",
                start_time=start_time,
                posture_score=data["base_score"] - i - 2,
                calories=300 + user_index * 25 + random.randint(0, 50),
            )

            create_training_log(
                user=user,
                exercise_type="squat",
                start_time=start_time - datetime.timedelta(hours=2),
                posture_score=data["base_score"] - i - 4,
                calories=160 + user_index * 20 + random.randint(0, 40),
            )

        # =========================
        # 全部時間資料：上個月或更早
        # =========================
        for i in range(2):
            start_time = now - datetime.timedelta(days=40 + i, hours=1)

            create_training_log(
                user=user,
                exercise_type="slow_jogging",
                start_time=start_time,
                posture_score=data["base_score"] - i - 5,
                calories=350 + user_index * 30 + random.randint(0, 60),
            )

            create_training_log(
                user=user,
                exercise_type="squat",
                start_time=start_time - datetime.timedelta(hours=2),
                posture_score=data["base_score"] - i - 6,
                calories=180 + user_index * 25 + random.randint(0, 50),
            )

        CommunityPost.objects.get_or_create(
            member=user,
            content=f"{user.username} 今天完成了 60 分鐘訓練！",
            defaults={
                "like_count": random.randint(1, 30)
            }
        )

    print("Seeding complete! Slow jogging and squat leaderboard data created.")


if __name__ == "__main__":
    seed()