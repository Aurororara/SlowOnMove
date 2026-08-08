from django.db import models
from django.contrib.auth.models import AbstractUser

class Member(AbstractUser):
    avatar = models.URLField(max_length=500, blank=True, null=True)
    login_provider = models.CharField(max_length=50, blank=True, null=True)
    provider_id = models.CharField(max_length=100, blank=True, null=True)

class BodyRecord(models.Model):

    member = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name='body_records'
    )

    record_date = models.DateField()

    height = models.IntegerField()

    weight = models.IntegerField()

    created_at = models.DateTimeField(
        auto_now_add=True
    )

class BloodPressureRecord(models.Model):

    member = models.ForeignKey(
        Member,
        on_delete=models.CASCADE
    )

    systolic = models.IntegerField()

    diastolic = models.IntegerField()

    pulse = models.IntegerField()

    record_date = models.DateField()

    created_at = models.DateTimeField(
        auto_now_add=True
    )

class BoardRanking(models.Model):
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='rankings')
    category = models.CharField(max_length=50)
    period_type = models.CharField(max_length=20)
    rank_position = models.IntegerField()

class CommunityPost(models.Model):
    POST_TYPE_CHOICES = [
        ("journey", "旅程"),
        ("plan", "計畫"),
        ("recipe", "食譜"),
    ]
    member = models.ForeignKey(
        Member,
        on_delete=models.CASCADE, related_name='posts'
    )
    post_type = models.CharField(
        max_length=20,
        choices=POST_TYPE_CHOICES,
        default="journey"
    )
    content = models.TextField()
    image = models.CharField(
        max_length=255,
        blank=True,
        null=True
    )
    created_at = models.DateTimeField(
        auto_now_add=True
    )
    updated_at = models.DateTimeField(
        auto_now=True
    )

    def __str__(self):
        return f"{self.member.username} - {self.post_type} - {self.id}"


class PostTag(models.Model):
    post = models.ForeignKey(
        CommunityPost,
        on_delete=models.CASCADE,
        related_name="tags"
    )
    name = models.CharField(
        max_length=50
    )

    def __str__(self):
        return self.name


class PostWorkoutPlan(models.Model):
    post = models.OneToOneField(
        CommunityPost,
        on_delete=models.CASCADE,
        related_name="workout_plan"
    )
    title = models.CharField(
        max_length=255
    )
    summary = models.TextField(
        blank=True
    )
    difficulty = models.CharField(
        max_length=50,
        default="中等"
    )
    total_minutes = models.IntegerField(
        default=0
    )

    def __str__(self):
        return self.title


class PostWorkoutPlanStep(models.Model):
    plan = models.ForeignKey(
        PostWorkoutPlan,
        on_delete=models.CASCADE,
        related_name="steps"
    )
    name = models.CharField(
        max_length=255
    )
    minutes = models.IntegerField()
    order = models.IntegerField(
        default=0
    )
    class Meta:
        ordering = ["order"]

    def __str__(self):
        return f"{self.name} - {self.minutes}分鐘"


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
    created_at = models.DateTimeField(auto_now_add=True)

class PostLike(models.Model):
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='post_likes')
    post = models.ForeignKey(CommunityPost, on_delete=models.CASCADE, related_name='likes')
    created_at = models.DateTimeField(auto_now_add=True)

class PostComment(models.Model):
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='post_comments')
    post = models.ForeignKey(CommunityPost, on_delete=models.CASCADE, related_name='comments')
    content = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

class PostReport(models.Model):
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='post_reports')
    post = models.ForeignKey(CommunityPost, on_delete=models.CASCADE, related_name='reports')
    reason = models.CharField(max_length=255)
    status = models.CharField(max_length=50)
    created_at = models.DateTimeField(auto_now_add=True)

class PoseAnalysis(models.Model):
    log = models.ForeignKey(TrainingLog, on_delete=models.CASCADE, related_name='pose_analyses')
    status = models.CharField(max_length=255)
    error_time = models.IntegerField()

class PointTransaction(models.Model):
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='point_transactions')
    points_changed = models.IntegerField()
    tran_type = models.CharField(max_length=50)
    created_at = models.DateTimeField(auto_now_add=True)

class Task(models.Model):
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='created_tasks', null=True, blank=True)
    status = models.CharField(max_length=50)
    current = models.IntegerField()
    completed_at = models.DateTimeField(null=True, blank=True)

class MemberTask(models.Model):
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='assigned_tasks', null=True, blank=True)
    task = models.ForeignKey(Task, on_delete=models.CASCADE, related_name='member_tasks')
    status = models.CharField(max_length=255)
    current = models.IntegerField()
    completed = models.DateTimeField(null=True, blank=True)

class Badge(models.Model):
    badge_name = models.CharField(max_length=100)
    description = models.CharField(max_length=255)
    badge_icon = models.CharField(max_length=50)
    created_at = models.DateTimeField(auto_now_add=True)

class MemberBadge(models.Model):
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='badges')
    badge = models.ForeignKey(Badge, on_delete=models.CASCADE, related_name='earned_by')
    earn_at = models.DateTimeField(auto_now_add=True)

class WorkoutMenu(models.Model):
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='workout_menus')
    title = models.CharField(max_length=255)
    description = models.CharField(max_length=255)
    is_public = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    update_at = models.DateTimeField(auto_now=True)

class WorkoutItem(models.Model):
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='workout_items')
    menu = models.ForeignKey(WorkoutMenu, on_delete=models.CASCADE, related_name='items')
    save_at = models.DateTimeField(auto_now_add=True)
