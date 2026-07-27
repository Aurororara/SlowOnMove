from django.contrib import admin
from .models import (
    Member, BodyRecord, BoardRanking, CommunityPost, Favorite, TrainingLog,
    PostLike, PostComment, PostReport, PoseAnalysis, PointTransaction,
    Task, MemberTask, Badge, MemberBadge, WorkoutMenu, WorkoutItem
)

@admin.register(Member)
class MemberAdmin(admin.ModelAdmin):
    list_display = ('username', 'email', 'date_joined')

@admin.register(BodyRecord)
class BodyRecordAdmin(admin.ModelAdmin):
    list_display = ('member', 'record_date', 'height', 'weight')

@admin.register(BoardRanking)
class BoardRankingAdmin(admin.ModelAdmin):
    list_display = ('member', 'category', 'period_type', 'rank_position')

@admin.register(CommunityPost)
class CommunityPostAdmin(admin.ModelAdmin):
    list_display = ('member', 'content', 'like_count', 'created_at')

@admin.register(Favorite)
class FavoriteAdmin(admin.ModelAdmin):
    list_display = ('member', 'post', 'created_at')

@admin.register(TrainingLog)
class TrainingLogAdmin(admin.ModelAdmin):
    list_display = ('member', 'start_time', 'end_time', 'total_mins', 'posture_score')

@admin.register(PostLike)
class PostLikeAdmin(admin.ModelAdmin):
    list_display = ('member', 'post', 'created_at')

@admin.register(PostComment)
class PostCommentAdmin(admin.ModelAdmin):
    list_display = ('member', 'post', 'created_at')

@admin.register(PostReport)
class PostReportAdmin(admin.ModelAdmin):
    list_display = ('member', 'post', 'reason', 'status', 'created_at')

@admin.register(PoseAnalysis)
class PoseAnalysisAdmin(admin.ModelAdmin):
    list_display = ('log', 'status', 'error_time')

@admin.register(PointTransaction)
class PointTransactionAdmin(admin.ModelAdmin):
    list_display = ('member', 'points_changed', 'tran_type', 'created_at')

@admin.register(Task)
class TaskAdmin(admin.ModelAdmin):
    list_display = ('member', 'status', 'current', 'completed_at')

@admin.register(MemberTask)
class MemberTaskAdmin(admin.ModelAdmin):
    list_display = ('member', 'task', 'status', 'current')

@admin.register(Badge)
class BadgeAdmin(admin.ModelAdmin):
    list_display = ('badge_name', 'created_at')

@admin.register(MemberBadge)
class MemberBadgeAdmin(admin.ModelAdmin):
    list_display = ('member', 'badge', 'earn_at')

@admin.register(WorkoutMenu)
class WorkoutMenuAdmin(admin.ModelAdmin):
    list_display = ('member', 'title', 'is_public', 'created_at')

@admin.register(WorkoutItem)
class WorkoutItemAdmin(admin.ModelAdmin):
    list_display = ('member', 'menu', 'save_at')
