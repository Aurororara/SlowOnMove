from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    MemberViewSet, BodyRecordViewSet, BloodPressureRecordViewSet, BoardRankingViewSet,
    CommunityPostViewSet, FavoriteViewSet, TrainingLogViewSet,
    PostLikeViewSet, PostCommentViewSet, PostReportViewSet, PoseAnalysisViewSet, PointTransactionViewSet,
    TaskViewSet, MemberTaskViewSet, BadgeViewSet, MemberBadgeViewSet, WorkoutMenuViewSet, WorkoutItemViewSet
)
from .auth_views import GoogleLoginView, FacebookLoginView, RegisterView, LoginView

router = DefaultRouter()
router.register(r'members', MemberViewSet)
router.register(r'body-records', BodyRecordViewSet)
router.register(r'blood-pressure-records', BloodPressureRecordViewSet)
router.register(r'board-rankings', BoardRankingViewSet)
router.register(
    r'community-posts',
    CommunityPostViewSet,
    basename='community-post'
)
router.register(r'favorites', FavoriteViewSet)
router.register(r'training-logs', TrainingLogViewSet)
router.register(r'post-likes', PostLikeViewSet)
router.register(r'post-comments', PostCommentViewSet)
router.register(r'post-reports', PostReportViewSet)
router.register(r'pose-analyses', PoseAnalysisViewSet)
router.register(r'point-transactions', PointTransactionViewSet)
router.register(r'tasks', TaskViewSet)
router.register(r'member-tasks', MemberTaskViewSet)
router.register(r'badges', BadgeViewSet)
router.register(r'member-badges', MemberBadgeViewSet)
router.register(r'workout-menus', WorkoutMenuViewSet)
router.register(r'workout-items', WorkoutItemViewSet)

urlpatterns = [
    path('auth/google/', GoogleLoginView.as_view(), name='auth-google'),
    path('auth/facebook/', FacebookLoginView.as_view(), name='auth-facebook'),
    path('auth/register/', RegisterView.as_view(), name='auth-register'),
    path('auth/login/', LoginView.as_view(), name='auth-login'),
    path('', include(router.urls)),
]
