from django.db import models
from django.contrib.auth.models import AbstractUser

class Member(AbstractUser):
    avatar = models.URLField(max_length=500, blank=True, null=True)
    login_provider = models.CharField(max_length=50, blank=True, null=True)
    provider_id = models.CharField(max_length=100, blank=True, null=True)

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
    step_count = models.IntegerField(default=0)
    distance = models.FloatField(default=0.0)
    created_at = models.DateTimeField(auto_now_add=True)
