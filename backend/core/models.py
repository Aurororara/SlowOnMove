from django.db import models
from django.contrib.auth.models import AbstractUser
from django.db.models import Q

class Member(AbstractUser):
    avatar = models.URLField(max_length=500, blank=True, null=True)
    login_provider = models.CharField(max_length=50, blank=True, null=True)
    provider_id = models.CharField(max_length=100, blank=True, null=True)

class FriendRequest(models.Model):
    STATUS_PENDING = "pending"
    STATUS_ACCEPTED = "accepted"
    STATUS_REJECTED = "rejected"

    STATUS_CHOICES = [
        (STATUS_PENDING, "待處理"),
        (STATUS_ACCEPTED, "已接受"),
        (STATUS_REJECTED, "已拒絕"),
    ]

    sender = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name="sent_friend_requests",
    )
    receiver = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name="received_friend_requests",
    )
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default=STATUS_PENDING,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
        models.UniqueConstraint(
            fields=["sender", "receiver"],
            condition=models.Q(status="pending"),
            name="unique_pending_friend_request",
        ),
        models.CheckConstraint(
            check=~models.Q(sender=models.F("receiver")),
            name="friend_request_not_self",
        ),
    ]

    def __str__(self):
        return f"{self.sender_id} -> {self.receiver_id} ({self.status})"


class Friendship(models.Model):
    member1 = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name="friendships_as_member1",
    )
    member2 = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name="friendships_as_member2",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["member1", "member2"],
                name="unique_friendship_pair",
            ),
            models.CheckConstraint(
                check=~models.Q(member1=models.F("member2")),
                name="friendship_not_self",
            ),
        ]

    def __str__(self):
        return f"{self.member1_id} <-> {self.member2_id}"

class ChatMessage(models.Model):
    sender = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name="sent_chat_messages",
    )

    receiver = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name="received_chat_messages",
    )

    content = models.TextField()

    is_read = models.BooleanField(
        default=False,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    class Meta:
        ordering = ["created_at"]
        indexes = [
            models.Index(
                fields=["sender", "receiver", "created_at"],
            ),
            models.Index(
                fields=["receiver", "is_read"],
            ),
        ]

    def __str__(self):
        return (
            f"{self.sender_id} -> "
            f"{self.receiver_id}: "
            f"{self.content[:30]}"
        )

class RunInvitation(models.Model):
    STATUS_PENDING = "pending"
    STATUS_ACCEPTED = "accepted"
    STATUS_REJECTED = "rejected"
    STATUS_CANCELLED = "cancelled"

    STATUS_CHOICES = [
        (STATUS_PENDING, "待回覆"),
        (STATUS_ACCEPTED, "已接受"),
        (STATUS_REJECTED, "已拒絕"),
        (STATUS_CANCELLED, "已取消"),
    ]

    inviter = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name="sent_run_invitations",
    )

    invitee = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name="received_run_invitations",
    )

    scheduled_at = models.DateTimeField()

    target_distance_km = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True,
    )

    target_duration_minutes = models.PositiveIntegerField(
        null=True,
        blank=True,
    )

    notes = models.TextField(
        blank=True,
        default="",
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default=STATUS_PENDING,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    responded_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    class Meta:
        ordering = ["created_at"]

        indexes = [
            models.Index(
                fields=["inviter", "created_at"],
            ),
            models.Index(
                fields=["invitee", "status", "created_at"],
            ),
        ]

        constraints = [
            models.CheckConstraint(
                check=~models.Q(
                    inviter=models.F("invitee"),
                ),
                name="run_invitation_not_self",
            ),
        ]

    def __str__(self):
        return (
            f"{self.inviter_id} -> "
            f"{self.invitee_id} "
            f"({self.status})"
        )

class CommunityGroup(models.Model):
    owner = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name="owned_community_groups",
    )

    name = models.CharField(
        max_length=100,
    )

    description = models.TextField(
        blank=True,
        default="",
    )

    is_private = models.BooleanField(
        default=False,
    )

    exercise_type = models.CharField(
        max_length=20,
        choices=[
            ("mixed", "超慢跑＋深蹲"),
            ("slow_jogging", "超慢跑"),
            ("squat", "深蹲"),
        ],
        default="mixed",
    )

    weekly_goal_target = models.PositiveIntegerField(
        default=20,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return self.name


class CommunityGroupMember(models.Model):
    group = models.ForeignKey(
        CommunityGroup,
        on_delete=models.CASCADE,
        related_name="group_members",
    )

    member = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name="community_group_memberships",
    )

    joined_at = models.DateTimeField(
        auto_now_add=True,
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["group", "member"],
                name="unique_community_group_member",
            ),
        ]

    def __str__(self):
        return f"{self.group_id} - {self.member_id}"

class CommunityGroupActivity(models.Model):
    group = models.ForeignKey(
        CommunityGroup,
        on_delete=models.CASCADE,
        related_name="activities",
    )

    creator = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name="created_group_activities",
    )

    title = models.CharField(
        max_length=100,
    )

    exercise_type = models.CharField(
        max_length=20,
        choices=[
            ("slow_jogging", "超慢跑"),
            ("squat", "深蹲"),
        ],
    )

    scheduled_at = models.DateTimeField()

    notes = models.TextField(
        blank=True,
        default="",
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        ordering = [
            "scheduled_at",
            "created_at",
        ]

    def __str__(self):
        return f"{self.group.name} - {self.title}"

class CommunityGroupActivityParticipant(models.Model):
    activity = models.ForeignKey(
        CommunityGroupActivity,
        on_delete=models.CASCADE,
        related_name="participants",
    )

    member = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name="community_group_activity_participations",
    )

    joined_at = models.DateTimeField(
        auto_now_add=True,
    )

    class Meta:
        ordering = [
            "joined_at",
        ]

        constraints = [
            models.UniqueConstraint(
                fields=[
                    "activity",
                    "member",
                ],
                name="unique_group_activity_participant",
            ),
        ]

    def __str__(self):
        return (
            f"{self.activity_id} - "
            f"{self.member_id}"
        )

class CommunityGroupJoinRequest(models.Model):
    STATUS_PENDING = "pending"
    STATUS_ACCEPTED = "accepted"
    STATUS_REJECTED = "rejected"

    STATUS_CHOICES = [
        (STATUS_PENDING, "Pending"),
        (STATUS_ACCEPTED, "Accepted"),
        (STATUS_REJECTED, "Rejected"),
    ]

    group = models.ForeignKey(
        CommunityGroup,
        on_delete=models.CASCADE,
        related_name="join_requests",
    )

    requester = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name="community_group_join_requests",
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default=STATUS_PENDING,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    responded_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=[
                    "group",
                    "requester",
                ],
                condition=Q(status="pending"),
                name="unique_pending_group_join_request",
            ),
        ]

class CommunityGroupInvitation(models.Model):
    STATUS_PENDING = "pending"
    STATUS_ACCEPTED = "accepted"
    STATUS_REJECTED = "rejected"

    STATUS_CHOICES = [
        (STATUS_PENDING, "待回覆"),
        (STATUS_ACCEPTED, "已接受"),
        (STATUS_REJECTED, "已拒絕"),
    ]

    group = models.ForeignKey(
        CommunityGroup,
        on_delete=models.CASCADE,
        related_name="invitations",
    )

    inviter = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name="sent_group_invitations",
    )

    invitee = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name="received_group_invitations",
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default=STATUS_PENDING,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    responded_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    class Meta:
        ordering = ["-created_at"]

        indexes = [
            models.Index(
                fields=["invitee", "status", "created_at"],
            ),
            models.Index(
                fields=["group", "status", "created_at"],
            ),
        ]

        constraints = [
            models.UniqueConstraint(
                fields=["group", "invitee"],
                condition=models.Q(status="pending"),
                name="unique_pending_group_invitation",
            ),
        ]

    def __str__(self):
        return (
            f"group={self.group_id}, "
            f"{self.inviter_id} -> {self.invitee_id} "
            f"({self.status})"
        )

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
    member = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name='favorites'
    )
    post = models.ForeignKey(
        CommunityPost,
        on_delete=models.CASCADE,
        related_name='favorited_by'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['member', 'post'],
                name='unique_member_favorite_post',
            ),
        ]

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
    member = models.ForeignKey(
        Member,
        on_delete=models.CASCADE,
        related_name='post_likes'
    )
    post = models.ForeignKey(
        CommunityPost,
        on_delete=models.CASCADE,
        related_name='likes'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['member', 'post'],
                name='unique_member_like_post',
            ),
        ]

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
