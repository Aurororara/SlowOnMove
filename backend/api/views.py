from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated,AllowAny
from rest_framework.decorators import action
from rest_framework.response import Response

from django.db.models import Avg, Sum
from api.leaderboard_service import get_leaderboard

from core.models import (
    Member, BodyRecord, BoardRanking, CommunityPost, Favorite, TrainingLog,
    PostLike, PostComment, PostReport, PoseAnalysis, PointTransaction,
    Task, MemberTask, Badge, MemberBadge, WorkoutMenu, WorkoutItem
)
from .serializers import (
    MemberSerializer, BodyRecordSerializer, BoardRankingSerializer,
    CommunityPostSerializer, FavoriteSerializer, TrainingLogSerializer,
    PostLikeSerializer, PostCommentSerializer, PostReportSerializer, PoseAnalysisSerializer, PointTransactionSerializer,
    TaskSerializer, MemberTaskSerializer, BadgeSerializer, MemberBadgeSerializer, WorkoutMenuSerializer, WorkoutItemSerializer
)


#  =========================
# 排行榜邏輯
#  =========================

ALLOWED_EXERCISE_TYPES = ["slow_jogging", "squat"]
ALLOWED_PERIODS = ["week", "month", "all"]

class MemberViewSet(viewsets.ModelViewSet):
    queryset = Member.objects.all()
    serializer_class = MemberSerializer
    permission_classes = [AllowAny]

    # 排行榜 API
    @action(detail=False, methods=["get"], url_path="leaderboard")
    def leaderboard(self, request):
        exercise_type = request.query_params.get("exercise_type")
        period = request.query_params.get("period", "all")

        if exercise_type not in ["slow_jogging", "squat"]:
            exercise_type = None

        if period not in ["week", "month", "all"]:
            period = "all"

        data = get_leaderboard(
            exercise_type=exercise_type,
            period=period,
        )

        return Response({
            "message": "排行榜取得成功",
            "exercise_type": exercise_type,
            "period": period,
            "data": data,
        })

class BodyRecordViewSet(viewsets.ModelViewSet):
    queryset = BodyRecord.objects.all()
    serializer_class = BodyRecordSerializer
    permission_classes = [AllowAny]
   # permission_classes = [IsAuthenticated]


class BoardRankingViewSet(viewsets.ModelViewSet):
    queryset = BoardRanking.objects.all()
    serializer_class = BoardRankingSerializer
    permission_classes = [AllowAny]
   # permission_classes = [IsAuthenticated]

class CommunityPostViewSet(viewsets.ModelViewSet):
    queryset = CommunityPost.objects.all()
    serializer_class = CommunityPostSerializer
    permission_classes = [IsAuthenticated]

class FavoriteViewSet(viewsets.ModelViewSet):
    queryset = Favorite.objects.all()
    serializer_class = FavoriteSerializer
    permission_classes = [IsAuthenticated]

class TrainingLogViewSet(viewsets.ModelViewSet):
    queryset = TrainingLog.objects.all()
    serializer_class = TrainingLogSerializer
    permission_classes = [AllowAny]
    #permission_classes = [IsAuthenticated]
    # ⭐個人運動數據加總 API
    @action(detail=False, methods=['get'], url_path='my-stats')
    def my_stats(self, request):
        member_id = request.query_params.get('member_id')
        
        if not member_id:
            return Response({"error": "缺少 member_id 參數"}, status=400)

        # 篩選該會員的所有運動紀錄
        user_logs = TrainingLog.objects.filter(member_id=member_id)
        
        # 讓資料庫直接幫我們加總 (效能最高)
        stats = user_logs.aggregate(
            total_time=Sum('total_mins'),
            total_calories=Sum('calories'),
            total_steps=Sum('step_count'),
            total_distance=Sum('distance'),
        )

        # 如果沒有紀錄，Sum 會回傳 None，所以要用 'or 0' 給預設值
        return Response({
            "member_id": member_id,
            "workout_count": user_logs.count(), # 總運動次數
            "total_time": stats['total_time'] or 0,
            "total_calories": stats['total_calories'] or 0,
            "total_steps": stats['total_steps'] or 0,
            "total_distance": round(stats['total_distance'] or 0.0, 2)
        })

class PostLikeViewSet(viewsets.ModelViewSet):
    queryset = PostLike.objects.all()
    serializer_class = PostLikeSerializer
    permission_classes = [AllowAny]

class PostCommentViewSet(viewsets.ModelViewSet):
    queryset = PostComment.objects.all()
    serializer_class = PostCommentSerializer
    permission_classes = [AllowAny]

class PostReportViewSet(viewsets.ModelViewSet):
    queryset = PostReport.objects.all()
    serializer_class = PostReportSerializer
    permission_classes = [AllowAny]

class PoseAnalysisViewSet(viewsets.ModelViewSet):
    queryset = PoseAnalysis.objects.all()
    serializer_class = PoseAnalysisSerializer
    permission_classes = [AllowAny]

class PointTransactionViewSet(viewsets.ModelViewSet):
    queryset = PointTransaction.objects.all()
    serializer_class = PointTransactionSerializer
    permission_classes = [AllowAny]

class TaskViewSet(viewsets.ModelViewSet):
    queryset = Task.objects.all()
    serializer_class = TaskSerializer
    permission_classes = [AllowAny]

class MemberTaskViewSet(viewsets.ModelViewSet):
    queryset = MemberTask.objects.all()
    serializer_class = MemberTaskSerializer
    permission_classes = [AllowAny]

class BadgeViewSet(viewsets.ModelViewSet):
    queryset = Badge.objects.all()
    serializer_class = BadgeSerializer
    permission_classes = [AllowAny]

class MemberBadgeViewSet(viewsets.ModelViewSet):
    queryset = MemberBadge.objects.all()
    serializer_class = MemberBadgeSerializer
    permission_classes = [AllowAny]

class WorkoutMenuViewSet(viewsets.ModelViewSet):
    queryset = WorkoutMenu.objects.all()
    serializer_class = WorkoutMenuSerializer
    permission_classes = [AllowAny]

class WorkoutItemViewSet(viewsets.ModelViewSet):
    queryset = WorkoutItem.objects.all()
    serializer_class = WorkoutItemSerializer
    permission_classes = [AllowAny]
