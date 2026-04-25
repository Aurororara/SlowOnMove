from django.db import models
from django.contrib.auth.models import AbstractUser

class Member(AbstractUser):
    # AbstractUser provides username, email, password, date_joined, etc.
    pass

class BodyRecord(models.Model):
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='body_records')
    record_date = models.DateField()
    height = models.IntegerField()
    weight = models.IntegerField()

class BoardRanking(models.Model):
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='rankings')
    category = models.CharField(max_length=50)
    period_type = models.CharField(max_length=20)
    rank_position = models.IntegerField()

class CommunityPost(models.Model):
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='posts')
    content = models.TextField()
    image = models.CharField(max_length=255, blank=True, null=True)
    like_count = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

class Favorite(models.Model):
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='favorites')
    post = models.ForeignKey(CommunityPost, on_delete=models.CASCADE, related_name='favorited_by')
    created_at = models.DateTimeField(auto_now_add=True)

class TrainingLog(models.Model):
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='training_logs')
    start_time = models.DateTimeField()
    end_time = models.DateTimeField()
    total_mins = models.IntegerField()
    exercise_type = models.CharField(
        max_length=20,
        choices=[
            ("slow_jogging", "超慢跑"),
            ("squat", "深蹲"),
        ],
        default="slow_jogging",
    )
    posture_score = models.IntegerField()
    calories = models.IntegerField()
    created_at = models.DateTimeField(auto_now_add=True)
