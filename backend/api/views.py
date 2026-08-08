from rest_framework import viewsets, status
from rest_framework.permissions import IsAuthenticated,AllowAny
from rest_framework.decorators import action
from rest_framework.response import Response

from django.db import transaction
from django.db.models import Avg, Sum, Q
from api.leaderboard_service import get_leaderboard

from core.models import (
    Member, BodyRecord, BloodPressureRecord, BoardRanking, CommunityPost, Favorite, TrainingLog,
    PostLike, PostComment, PostReport, PoseAnalysis, PointTransaction,
    Task, MemberTask, Badge, MemberBadge, WorkoutMenu, WorkoutItem, PostTag,
    PostWorkoutPlan,
    PostWorkoutPlanStep
)
from .serializers import (
    MemberSerializer, BodyRecordSerializer, BloodPressureRecordSerializer, BoardRankingSerializer,
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

class BloodPressureRecordViewSet(viewsets.ModelViewSet):
    queryset = BloodPressureRecord.objects.all()
    serializer_class = BloodPressureRecordSerializer
    permission_classes = [AllowAny]


class BoardRankingViewSet(viewsets.ModelViewSet):
    queryset = BoardRanking.objects.all()
    serializer_class = BoardRankingSerializer
    permission_classes = [AllowAny]
   # permission_classes = [IsAuthenticated]

class CommunityPostViewSet(viewsets.ModelViewSet):
    serializer_class = CommunityPostSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = (
            CommunityPost.objects
            .select_related("member")
            .prefetch_related(
                "tags",
                "likes",
                "comments",
                "favorited_by",
                "workout_plan__steps",
            )
            .order_by("-created_at")
        )

        # 搜尋
        search = self.request.query_params.get("search")

        if search:
            queryset = queryset.filter(
                Q(content__icontains=search)
                | Q(member__username__icontains=search)
                | Q(member__first_name__icontains=search)
                | Q(member__last_name__icontains=search)
                | Q(tags__name__icontains=search)
            ).distinct()

        # 查特定會員的貼文
        member_id = self.request.query_params.get("member_id")

        if member_id:
            queryset = queryset.filter(member_id=member_id)

        # 貼文類型
        post_type = self.request.query_params.get("post_type")

        if post_type in ["journey", "plan", "recipe"]:
            queryset = queryset.filter(post_type=post_type)

        return queryset


    @transaction.atomic
    def create(self, request, *args, **kwargs):
        post_type = request.data.get("post_type", "journey")
        content = request.data.get("content", "").strip()
        image = request.data.get("image")

        tags = request.data.get("tags", [])

        workout_plan = request.data.get("workout_plan")

        if post_type not in ["journey", "plan", "recipe"]:
            return Response(
                {
                    "error": "不支援的貼文類型"
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not content:
            return Response(
                {
                    "error": "貼文內容不可為空"
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not isinstance(tags, list):
            return Response(
                {
                    "error": "tags 必須是陣列"
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if post_type == "plan" and not workout_plan:
            return Response(
                {
                    "error": "計畫貼文必須提供 workout_plan"
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        post = CommunityPost.objects.create(
            member=request.user,
            post_type=post_type,
            content=content,
            image=image,
        )

        # 建立標籤
        self._save_tags(
            post=post,
            tags=tags,
        )

        # 建立訓練計畫
        if post_type == "plan":
            try:
                self._save_workout_plan(
                    post=post,
                    workout_plan=workout_plan,
                )
            except ValueError as error:
                transaction.set_rollback(True)

                return Response(
                    {
                        "error": str(error)
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )


        serializer = self.get_serializer(post)

        return Response(
            serializer.data,
            status=status.HTTP_201_CREATED,
        )


    @transaction.atomic
    def update(self, request, *args, **kwargs):
        partial = kwargs.pop("partial", False)

        post = self.get_object()

        # 只能修改自己的貼文
        if post.member_id != request.user.id:
            return Response(
                {
                    "error": "你只能修改自己的貼文"
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        post_type = request.data.get(
            "post_type",
            post.post_type,
        )

        content = request.data.get(
            "content",
            post.content,
        )

        image = request.data.get(
            "image",
            post.image,
        )

        tags = request.data.get("tags")

        workout_plan = request.data.get("workout_plan")

        if post_type not in ["journey", "plan", "recipe"]:
            return Response(
                {
                    "error": "不支援的貼文類型"
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not str(content).strip():
            return Response(
                {
                    "error": "貼文內容不可為空"
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        post.post_type = post_type
        post.content = str(content).strip()
        post.image = image

        post.save()

        # 如果有傳 tags 才更新
        if tags is not None:

            if not isinstance(tags, list):
                return Response(
                    {
                        "error": "tags 必須是陣列"
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            post.tags.all().delete()

            self._save_tags(
                post=post,
                tags=tags,
            )

        # 計畫貼文
        if post_type == "plan":

            if workout_plan is not None:

                if hasattr(post, "workout_plan"):
                    post.workout_plan.delete()

                try:
                    self._save_workout_plan(
                        post=post,
                        workout_plan=workout_plan,
                    )
                except ValueError as error:
                    transaction.set_rollback(True)

                    return Response(
                        {
                            "error": str(error)
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

        else:
            # 從 plan 改回 journey 時，
            # 把舊計畫資料刪掉
            if hasattr(post, "workout_plan"):
                post.workout_plan.delete()

        serializer = self.get_serializer(post)

        return Response(serializer.data)


    def destroy(self, request, *args, **kwargs):
        post = self.get_object()

        if post.member_id != request.user.id:
            return Response(
                {
                    "error": "你只能刪除自己的貼文"
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        post.delete()

        return Response(
            {
                "message": "貼文刪除成功"
            },
            status=status.HTTP_200_OK,
        )


    # =========================
    # 按讚 / 取消讚
    # =========================

    @action(
        detail=True,
        methods=["post"],
        url_path="toggle-like",
    )
    def toggle_like(self, request, pk=None):
        post = self.get_object()

        like = PostLike.objects.filter(
            member=request.user,
            post=post,
        ).first()

        if like:
            like.delete()
            is_liked = False

        else:
            PostLike.objects.create(
                member=request.user,
                post=post,
            )

            is_liked = True

        return Response({
            "message": (
                "已按讚"
                if is_liked
                else "已取消按讚"
            ),
            "is_liked": is_liked,
            "like_count": PostLike.objects.filter(post=post).count(),
        })


    # =========================
    # 收藏 / 取消收藏
    # =========================

    @action(
        detail=True,
        methods=["post"],
        url_path="toggle-favorite",
    )
    def toggle_favorite(self, request, pk=None):
        post = self.get_object()

        favorite = Favorite.objects.filter(
            member=request.user,
            post=post,
        ).first()

        if favorite:
            favorite.delete()
            is_saved = False

        else:
            Favorite.objects.create(
                member=request.user,
                post=post,
            )

            is_saved = True

        return Response({
            "message": (
                "已收藏"
                if is_saved
                else "已取消收藏"
            ),
            "is_saved": is_saved,
        })


    # =========================
    # 留言
    # =========================

    @action(
        detail=True,
        methods=["get", "post"],
        url_path="comments",
    )
    def comments(self, request, pk=None):
        post = self.get_object()

        if request.method == "GET":

            comments = (
                post.comments
                .select_related("member")
                .order_by("created_at")
            )

            data = []

            for comment in comments:

                name = (
                    comment.member.get_full_name().strip()
                    or comment.member.username
                )

                data.append({
                    "id": comment.id,
                    "member_id": comment.member_id,
                    "member_name": name,
                    "member_initial": (
                        name[0].upper()
                        if name
                        else "U"
                    ),
                    "content": comment.content,
                    "created_at": comment.created_at,
                })

            return Response(data)

        content = request.data.get(
            "content",
            "",
        ).strip()

        if not content:
            return Response(
                {
                    "error": "留言不可為空"
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        comment = PostComment.objects.create(
            member=request.user,
            post=post,
            content=content,
        )

        name = (
            request.user.get_full_name().strip()
            or request.user.username
        )

        return Response(
            {
                "id": comment.id,
                "member_id": request.user.id,
                "member_name": name,
                "member_initial": (
                    name[0].upper()
                    if name
                    else "U"
                ),
                "content": comment.content,
                "created_at": comment.created_at,
            },
            status=status.HTTP_201_CREATED,
        )


    # =========================
    # 檢舉
    # =========================

    @action(
        detail=True,
        methods=["post"],
        url_path="report",
    )
    def report(self, request, pk=None):
        post = self.get_object()

        reason = request.data.get(
            "reason",
            "",
        ).strip()

        if not reason:
            return Response(
                {
                    "error": "請提供檢舉原因"
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        report = PostReport.objects.create(
            member=request.user,
            post=post,
            reason=reason,
            status="pending",
        )

        return Response(
            {
                "message": "檢舉已送出",
                "report_id": report.id,
                "status": report.status,
            },
            status=status.HTTP_201_CREATED,
        )


    # =========================
    # 我的貼文
    # =========================

    @action(
        detail=False,
        methods=["get"],
        url_path="my-posts",
    )
    def my_posts(self, request):
        posts = self.get_queryset().filter(
            member=request.user
        )

        serializer = self.get_serializer(
            posts,
            many=True,
        )

        return Response(serializer.data)


    # =========================
    # 我的收藏
    # =========================

    @action(
        detail=False,
        methods=["get"],
        url_path="saved",
    )
    def saved(self, request):
        posts = (
            self.get_queryset()
            .filter(
                favorited_by__member=request.user
            )
            .distinct()
        )

        serializer = self.get_serializer(
            posts,
            many=True,
        )

        return Response(serializer.data)


    # =========================
    # 共用：儲存標籤
    # =========================

    def _save_tags(self, post, tags):
        for tag in tags:

            tag_name = str(tag).strip()

            if not tag_name:
                continue

            # Flutter 現在使用 #晨跑
            # 所以統一補上 #
            if not tag_name.startswith("#"):
                tag_name = f"#{tag_name}"

            PostTag.objects.create(
                post=post,
                name=tag_name,
            )


    # =========================
    # 共用：儲存訓練計畫
    # =========================

    def _save_workout_plan(
        self,
        post,
        workout_plan,
    ):
        if not isinstance(workout_plan, dict):
            raise ValueError(
                "workout_plan 格式錯誤"
            )

        title = str(
            workout_plan.get(
                "title",
                "",
            )
        ).strip()

        summary = str(
            workout_plan.get(
                "summary",
                "",
            )
        ).strip()

        difficulty = str(
            workout_plan.get(
                "difficulty",
                "中等",
            )
        ).strip()

        steps = workout_plan.get(
            "steps",
            [],
        )

        if not title:
            raise ValueError(
                "計畫標題不可為空"
            )

        if not isinstance(steps, list):
            raise ValueError(
                "steps 必須是陣列"
            )

        valid_steps = []

        total_minutes = 0

        for index, step in enumerate(steps):

            if not isinstance(step, dict):
                continue

            name = str(
                step.get(
                    "name",
                    "",
                )
            ).strip()

            try:
                minutes = int(
                    step.get(
                        "minutes",
                        0,
                    )
                )

            except (TypeError, ValueError):
                minutes = 0

            if not name or minutes <= 0:
                continue

            valid_steps.append({
                "name": name,
                "minutes": minutes,
                "order": index,
            })

            total_minutes += minutes

        if not valid_steps:
            raise ValueError(
                "計畫至少需要一個有效步驟"
            )

        plan = PostWorkoutPlan.objects.create(
            post=post,
            title=title,
            summary=summary,
            difficulty=difficulty,
            total_minutes=total_minutes,
        )

        PostWorkoutPlanStep.objects.bulk_create([
            PostWorkoutPlanStep(
                plan=plan,
                name=step["name"],
                minutes=step["minutes"],
                order=step["order"],
            )
            for step in valid_steps
        ])

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
        )

        # 如果沒有紀錄，Sum 會回傳 None，所以要用 'or 0' 給預設值
        return Response({
            "member_id": member_id,
            "workout_count": user_logs.count(), # 總運動次數
            "total_time": stats['total_time'] or 0,
            "total_calories": stats['total_calories'] or 0,
            "total_steps": stats['total_steps'] or 0,
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
