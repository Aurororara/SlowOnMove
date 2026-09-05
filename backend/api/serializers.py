from rest_framework import serializers
from django.utils import timezone
from django.db.models import Q
from core.models import (
    Member, BodyRecord, BloodPressureRecord, BoardRanking, CommunityPost, Favorite, TrainingLog,
    PostLike, PostComment, PostReport, PoseAnalysis, PointTransaction,
    PostTag, PostWorkoutPlan, PostWorkoutPlanStep,
    Task, MemberTask, Badge, MemberBadge, WorkoutMenu, WorkoutItem,FriendRequest,Friendship, ChatMessage, RunInvitation,
    CommunityGroup, CommunityGroupMember, CommunityGroupInvitation,
    CommunityGroupActivity,
    CommunityGroupJoinRequest,
)

class MemberSerializer(serializers.ModelSerializer):
    class Meta:
        model = Member
        fields = ['id', 'username', 'email', 'date_joined',]
        read_only_fields = ['id', 'date_joined']

class BodyRecordSerializer(serializers.ModelSerializer):
    class Meta:
        model = BodyRecord
        fields = '__all__'

class BloodPressureRecordSerializer(serializers.ModelSerializer):
    class Meta:
        model = BloodPressureRecord
        fields = '__all__'


class BoardRankingSerializer(serializers.ModelSerializer):
    class Meta:
        model = BoardRanking
        fields = '__all__'

class PostWorkoutPlanStepSerializer(serializers.ModelSerializer):
    class Meta:
        model = PostWorkoutPlanStep
        fields = [
            "id",
            "name",
            "minutes",
            "order",
        ]


class PostWorkoutPlanSerializer(serializers.ModelSerializer):
    steps = PostWorkoutPlanStepSerializer(
        many=True,
        read_only=True
    )

    class Meta:
        model = PostWorkoutPlan
        fields = [
            "id",
            "title",
            "summary",
            "difficulty",
            "total_minutes",
            "steps",
        ]

class CommunityPostSerializer(serializers.ModelSerializer):
    member_id = serializers.IntegerField(
        source="member.id",
        read_only=True
    )

    member_name = serializers.SerializerMethodField()

    member_initial = serializers.SerializerMethodField()

    member_avatar = serializers.CharField(
        source="member.avatar",
        read_only=True,
        allow_null=True
    )

    tags = serializers.SerializerMethodField()

    workout_plan = PostWorkoutPlanSerializer(
        read_only=True
    )

    like_count = serializers.SerializerMethodField()

    comment_count = serializers.SerializerMethodField()

    is_liked = serializers.SerializerMethodField()

    is_saved = serializers.SerializerMethodField()

    time_ago = serializers.SerializerMethodField()

    class Meta:
        model = CommunityPost

        fields = [
            "id",
            "member_id",
            "member_name",
            "member_initial",
            "member_avatar",
            "post_type",
            "content",
            "image",
            "tags",
            "workout_plan",
            "like_count",
            "comment_count",
            "is_liked",
            "is_saved",
            "time_ago",
            "created_at",
            "updated_at",
        ]

        read_only_fields = [
            "id",
            "member_id",
            "member_name",
            "member_initial",
            "member_avatar",
            "like_count",
            "comment_count",
            "is_liked",
            "is_saved",
            "time_ago",
            "created_at",
            "updated_at",
        ]

    def get_member_name(self, obj):
        full_name = obj.member.get_full_name().strip()

        if full_name:
            return full_name

        return obj.member.username


    def get_member_initial(self, obj):
        name = self.get_member_name(obj)

        if not name:
            return "U"

        return name[0].upper()


    def get_tags(self, obj):
        return [
            tag.name
            for tag in obj.tags.all()
        ]


    def get_like_count(self, obj):
        return obj.likes.count()


    def get_comment_count(self, obj):
        return obj.comments.count()


    def get_is_liked(self, obj):
        request = self.context.get("request")

        if not request:
            return False

        if not request.user.is_authenticated:
            return False

        return obj.likes.filter(
            member=request.user
        ).exists()


    def get_is_saved(self, obj):
        request = self.context.get("request")

        if not request:
            return False

        if not request.user.is_authenticated:
            return False

        return obj.favorited_by.filter(
            member=request.user
        ).exists()


    def get_time_ago(self, obj):

        now = timezone.now()
        diff = now - obj.created_at

        seconds = int(diff.total_seconds())

        if seconds < 60:
            return "剛剛"

        minutes = seconds // 60

        if minutes < 60:
            return f"{minutes} 分鐘前"

        hours = minutes // 60

        if hours < 24:
            return f"{hours} 小時前"

        days = hours // 24

        if days == 1:
            return "昨天"

        if days < 7:
            return f"{days} 天前"

        return obj.created_at.strftime("%Y/%m/%d")

class FavoriteSerializer(serializers.ModelSerializer):
    class Meta:
        model = Favorite
        fields = '__all__'

class TrainingLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = TrainingLog
        fields = '__all__'

class PostLikeSerializer(serializers.ModelSerializer):
    class Meta:
        model = PostLike
        fields = '__all__'

class PostCommentSerializer(serializers.ModelSerializer):
    class Meta:
        model = PostComment
        fields = '__all__'

class PostReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = PostReport
        fields = '__all__'

class PoseAnalysisSerializer(serializers.ModelSerializer):
    class Meta:
        model = PoseAnalysis
        fields = '__all__'

class PointTransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = PointTransaction
        fields = '__all__'

class TaskSerializer(serializers.ModelSerializer):
    class Meta:
        model = Task
        fields = '__all__'

class MemberTaskSerializer(serializers.ModelSerializer):
    class Meta:
        model = MemberTask
        fields = '__all__'

class BadgeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Badge
        fields = '__all__'

class MemberBadgeSerializer(serializers.ModelSerializer):
    class Meta:
        model = MemberBadge
        fields = '__all__'

class WorkoutMenuSerializer(serializers.ModelSerializer):
    class Meta:
        model = WorkoutMenu
        fields = '__all__'

class WorkoutItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = WorkoutItem
        fields = '__all__'

class FriendMemberSerializer(serializers.ModelSerializer):
    name = serializers.SerializerMethodField()
    initial = serializers.SerializerMethodField()

    class Meta:
        model = Member
        fields = [
            "id",
            "name",
            "initial",
            "avatar",
        ]

    def get_name(self, obj):
        return obj.get_full_name().strip() or obj.username

    def get_initial(self, obj):
        name = self.get_name(obj)

        if not name:
            return "U"

        return name[0].upper()

class FriendSearchSerializer(FriendMemberSerializer):
    relationship = serializers.SerializerMethodField()

    class Meta(FriendMemberSerializer.Meta):
        fields = FriendMemberSerializer.Meta.fields + [
            "relationship",
        ]

    def get_relationship(self, obj):
        request = self.context.get("request")

        if request is None:
            return "none"

        user = request.user

        # 已經是好友
        is_friend = Friendship.objects.filter(
            Q(member1=user, member2=obj)
            | Q(member1=obj, member2=user)
        ).exists()

        if is_friend:
            return "friend"

        # 我已送出邀請
        sent = FriendRequest.objects.filter(
            sender=user,
            receiver=obj,
            status=FriendRequest.STATUS_PENDING,
        ).exists()

        if sent:
            return "sent"

        # 對方已邀請我
        received = FriendRequest.objects.filter(
            sender=obj,
            receiver=user,
            status=FriendRequest.STATUS_PENDING,
        ).exists()

        if received:
            return "received"

        return "none"

class FriendRequestSerializer(serializers.ModelSerializer):
    sender = FriendMemberSerializer(read_only=True)
    receiver = FriendMemberSerializer(read_only=True)

    class Meta:
        model = FriendRequest
        fields = [
            "id",
            "sender",
            "receiver",
            "status",
            "created_at",
        ]

class ChatMessageSerializer(serializers.ModelSerializer):
    is_mine = serializers.SerializerMethodField()

    class Meta:
        model = ChatMessage
        fields = [
            "id",
            "sender_id",
            "receiver_id",
            "content",
            "is_mine",
            "is_read",
            "created_at",
        ]

        read_only_fields = [
            "id",
            "sender_id",
            "receiver_id",
            "is_mine",
            "is_read",
            "created_at",
        ]

    def get_is_mine(self, obj):
        request = self.context.get("request")

        return (
            request is not None
            and obj.sender_id == request.user.id
        )

class RunInvitationSerializer(serializers.ModelSerializer):
    inviter = FriendMemberSerializer(
        read_only=True,
    )

    invitee = FriendMemberSerializer(
        read_only=True,
    )

    class Meta:
        model = RunInvitation

        fields = [
            "id",
            "inviter",
            "invitee",
            "scheduled_at",
            "target_distance_km",
            "target_duration_minutes",
            "notes",
            "status",
            "created_at",
            "updated_at",
            "responded_at",
        ]

        read_only_fields = [
            "id",
            "inviter",
            "invitee",
            "status",
            "created_at",
            "updated_at",
            "responded_at",
        ]

class CommunityGroupMemberSerializer(serializers.ModelSerializer):
    member = FriendMemberSerializer(
        read_only=True,
    )

    class Meta:
        model = CommunityGroupMember

        fields = [
            "id",
            "member",
            "joined_at",
        ]

        read_only_fields = [
            "id",
            "member",
            "joined_at",
        ]


class CommunityGroupSerializer(serializers.ModelSerializer):
    owner = FriendMemberSerializer(
        read_only=True,
    )

    member_count = serializers.SerializerMethodField()

    members = CommunityGroupMemberSerializer(
        source="group_members",
        many=True,
        read_only=True,
    )

    class Meta:
        model = CommunityGroup

        fields = [
            "id",
            "owner",
            "name",
            "description",
            "is_private",
            "exercise_type",
            "weekly_goal_target",
            "member_count",
            "members",
            "created_at",
            "updated_at",
        ]

        read_only_fields = [
            "id",
            "owner",
            "member_count",
            "members",
            "created_at",
            "updated_at",
        ]

    def get_member_count(self, obj):
        return obj.group_members.count()

class CommunityGroupJoinRequestSerializer(
    serializers.ModelSerializer
):
    requester = FriendMemberSerializer(
        read_only=True,
    )

    group_id = serializers.IntegerField(
        source="group.id",
        read_only=True,
    )

    group_name = serializers.CharField(
        source="group.name",
        read_only=True,
    )

    class Meta:
        model = CommunityGroupJoinRequest

        fields = [
            "id",
            "group_id",
            "group_name",
            "requester",
            "status",
            "created_at",
            "updated_at",
            "responded_at",
        ]

        read_only_fields = fields


class CommunityGroupInvitationSerializer(serializers.ModelSerializer):
    inviter = FriendMemberSerializer(
        read_only=True,
    )

    invitee = FriendMemberSerializer(
        read_only=True,
    )

    group_id = serializers.IntegerField(
        source="group.id",
        read_only=True,
    )

    group_name = serializers.CharField(
        source="group.name",
        read_only=True,
    )

    class Meta:
        model = CommunityGroupInvitation

        fields = [
            "id",
            "group_id",
            "group_name",
            "inviter",
            "invitee",
            "status",
            "created_at",
            "updated_at",
            "responded_at",
        ]

        read_only_fields = [
            "id",
            "group_id",
            "group_name",
            "inviter",
            "invitee",
            "status",
            "created_at",
            "updated_at",
            "responded_at",
        ]

class CommunityGroupActivitySerializer(serializers.ModelSerializer):
    creator = FriendMemberSerializer(
        read_only=True,
    )

    group_id = serializers.IntegerField(
        source="group.id",
        read_only=True,
    )

    participant_count = serializers.SerializerMethodField()

    is_joined = serializers.SerializerMethodField()

    class Meta:
        model = CommunityGroupActivity

        fields = [
            "id",
            "group_id",
            "creator",
            "title",
            "exercise_type",
            "scheduled_at",
            "notes",
            "participant_count",
            "is_joined",
            "created_at",
            "updated_at",
        ]

        read_only_fields = [
            "id",
            "group_id",
            "creator",
            "participant_count",
            "is_joined",
            "created_at",
            "updated_at",
        ]

    def get_participant_count(self, obj):
        return obj.participants.count()

    def get_is_joined(self, obj):
        request = self.context.get("request")

        if request is None or not request.user.is_authenticated:
            return False

        return obj.participants.filter(
            member=request.user,
        ).exists()