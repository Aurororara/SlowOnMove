from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    MemberViewSet, BodyRecordViewSet, BoardRankingViewSet,
    CommunityPostViewSet, FavoriteViewSet, TrainingLogViewSet
)

router = DefaultRouter()
router.register(r'members', MemberViewSet)
router.register(r'body-records', BodyRecordViewSet)
router.register(r'board-rankings', BoardRankingViewSet)
router.register(r'community-posts', CommunityPostViewSet)
router.register(r'favorites', FavoriteViewSet)
router.register(r'training-logs', TrainingLogViewSet)

urlpatterns = [
    path('', include(router.urls)),
]
