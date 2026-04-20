from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from core.models import Member, BodyRecord, BoardRanking, CommunityPost, Favorite, TrainingLog
from .serializers import (
    MemberSerializer, BodyRecordSerializer, BoardRankingSerializer,
    CommunityPostSerializer, FavoriteSerializer, TrainingLogSerializer
)

class MemberViewSet(viewsets.ModelViewSet):
    queryset = Member.objects.all()
    serializer_class = MemberSerializer
    permission_classes = [IsAuthenticated]

class BodyRecordViewSet(viewsets.ModelViewSet):
    queryset = BodyRecord.objects.all()
    serializer_class = BodyRecordSerializer
    permission_classes = [IsAuthenticated]

class BoardRankingViewSet(viewsets.ModelViewSet):
    queryset = BoardRanking.objects.all()
    serializer_class = BoardRankingSerializer
    permission_classes = [IsAuthenticated]

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
    permission_classes = [IsAuthenticated]
