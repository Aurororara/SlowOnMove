from rest_framework import serializers
from core.models import (
    Member, BodyRecord, BoardRanking, CommunityPost, Favorite, TrainingLog,
    PostLike, PostComment, PostReport, PoseAnalysis, PointTransaction,
    Task, MemberTask, Badge, MemberBadge, WorkoutMenu, WorkoutItem
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

class BoardRankingSerializer(serializers.ModelSerializer):
    class Meta:
        model = BoardRanking
        fields = '__all__'

class CommunityPostSerializer(serializers.ModelSerializer):
    class Meta:
        model = CommunityPost
        fields = '__all__'

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
