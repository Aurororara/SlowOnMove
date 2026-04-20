from django.contrib import admin
from .models import Member, BodyRecord, BoardRanking, CommunityPost, Favorite, TrainingLog

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
