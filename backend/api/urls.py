from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    MemberViewSet, BodyRecordViewSet, BoardRankingViewSet,
    CommunityPostViewSet, FavoriteViewSet, TrainingLogViewSet
)
from .auth_views import GoogleLoginView, FacebookLoginView

router = DefaultRouter()
router.register(r'members', MemberViewSet)
router.register(r'body-records', BodyRecordViewSet)
router.register(r'board-rankings', BoardRankingViewSet)
router.register(r'community-posts', CommunityPostViewSet)
router.register(r'favorites', FavoriteViewSet)
router.register(r'training-logs', TrainingLogViewSet)

urlpatterns = [
    path('auth/google/', GoogleLoginView.as_view(), name='auth-google'),
    path('auth/facebook/', FacebookLoginView.as_view(), name='auth-facebook'),
    path('', include(router.urls)),
]
