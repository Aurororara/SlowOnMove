from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated,AllowAny
from rest_framework.decorators import action
from rest_framework.response import Response

from django.db.models import Avg, Sum
from django.utils import timezone
from api.leaderboard_service import get_leaderboard

from core.models import Member, BodyRecord, BoardRanking, CommunityPost, Favorite, TrainingLog
from .serializers import (
    MemberSerializer, BodyRecordSerializer, BoardRankingSerializer,
    CommunityPostSerializer, FavoriteSerializer, TrainingLogSerializer
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
