from rest_framework import viewsets, status
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated,AllowAny
from rest_framework.decorators import action
from rest_framework.response import Response

import os
from django.http import HttpResponse, HttpResponseForbidden
from django.views.decorators.csrf import csrf_exempt
from linebot import LineBotApi, WebhookParser
from linebot.exceptions import InvalidSignatureError
from linebot.models import MessageEvent, TextMessage, TextSendMessage
from openai import OpenAI

line_bot_api = LineBotApi(os.getenv('LINE_CHANNEL_ACCESS_TOKEN', 'YOUR_LINE_TOKEN'))
parser = WebhookParser(os.getenv('LINE_CHANNEL_SECRET', 'YOUR_LINE_SECRET'))
openai_client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

from django.utils import timezone
from django.db import transaction
from django.db.models import Count, Sum, Q
from api.leaderboard_service import get_leaderboard
from datetime import timedelta

from core.models import (
    Member, BodyRecord, BloodPressureRecord, BoardRanking, CommunityPost, Favorite, TrainingLog,
    PostLike, PostComment, PostReport, PoseAnalysis, PointTransaction,
    Task, MemberTask, Badge, MemberBadge, WorkoutMenu, WorkoutItem, PostTag,
    PostWorkoutPlan,
    WorkoutMenuStep,
    PostWorkoutPlanStep,FriendRequest,
    Friendship, ChatMessage, RunInvitation,
    CommunityGroup, CommunityGroupMember, CommunityGroupInvitation,
    CommunityGroupActivity,
    CommunityGroupActivityParticipant,
    CommunityGroupJoinRequest,
    FeatureUnlock,
    WorkoutMenuSession,
)
from .serializers import (
    MemberSerializer, AdminMemberListSerializer,AdminPostReportSerializer, BodyRecordSerializer, BloodPressureRecordSerializer, BoardRankingSerializer,
    CommunityPostSerializer, FavoriteSerializer, TrainingLogSerializer,
    PostLikeSerializer, PostCommentSerializer, PostReportSerializer, PoseAnalysisSerializer, PointTransactionSerializer,
    TaskSerializer, MemberTaskSerializer, BadgeSerializer, MemberBadgeSerializer, WorkoutMenuSerializer, WorkoutMenuSessionSerializer, WorkoutItemSerializer,FriendMemberSerializer,
    FriendRequestSerializer,
    FriendSearchSerializer,
    ChatMessageSerializer,
    RunInvitationSerializer,
    CommunityGroupSerializer,
    CommunityGroupInvitationSerializer,
    CommunityGroupActivitySerializer,
    CommunityGroupJoinRequestSerializer,
)
from .ecpay_service import ECPayService


#  =========================
# 排行榜邏輯
#  =========================

ALLOWED_EXERCISE_TYPES = ["slow_jogging", "squat"]
ALLOWED_PERIODS = ["week", "month", "all"]

class MemberViewSet(viewsets.ModelViewSet):
    queryset = Member.objects.all()
    serializer_class = MemberSerializer
    permission_classes = [AllowAny]


    @action(detail=True, methods=["get"], url_path="daily-tasks")
    def daily_tasks(self, request, pk=None):
        member = self.get_object()

        goal = member.exercise_goal
        frequency = member.exercise_frequency

        # 根據「運動目標」＋「每週運動頻率」決定今日任務
        task_rules = {
            "weight_loss": {
                "1_2": {
                    "title": "今日燃脂訓練",
                    "tasks": [
                        {
                            "type": "slow_jogging",
                            "title": "超慢跑",
                            "target": 20,
                            "unit": "分鐘",
                        },
                        {
                            "type": "steps",
                            "title": "今日步數",
                            "target": 7000,
                            "unit": "步",
                        },
                    ],
                },
                "3_4": {
                    "title": "今日燃脂訓練",
                    "tasks": [
                        {
                            "type": "slow_jogging",
                            "title": "超慢跑",
                            "target": 30,
                            "unit": "分鐘",
                        },
                        {
                            "type": "steps",
                            "title": "今日步數",
                            "target": 8000,
                            "unit": "步",
                        },
                    ],
                },
                "5_plus": {
                    "title": "今日燃脂訓練",
                    "tasks": [
                        {
                            "type": "slow_jogging",
                            "title": "超慢跑",
                            "target": 40,
                            "unit": "分鐘",
                        },
                        {
                            "type": "steps",
                            "title": "今日步數",
                            "target": 10000,
                            "unit": "步",
                        },
                    ],
                },
            },

            "muscle_gain": {
                "1_2": {
                    "title": "今日肌力訓練",
                    "tasks": [
                        {
                            "type": "squat",
                            "title": "深蹲",
                            "target": 2,
                            "unit": "組",
                        },
                        {
                            "type": "training",
                            "title": "完成運動",
                            "target": 20,
                            "unit": "分鐘",
                        },
                    ],
                },
                "3_4": {
                    "title": "今日肌力訓練",
                    "tasks": [
                        {
                            "type": "squat",
                            "title": "深蹲",
                            "target": 3,
                            "unit": "組",
                        },
                        {
                            "type": "training",
                            "title": "完成運動",
                            "target": 30,
                            "unit": "分鐘",
                        },
                    ],
                },
                "5_plus": {
                    "title": "今日肌力訓練",
                    "tasks": [
                        {
                            "type": "squat",
                            "title": "深蹲",
                            "target": 4,
                            "unit": "組",
                        },
                        {
                            "type": "training",
                            "title": "完成運動",
                            "target": 40,
                            "unit": "分鐘",
                        },
                    ],
                },
            },

            "health": {
                "1_2": {
                    "title": "今日健康任務",
                    "tasks": [
                        {
                            "type": "training",
                            "title": "完成運動",
                            "target": 20,
                            "unit": "分鐘",
                        },
                        {
                            "type": "steps",
                            "title": "今日步數",
                            "target": 7000,
                            "unit": "步",
                        },
                    ],
                },
                "3_4": {
                    "title": "今日健康任務",
                    "tasks": [
                        {
                            "type": "training",
                            "title": "完成運動",
                            "target": 30,
                            "unit": "分鐘",
                        },
                        {
                            "type": "steps",
                            "title": "今日步數",
                            "target": 8000,
                            "unit": "步",
                        },
                    ],
                },
                "5_plus": {
                    "title": "今日健康任務",
                    "tasks": [
                        {
                            "type": "training",
                            "title": "完成運動",
                            "target": 40,
                            "unit": "分鐘",
                        },
                        {
                            "type": "steps",
                            "title": "今日步數",
                            "target": 10000,
                            "unit": "步",
                        },
                    ],
                },
            },
        }

        selected = task_rules.get(goal, task_rules["health"])
        plan = selected.get(
            frequency,
            selected["1_2"],
        )

        return Response({
            "member_id": member.id,
            "goal": goal,
            "frequency": frequency,
            "plan_title": plan["title"],
            "tasks": plan["tasks"],
        })
    
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

    @action(detail=False, methods=["get"], url_path="admin-users")
    def admin_users(self, request):
        # 撈出所有使用者，依照加入時間排序
        members = Member.objects.all().order_by("-date_joined")
        
        # 使用我們剛才寫好的專用 Serializer
        serializer = AdminMemberListSerializer(members, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    # 切換用戶啟用 / 停權狀態
    @action(detail=True, methods=["post"], url_path="toggle-status")
    def toggle_status(self, request, pk=None):
        member = self.get_object()
        # 反轉狀態：True 變 False，False 變 True
        member.is_active = not member.is_active
        member.save(update_fields=["is_active"])
        
        return Response({
            "message": f"用戶狀態已更新為 {'啟用' if member.is_active else '停用'}",
            "id": member.id,
            "isActive": member.is_active,
        }, status=status.HTTP_200_OK)

    # 數據分析 API 端點
    @action(detail=False, methods=["get"], url_path="admin-analytics")
    def admin_analytics(self, request):
        timeframe = request.query_params.get("timeframe", "all")
        data = compute_admin_analytics(timeframe=timeframe)
        return Response(data, status=status.HTTP_200_OK)
    

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

        post_type = request.query_params.get("post_type")

        if post_type in ["journey", "plan", "recipe"]:
            posts = posts.filter(
                post_type=post_type
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

            exercise_type = str(
                step.get(
                    "exercise_type",
                    "",
                )
            ).strip()

            if exercise_type not in [
                "slow_jogging",
                "squat",
            ]:
                continue

            name = (
                "超慢跑"
                if exercise_type == "slow_jogging"
                else "深蹲"
            )

            minutes = None
            reps = None

            if exercise_type == "slow_jogging":
                try:
                    minutes = int(
                        step.get(
                            "minutes",
                            0,
                        )
                    )
                except (TypeError, ValueError):
                    minutes = 0

                if minutes <= 0:
                    continue

                total_minutes += minutes

            elif exercise_type == "squat":
                try:
                    reps = int(
                        step.get(
                            "reps",
                            0,
                        )
                    )
                except (TypeError, ValueError):
                    reps = 0

                if reps <= 0:
                    continue

            valid_steps.append({
                "name": name,
                "exercise_type": exercise_type,
                "minutes": minutes,
                "reps": reps,
                "order": index,
            })

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
                exercise_type=step["exercise_type"],
                minutes=step["minutes"],
                reps=step["reps"],
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
    permission_classes = [IsAuthenticated]
    # 個人運動數據加總 API
    @action(detail=False, methods=['get'], url_path='my-stats')
    def my_stats(self, request):
        user_logs = TrainingLog.objects.filter(
            member=request.user
        )
        
        stats = user_logs.aggregate(
            total_time=Sum('total_mins'),
            total_calories=Sum('calories'),
            total_steps=Sum('step_count'),
        )

        return Response({
            "member_id": request.user.id,
            "workout_count": user_logs.count(),
            "total_time": stats['total_time'] or 0,
            "total_calories": stats['total_calories'] or 0,
            "total_steps": stats['total_steps'] or 0,
        })

    @transaction.atomic
    def perform_create(self, serializer):
        training_log = serializer.save(
            member=self.request.user
        )

        member = (
            Member.objects
            .select_for_update()
            .get(id=training_log.member_id)
        )

        # =========================
        # 1. 完成一次運動 +5 SP
        # =========================

        workout_reference_key = (
            f"workout:{training_log.id}"
        )

        workout_reward_exists = (
            PointTransaction.objects.filter(
                member=member,
                reference_key=workout_reference_key,
                tran_type="reward",
                status="completed",
            ).exists()
        )

        if not workout_reward_exists:
            workout_reward = 5

            member.points += workout_reward
            member.save(
                update_fields=["points"]
            )

            PointTransaction.objects.create(
                member=member,
                points_changed=workout_reward,
                tran_type="reward",
                description="完成運動獎勵",
                reference_key=workout_reference_key,
                status="completed",
            )

        # =========================
        # 2. 計算目前連續運動天數
        # =========================

        today = timezone.localdate(
            training_log.start_time
        )

        log_dates = {
            timezone.localdate(start_time)
            for start_time in (
                TrainingLog.objects
                .filter(member=member)
                .values_list(
                    "start_time",
                    flat=True,
                )
            )
        }

        streak_days = 0
        current_date = today

        while current_date in log_dates:
            streak_days += 1
            current_date -= timedelta(days=1)

        # current_date 已經是沒有運動的前一天
        streak_start_date = (
            today - timedelta(
                days=streak_days - 1
            )
        )

        # =========================
        # 3. 連續 7 天 +30 SP
        # =========================

        if streak_days >= 7:
            streak_reference_key = (
                "streak:7:"
                f"{streak_start_date.isoformat()}"
            )

            streak_reward_exists = (
                PointTransaction.objects.filter(
                    member=member,
                    reference_key=streak_reference_key,
                    tran_type="reward",
                    status="completed",
                ).exists()
            )

            if not streak_reward_exists:
                streak_reward = 30

                member.points += streak_reward
                member.save(
                    update_fields=["points"]
                )

                PointTransaction.objects.create(
                    member=member,
                    points_changed=streak_reward,
                    tran_type="reward",
                    description="連續運動 7 天獎勵",
                    reference_key=streak_reference_key,
                    status="completed",
                )

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

    # 後台取得所有被檢舉貼文清單
    @action(detail=False, methods=["get"], url_path="admin-reports")
    def admin_reports(self, request):
        reports = (
            PostReport.objects
            .select_related("member", "post", "post__member")
            .order_by("-created_at")
        )
        serializer = AdminPostReportSerializer(reports, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    # 後台處理檢舉：下架貼文或駁回檢舉
    @action(detail=True, methods=["post"], url_path="resolve")
    @transaction.atomic
    def resolve_report(self, request, pk=None):
        report = self.get_object()
        action_type = request.data.get("action", "dismiss")

        if action_type == "take_down":
            report.status = "removed"
            # 標記貼文為不公開/下架，而不是物理刪除
            if report.post:
                # 如果你的 CommunityPost 有 is_active 欄位：
                if hasattr(report.post, "is_active"):
                    report.post.is_active = False
                    report.post.save(update_fields=["is_active"])
                # 如果沒有 is_active，先用文字標記避免級聯刪除
                elif hasattr(report.post, "content"):
                    report.post.content = "[該貼文因違反社群規範已被下架]"
                    report.post.save(update_fields=["content"])
        else:
            report.status = "reviewed"

        report.save(update_fields=["status"])

        return Response({
            "message": "處理完成",
            "report_id": report.id,
            "status": report.status,
        }, status=status.HTTP_200_OK)

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
    queryset = MemberBadge.objects.select_related('badge').all()
    serializer_class = MemberBadgeSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        queryset = super().get_queryset()
        member_id = self.request.query_params.get('member_id')
        if member_id:
            queryset = queryset.filter(member_id=member_id)
        return queryset

class WorkoutMenuViewSet(viewsets.ModelViewSet):
    serializer_class = WorkoutMenuSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return (
            WorkoutMenu.objects
            .filter(
                Q(is_public=True) |
                Q(member=self.request.user)
            )
            .order_by('-created_at')
        )

    def perform_create(self, serializer):
        serializer.save(
            member=self.request.user
        )

    @action(
        detail=False,
        methods=['post'],
        url_path='apply',
    )
    def apply(self, request):
        plan_id = request.data.get('post_workout_plan_id')

        if not plan_id:
            return Response(
                {
                    'error': '缺少 post_workout_plan_id',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            plan = (
                PostWorkoutPlan.objects
                .prefetch_related('steps')
                .get(id=plan_id)
            )
        except PostWorkoutPlan.DoesNotExist:
            return Response(
                {
                    'error': '找不到運動計畫',
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        existing_menu = WorkoutMenu.objects.filter(
            member=request.user,
            source_plan=plan,
        ).first()

        if existing_menu:
            return Response(
                {
                    'message': '此運動菜單已套用',
                    'already_applied': True,
                    'menu': self.get_serializer(
                        existing_menu
                    ).data,
                },
                status=status.HTTP_200_OK,
            )

        with transaction.atomic():
            menu = WorkoutMenu.objects.create(
                member=request.user,
                source_plan=plan,
                title=plan.title,
                description=plan.summary,
                difficulty=plan.difficulty,
                total_minutes=plan.total_minutes,
                is_public=False,
            )

            WorkoutMenuStep.objects.bulk_create([
                WorkoutMenuStep(
                    menu=menu,
                    name=step.name,
                    exercise_type=step.exercise_type,
                    minutes=step.minutes,
                    reps=step.reps,
                    order=step.order,
                )
                for step in plan.steps.all()
            ])

            WorkoutItem.objects.create(
                member=request.user,
                menu=menu,
            )

        return Response(
            {
                'message': '運動菜單套用成功',
                'already_applied': False,
                'menu': self.get_serializer(
                    menu
                ).data,
            },
            status=status.HTTP_201_CREATED,
        )

class WorkoutItemViewSet(viewsets.ModelViewSet):
    serializer_class = WorkoutItemSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return (
            WorkoutItem.objects
            .filter(member=self.request.user)
            .select_related('menu')
            .order_by('-save_at')
        )

    def create(self, request, *args, **kwargs):
        menu_id = request.data.get('menu')

        if not menu_id:
            return Response(
                {
                    'error': '缺少 menu',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        exists = WorkoutItem.objects.filter(
            member=request.user,
            menu_id=menu_id,
        ).exists()

        if exists:
            return Response(
                {
                    'message': '此運動菜單已套用',
                    'already_applied': True,
                },
                status=status.HTTP_200_OK,
            )

        return super().create(
            request,
            *args,
            **kwargs,
        )

    def perform_create(self, serializer):
        serializer.save(
            member=self.request.user
        )

class WorkoutMenuSessionViewSet(viewsets.ModelViewSet):
    serializer_class = WorkoutMenuSessionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return (
            WorkoutMenuSession.objects
            .filter(member=self.request.user)
            .select_related("menu")
            .order_by("-started_at")
        )

    def perform_create(self, serializer):
        menu = serializer.validated_data["menu"]

        serializer.save(
            member=self.request.user,
            menu_title=menu.title,
            status=WorkoutMenuSession.STATUS_IN_PROGRESS,
        )

    @action(
        detail=True,
        methods=["post"],
        url_path="complete",
    )
    def complete(self, request, pk=None):
        session = self.get_object()

        if session.status == WorkoutMenuSession.STATUS_COMPLETED:
            return Response(
                {
                    "message": "此菜單訓練已完成",
                    "session": self.get_serializer(session).data,
                },
                status=status.HTTP_200_OK,
            )

        session.status = WorkoutMenuSession.STATUS_COMPLETED
        session.completed_at = timezone.now()

        session.save(
            update_fields=[
                "status",
                "completed_at",
            ]
        )

        return Response(
            {
                "message": "菜單訓練完成",
                "session": self.get_serializer(session).data,
            },
            status=status.HTTP_200_OK,
        )

    @action(
        detail=True,
        methods=["post"],
        url_path="abandon",
    )
    def abandon(self, request, pk=None):
        session = self.get_object()

        if session.status == WorkoutMenuSession.STATUS_COMPLETED:
            return Response(
                {
                    "error": "已完成的菜單訓練不能中止",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        session.status = WorkoutMenuSession.STATUS_ABANDONED

        session.save(
            update_fields=[
                "status",
            ]
        )

        return Response(
            {
                "message": "已中止菜單訓練",
                "session": self.get_serializer(session).data,
            },
            status=status.HTTP_200_OK,
        )
    
    def destroy(self, request, *args, **kwargs):
        item = self.get_object()
        menu = item.menu

        item.delete()

        if menu.member_id == request.user.id:
            menu.delete()

        return Response(
            status=status.HTTP_204_NO_CONTENT,
        )

class FriendViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    def _friend_ids(self, user):
        friendships = Friendship.objects.filter(
            Q(member1=user) | Q(member2=user)
        )

        friend_ids = []

        for friendship in friendships:
            if friendship.member1_id == user.id:
                friend_ids.append(friendship.member2_id)
            else:
                friend_ids.append(friendship.member1_id)

        return friend_ids

    # =========================
    # 好友列表
    # =========================

    def list(self, request):
        friend_ids = self._friend_ids(request.user)

        friends = Member.objects.filter(
            id__in=friend_ids
        ).order_by("first_name", "username")

        serializer = FriendMemberSerializer(
            friends,
            many=True,
        )

        return Response(serializer.data)

    # =========================
    # 收到的好友邀請
    # =========================

    @action(
        detail=False,
        methods=["get"],
        url_path="requests",
    )
    def requests(self, request):
        requests = (
            FriendRequest.objects
            .filter(
                receiver=request.user,
                status=FriendRequest.STATUS_PENDING,
            )
            .select_related("sender", "receiver")
            .order_by("-created_at")
        )

        serializer = FriendRequestSerializer(
            requests,
            many=True,
        )

        return Response(serializer.data)

    # =========================
    # 已送出的邀請
    # =========================

    @action(
        detail=False,
        methods=["get"],
        url_path="pending",
    )
    def pending(self, request):
        requests = (
            FriendRequest.objects
            .filter(
                sender=request.user,
                status=FriendRequest.STATUS_PENDING,
            )
            .select_related("sender", "receiver")
            .order_by("-created_at")
        )

        serializer = FriendRequestSerializer(
            requests,
            many=True,
        )

        return Response(serializer.data)

    # =========================
    # 好友推薦
    # =========================

    @action(
        detail=False,
        methods=["get"],
        url_path="suggestions",
    )
    def suggestions(self, request):
        friend_ids = self._friend_ids(request.user)

        pending_user_ids = set(
            FriendRequest.objects.filter(
                Q(
                    sender=request.user,
                    status=FriendRequest.STATUS_PENDING,
                )
                | Q(
                    receiver=request.user,
                    status=FriendRequest.STATUS_PENDING,
                )
            ).values_list(
                "sender_id",
                "receiver_id",
            )
        )

        excluded_ids = {
            request.user.id,
            *friend_ids,
        }

        for sender_id, receiver_id in pending_user_ids:
            excluded_ids.add(sender_id)
            excluded_ids.add(receiver_id)

        users = (
            Member.objects
            .exclude(id__in=excluded_ids)
            .order_by("-date_joined")[:20]
        )

        serializer = FriendMemberSerializer(
            users,
            many=True,
        )

        return Response(serializer.data)

    # =========================
    # 搜尋使用者
    # =========================

    @action(
        detail=False,
        methods=["get"],
        url_path="search",
    )
    def search(self, request):
        keyword = request.query_params.get(
            "keyword",
            "",
        ).strip()

        if not keyword:
            return Response([])

        users = (
            Member.objects
            .exclude(id=request.user.id)
            .filter(
                Q(username__icontains=keyword)
                | Q(first_name__icontains=keyword)
                | Q(last_name__icontains=keyword)
                | Q(email__icontains=keyword)
            )
            .order_by("first_name", "username")[:20]
        )

        serializer = FriendSearchSerializer(
            users,
            many=True,
            context={
                "request": request,
            },
        )

        return Response(serializer.data)

    # =========================
    # 送出好友邀請
    # =========================

    @action(
        detail=False,
        methods=["post"],
        url_path="request",
    )
    def send_request(self, request):
        receiver_id = request.data.get("member_id")

        try:
            receiver = Member.objects.get(id=receiver_id)
        except Member.DoesNotExist:
            return Response(
                {"error": "找不到使用者"},
                status=status.HTTP_404_NOT_FOUND,
            )

        if receiver.id == request.user.id:
            return Response(
                {"error": "不能加自己為好友"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        exists = Friendship.objects.filter(
            Q(member1=request.user, member2=receiver)
            | Q(member1=receiver, member2=request.user)
        ).exists()

        if exists:
            return Response(
                {"error": "你們已經是好友"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        reverse_request = FriendRequest.objects.filter(
            sender=receiver,
            receiver=request.user,
            status=FriendRequest.STATUS_PENDING,
        ).first()

        if reverse_request:
            return Response(
                {
                    "error": "對方已經送出好友邀請給你，請直接接受邀請"
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        friend_request, created = FriendRequest.objects.get_or_create(
            sender=request.user,
            receiver=receiver,
            status=FriendRequest.STATUS_PENDING,
        )

        if not created:
            return Response(
                {"error": "好友邀請已送出"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = FriendRequestSerializer(friend_request)

        return Response(
            serializer.data,
            status=status.HTTP_201_CREATED,
        )

    # =========================
    # 接受好友邀請
    # =========================

    @action(
        detail=True,
        methods=["post"],
        url_path="accept",
    )
    @transaction.atomic
    def accept(self, request, pk=None):
        friend_request = FriendRequest.objects.filter(
            id=pk,
            receiver=request.user,
            status=FriendRequest.STATUS_PENDING,
        ).first()

        if friend_request is None:
            return Response(
                {"error": "找不到好友邀請"},
                status=status.HTTP_404_NOT_FOUND,
            )

        member1, member2 = sorted(
            [friend_request.sender, friend_request.receiver],
            key=lambda member: member.id,
        )

        Friendship.objects.get_or_create(
            member1=member1,
            member2=member2,
        )

        friend_request.status = FriendRequest.STATUS_ACCEPTED
        friend_request.save(
            update_fields=[
                "status",
                "updated_at",
            ]
        )

        return Response({
            "message": "已接受好友邀請"
        })

    # =========================
    # 拒絕好友邀請
    # =========================

    @action(
        detail=True,
        methods=["post"],
        url_path="reject",
    )
    def reject(self, request, pk=None):
        friend_request = FriendRequest.objects.filter(
            id=pk,
            receiver=request.user,
            status=FriendRequest.STATUS_PENDING,
        ).first()

        if friend_request is None:
            return Response(
                {"error": "找不到好友邀請"},
                status=status.HTTP_404_NOT_FOUND,
            )

        friend_request.status = FriendRequest.STATUS_REJECTED
        friend_request.save(
            update_fields=[
                "status",
                "updated_at",
            ]
        )

        return Response({
            "message": "已拒絕好友邀請"
        })

    # =========================
    # 取消已送出的好友邀請
    # =========================

    @action(
        detail=True,
        methods=["delete"],
        url_path="cancel",
    )
    def cancel(self, request, pk=None):
        friend_request = FriendRequest.objects.filter(
            id=pk,
            sender=request.user,
            status=FriendRequest.STATUS_PENDING,
        ).first()

        if friend_request is None:
            return Response(
                {"error": "找不到好友邀請"},
                status=status.HTTP_404_NOT_FOUND,
            )

        friend_request.delete()

        return Response(
            status=status.HTTP_204_NO_CONTENT
        )

    # =========================
    # 刪除好友
    # =========================

    @action(
        detail=True,
        methods=["delete"],
        url_path="remove",
    )
    def remove_friend(self, request, pk=None):
        friendship = Friendship.objects.filter(
            Q(member1=request.user, member2_id=pk)
            | Q(member1_id=pk, member2=request.user)
        ).first()

        if friendship is None:
            return Response(
                {"error": "你們不是好友"},
                status=status.HTTP_404_NOT_FOUND,
            )

        friendship.delete()

        return Response(
            status=status.HTTP_204_NO_CONTENT
        )

class ChatViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    def _is_friend(self, user, friend):
        return Friendship.objects.filter(
            Q(member1=user, member2=friend)
            | Q(member1=friend, member2=user)
        ).exists()

    @action(
        detail=True,
        methods=["get", "post"],
        url_path="messages",
    )
    def messages(self, request, pk=None):
        try:
            friend = Member.objects.get(pk=pk)
        except Member.DoesNotExist:
            return Response(
                {
                    "error": "找不到使用者",
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        if friend.id == request.user.id:
            return Response(
                {
                    "error": "不能與自己聊天",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not self._is_friend(
            request.user,
            friend,
        ):
            return Response(
                {
                    "error": "只有好友可以傳送訊息",
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        if request.method == "GET":
            messages = (
                ChatMessage.objects
                .filter(
                    Q(
                        sender=request.user,
                        receiver=friend,
                    )
                    | Q(
                        sender=friend,
                        receiver=request.user,
                    )
                )
                .select_related(
                    "sender",
                    "receiver",
                )
                .order_by("created_at")
            )

            unread_messages = ChatMessage.objects.filter(
                sender=friend,
                receiver=request.user,
                is_read=False,
            ).order_by(
                "created_at",
            )

            first_unread_message = unread_messages.first()

            first_unread_message_id = (
                first_unread_message.id
                if first_unread_message is not None
                else None
            )

            serializer = ChatMessageSerializer(
                messages,
                many=True,
                context={
                    "request": request,
                },
            )

            response_data = {
                "first_unread_message_id": first_unread_message_id,
                "messages": serializer.data,
            }

            unread_messages.update(
                is_read=True,
            )

            return Response(response_data)

        content = str(
            request.data.get(
                "content",
                "",
            )
        ).strip()

        if not content:
            return Response(
                {
                    "error": "訊息不可為空",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        message = ChatMessage.objects.create(
            sender=request.user,
            receiver=friend,
            content=content,
        )

        serializer = ChatMessageSerializer(
            message,
            context={
                "request": request,
            },
        )

        return Response(
            serializer.data,
            status=status.HTTP_201_CREATED,
        )

    @action(
        detail=False,
        methods=["get"],
        url_path="unread",
    )
    def unread(self, request):
        unread_messages = (
            ChatMessage.objects
            .filter(
                receiver=request.user,
                is_read=False,
            )
            .values("sender_id")
            .annotate(unread_count=Count("id"))
            .order_by()
        )

        friends = [
            {
                "friend_id": item["sender_id"],
                "unread_count": item["unread_count"],
            }
            for item in unread_messages
        ]

        total = sum(
            item["unread_count"]
            for item in unread_messages
        )

        return Response({
            "total": total,
            "friends": friends,
        })

class RunInvitationViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    def _is_friend(self, user, friend):
        return Friendship.objects.filter(
            Q(member1=user, member2=friend)
            | Q(member1=friend, member2=user)
        ).exists()

    def create(self, request):
        invitee_id = request.data.get(
            "invitee_id",
        )

        if not invitee_id:
            return Response(
                {
                    "error": "缺少 invitee_id",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            invitee = Member.objects.get(
                id=invitee_id,
            )
        except Member.DoesNotExist:
            return Response(
                {
                    "error": "找不到使用者",
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        if invitee.id == request.user.id:
            return Response(
                {
                    "error": "不能邀請自己跑步",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not self._is_friend(
            request.user,
            invitee,
        ):
            return Response(
                {
                    "error": "只能邀請好友一起跑步",
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = RunInvitationSerializer(
            data=request.data,
        )

        serializer.is_valid(
            raise_exception=True,
        )

        invitation = serializer.save(
            inviter=request.user,
            invitee=invitee,
        )

        response_serializer = RunInvitationSerializer(
            invitation,
        )

        return Response(
            response_serializer.data,
            status=status.HTTP_201_CREATED,
        )

    @action(
        detail=False,
        methods=["get"],
        url_path=r"with/(?P<friend_id>[^/.]+)",
    )
    def with_friend(self, request, friend_id=None):
        try:
            friend = Member.objects.get(id=friend_id)
        except Member.DoesNotExist:
            return Response(
                {
                    "error": "找不到使用者",
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        if friend.id == request.user.id:
            return Response(
                {
                    "error": "不能查詢自己",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not self._is_friend(
            request.user,
            friend,
        ):
            return Response(
                {
                    "error": "只能查看好友之間的跑步邀請",
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        invitations = (
            RunInvitation.objects
            .filter(
                Q(
                    inviter=request.user,
                    invitee=friend,
                )
                | Q(
                    inviter=friend,
                    invitee=request.user,
                )
            )
            .select_related(
                "inviter",
                "invitee",
            )
            .order_by("created_at")
        )

        serializer = RunInvitationSerializer(
            invitations,
            many=True,
        )

        return Response(serializer.data)

    @action(
        detail=True,
        methods=["post"],
        url_path="accept",
    )
    def accept(self, request, pk=None):
        invitation = (
            RunInvitation.objects
            .filter(
                id=pk,
                invitee=request.user,
                status=RunInvitation.STATUS_PENDING,
            )
            .first()
        )

        if invitation is None:
            return Response(
                {
                    "error": "找不到待處理的跑步邀請",
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        invitation.status = RunInvitation.STATUS_ACCEPTED
        invitation.responded_at = timezone.now()

        invitation.save(
            update_fields=[
                "status",
                "responded_at",
                "updated_at",
            ]
        )

        serializer = RunInvitationSerializer(
            invitation,
        )

        return Response(serializer.data)

    @action(
        detail=True,
        methods=["post"],
        url_path="reject",
    )
    def reject(self, request, pk=None):
        invitation = (
            RunInvitation.objects
            .filter(
                id=pk,
                invitee=request.user,
                status=RunInvitation.STATUS_PENDING,
            )
            .first()
        )

        if invitation is None:
            return Response(
                {
                "error": "找不到待處理的跑步邀請",
            },
            status=status.HTTP_404_NOT_FOUND,
        )

        invitation.status = RunInvitation.STATUS_REJECTED
        invitation.responded_at = timezone.now()

        invitation.save(
            update_fields=[
                "status",
                "responded_at",
                "updated_at",
            ]
        )

        serializer = RunInvitationSerializer(
            invitation,
        )

        return Response(serializer.data)

    @action(
        detail=True,
        methods=["post"],
        url_path="cancel",
    )
    def cancel(self, request, pk=None):
        invitation = (
            RunInvitation.objects
            .filter(
                id=pk,
                inviter=request.user,
                status=RunInvitation.STATUS_PENDING,
            )
            .first()
        )

        if invitation is None:
            return Response(
                {
                    "error": "找不到可取消的跑步邀請",
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        invitation.status = RunInvitation.STATUS_CANCELLED

        invitation.save(
            update_fields=[
                "status",
                "updated_at",
            ]
        )

        serializer = RunInvitationSerializer(
            invitation,
        )

        return Response(serializer.data)

    @action(
        detail=False,
        methods=["get"],
        url_path="pending",
    )
    def pending(self, request):
        invitations = (
            RunInvitation.objects
            .filter(
                invitee=request.user,
                status=RunInvitation.STATUS_PENDING,
            )
            .values("inviter_id")
            .annotate(
                pending_count=Count("id"),
            )
            .order_by()
        )

        friends = [
            {
                "friend_id": item["inviter_id"],
                "pending_count": item["pending_count"],
            }
            for item in invitations
        ]

        total = sum(
            item["pending_count"]
            for item in friends
        )

        return Response(
            {
                "total": total,
                "friends": friends,
            }
        )

class CommunityGroupViewSet(viewsets.ModelViewSet):
    serializer_class = CommunityGroupSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = (
            CommunityGroup.objects
            .filter(
                group_members__member=self.request.user,
            )
            .select_related(
                "owner",
            )
            .prefetch_related(
                "group_members__member",
            )
            .distinct()
        )

        search = self.request.query_params.get(
            "search",
            "",
        ).strip()

        if search:
            queryset = queryset.filter(
                Q(name__icontains=search)
                | Q(description__icontains=search)
            )

        return queryset.order_by("-created_at")

    @action(
        detail=False,
        methods=["get"],
        url_path="discover",
    )
    def discover(self, request):
        groups = (
            CommunityGroup.objects
            .exclude(
                group_members__member=request.user,
            )
            .select_related(
                "owner",
            )
            .prefetch_related(
                "group_members__member",
            )
            .distinct()
        )

        search = request.query_params.get(
            "search",
            "",
        ).strip()

        if search:
            groups = groups.filter(
                Q(name__icontains=search)
                | Q(description__icontains=search)
            )

        groups = groups.order_by("-created_at")

        serializer = CommunityGroupSerializer(
            groups,
            many=True,
            context={
                "request": request,
            },
        )

        return Response(
            serializer.data,
        )

    @action(
        detail=True,
        methods=["post"],
        url_path="join",
    )
    @transaction.atomic
    def join(self, request, pk=None):
        group = CommunityGroup.objects.filter(
            id=pk,
        ).first()

        if group is None:
            return Response(
                {"error": "找不到群組"},
                status=status.HTTP_404_NOT_FOUND,
            )

        if group.is_private:
            return Response(
                {"error": "私人群組需要申請加入"},
                status=status.HTTP_403_FORBIDDEN,
            )

        if CommunityGroupMember.objects.filter(
            group=group,
            member=request.user,
        ).exists():
            return Response(
                {"error": "你已經是群組成員"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        CommunityGroupMember.objects.create(
            group=group,
            member=request.user,
        )

        serializer = CommunityGroupSerializer(
            group,
            context={
                "request": request,
            },
        )

        return Response(
            serializer.data,
            status=status.HTTP_200_OK,
        )

    @action(
        detail=True,
        methods=["post"],
        url_path="request-join",
    )
    @transaction.atomic
    def request_join(self, request, pk=None):
        group = (
            CommunityGroup.objects
            .select_for_update()
            .filter(
                id=pk,
            )
            .first()
        )

        if group is None:
            return Response(
                {
                    "error": "找不到群組",
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        if not group.is_private:
            return Response(
                {
                    "error": "公開群組不需要申請加入",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if CommunityGroupMember.objects.filter(
            group=group,
            member=request.user,
        ).exists():
            return Response(
                {
                    "error": "你已經是群組成員",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if group.group_members.count() >= 30:
            return Response(
                {
                    "error": "群組已達 30 人上限",
                },
                status=status.HTTP_409_CONFLICT,
            )

        pending_exists = (
            CommunityGroupJoinRequest.objects
            .filter(
                group=group,
                requester=request.user,
                status=CommunityGroupJoinRequest.STATUS_PENDING,
            )
            .exists()
        )

        if pending_exists:
            return Response(
                {
                    "error": "你已經申請加入此群組",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        join_request = (
            CommunityGroupJoinRequest.objects.create(
                group=group,
                requester=request.user,
            )
        )

        serializer = CommunityGroupJoinRequestSerializer(
            join_request,
        )

        return Response(
            serializer.data,
            status=status.HTTP_201_CREATED,
        )

    @action(
        detail=True,
        methods=["get"],
        url_path="join-requests",
    )
    def join_requests(self, request, pk=None):
        group = self.get_object()

        if group.owner_id != request.user.id:
            return Response(
                {
                    "error": "只有群組創立者可以查看加入申請",
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        requests = (
            CommunityGroupJoinRequest.objects
            .filter(
                group=group,
                status=CommunityGroupJoinRequest.STATUS_PENDING,
            )
            .select_related(
                "group",
                "requester",
            )
            .order_by("-created_at")
        )

        serializer = CommunityGroupJoinRequestSerializer(
            requests,
            many=True,
        )

        return Response(serializer.data)

    @action(
        detail=True,
        methods=["post"],
        url_path=r"join-requests/(?P<request_id>\d+)/respond",
    )
    @transaction.atomic
    def respond_join_request(
        self,
        request,
        pk=None,
        request_id=None,
    ):
        group = (
            CommunityGroup.objects
            .select_for_update()
            .filter(id=pk)
            .first()
        )

        if group is None:
            return Response(
                {
                    "error": "找不到群組",
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        if group.owner_id != request.user.id:
            return Response(
                {
                    "error": "只有群組創立者可以處理加入申請",
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        join_request = (
            CommunityGroupJoinRequest.objects
            .select_for_update()
            .select_related(
                "requester",
                "group",
            )
            .filter(
                id=request_id,
                group=group,
                status=CommunityGroupJoinRequest.STATUS_PENDING,
            )
            .first()
        )

        if join_request is None:
            return Response(
                {
                    "error": "找不到待處理的加入申請",
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        action_value = str(
            request.data.get(
                "action",
                "",
            )
        ).strip().lower()

        if action_value not in [
            "accept",
            "reject",
        ]:
            return Response(
                {
                    "error": "action 必須為 accept 或 reject",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if action_value == "reject":
            join_request.status = (
                CommunityGroupJoinRequest.STATUS_REJECTED
            )
            join_request.responded_at = timezone.now()

            join_request.save(
                update_fields=[
                    "status",
                    "responded_at",
                    "updated_at",
                ]
            )

            return Response(
                CommunityGroupJoinRequestSerializer(
                    join_request,
                ).data,
            )

        already_member = CommunityGroupMember.objects.filter(
            group=group,
            member=join_request.requester,
        ).exists()

        if not already_member:
            if group.group_members.count() >= 30:
                return Response(
                    {
                        "error": "群組已達 30 人上限",
                    },
                    status=status.HTTP_409_CONFLICT,
                )

            CommunityGroupMember.objects.create(
                group=group,
                member=join_request.requester,
            )

        join_request.status = (
            CommunityGroupJoinRequest.STATUS_ACCEPTED
        )
        join_request.responded_at = timezone.now()

        join_request.save(
            update_fields=[
                "status",
                "responded_at",
                "updated_at",
            ]
        )

        return Response(
            CommunityGroupJoinRequestSerializer(
                join_request,
            ).data,
        )

    # =========================
    # 移除群組成員
    # =========================
    @action(
        detail=True,
        methods=["delete"],
        url_path=r"members/(?P<member_id>\d+)",
    )
    @transaction.atomic
    def remove_member(
        self,
        request,
        pk=None,
        member_id=None,
    ):
        group = CommunityGroup.objects.filter(
            id=pk,
        ).first()

        if group is None:
            return Response(
                {
                    "error": "找不到群組",
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        # 只有群組創立者可以移除成員
        if group.owner_id != request.user.id:
            return Response(
                {
                    "error": "只有群組創立者可以移除成員",
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        try:
            member_id = int(member_id)
        except (TypeError, ValueError):
            return Response(
                {
                    "error": "成員 ID 格式錯誤",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # 不允許移除自己
        if member_id == group.owner_id:
            return Response(
                {
                    "error": "無法移除群組創立者",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        membership = (
            CommunityGroupMember.objects
            .filter(
                group=group,
                member_id=member_id,
            )
            .select_related("member")
            .first()
        )

        if membership is None:
            return Response(
                {
                    "error": "找不到此群組成員",
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        member = membership.member

        # 清除該成員在此群組活動中的參加紀錄
        CommunityGroupActivityParticipant.objects.filter(
            activity__group=group,
            member=member,
        ).delete()

        membership.delete()

        return Response(
            {
                "message": "已移除群組成員",
            },
            status=status.HTTP_200_OK,
        )

    # =========================
    # 退出群組
    # =========================
    @action(
        detail=True,
        methods=["post"],
        url_path="leave",
    )
    @transaction.atomic
    def leave(self, request, pk=None):
        group = CommunityGroup.objects.filter(
            id=pk,
        ).first()

        if group is None:
            return Response(
                {
                    "error": "找不到群組",
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        # 創立者不能直接退出
        if group.owner_id == request.user.id:
            return Response(
                {
                    "error": "群組創立者無法退出群組",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        membership = CommunityGroupMember.objects.filter(
            group=group,
            member=request.user,
        ).first()

        if membership is None:
            return Response(
                {
                    "error": "你不是此群組的成員",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # 移除這個人在該群組活動中的參加紀錄
        CommunityGroupActivityParticipant.objects.filter(
            activity__group=group,
            member=request.user,
        ).delete()

        membership.delete()

        return Response(
            {
                "message": "已退出群組",
            },
            status=status.HTTP_200_OK,
        )

    @transaction.atomic
    def perform_create(self, serializer):
        group = serializer.save(
            owner=self.request.user,
        )

        CommunityGroupMember.objects.create(
            group=group,
            member=self.request.user,
        )

    @action(
        detail=True,
        methods=["post"],
        url_path="invite",
    )
    def invite(self, request, pk=None):
        group = self.get_object()

        if group.owner_id != request.user.id:
            return Response(
                {
                    "error": "只有群組創立者可以邀請成員",
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        invitee_id = request.data.get(
            "invitee_id",
        )

        if not invitee_id:
            return Response(
                {
                    "error": "缺少 invitee_id",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            invitee = Member.objects.get(
                id=invitee_id,
            )
        except Member.DoesNotExist:
            return Response(
                {
                    "error": "找不到使用者",
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        if invitee.id == request.user.id:
            return Response(
                {
                    "error": "不能邀請自己加入群組",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not self._is_friend(
            request.user,
            invitee,
        ):
            return Response(
                {
                    "error": "只能邀請好友加入群組",
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        if self._is_group_member(
            group,
            invitee,
        ):
            return Response(
                {
                    "error": "此好友已經在群組中",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if group.group_members.count() >= 30:
            return Response(
                {
                    "error": "群組已達 30 人上限",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        pending_exists = CommunityGroupInvitation.objects.filter(
            group=group,
            invitee=invitee,
            status=CommunityGroupInvitation.STATUS_PENDING,
        ).exists()

        if pending_exists:
            return Response(
                {
                    "error": "已經送出群組邀請",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        invitation = CommunityGroupInvitation.objects.create(
            group=group,
            inviter=request.user,
            invitee=invitee,
        )

        serializer = CommunityGroupInvitationSerializer(
            invitation,
        )

        return Response(
            serializer.data,
            status=status.HTTP_201_CREATED,
        )

    @action(
        detail=True,
        methods=["get", "post"],
        url_path="activities",
    )
    def activities(self, request, pk=None):
        group = self.get_object()

        is_member = CommunityGroupMember.objects.filter(
            group=group,
            member=request.user,
        ).exists()

        if not is_member:
            return Response(
                {
                    "error": "只有群組成員可以存取群組活動",
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        if request.method == "GET":
            activities = (
                CommunityGroupActivity.objects
                .filter(
                    group=group,
                )
                .select_related(
                    "creator",
                    "group",
                )
                .order_by(
                    "scheduled_at",
                    "created_at",
                )
            )

            serializer = CommunityGroupActivitySerializer(
                activities,
                many=True,
                context={
                    "request": request,
                },
            )

            return Response(
                serializer.data,
            )

        serializer = CommunityGroupActivitySerializer(
            data=request.data,
        )

        serializer.is_valid(
            raise_exception=True,
        )

        activity = serializer.save(
            group=group,
            creator=request.user,
        )

        return Response(
            CommunityGroupActivitySerializer(
                activity,
                context={
                    "request": request,
                },
            ).data,
            status=status.HTTP_201_CREATED,
        )

    @action(
        detail=True,
        methods=["post"],
        url_path=r"activities/(?P<activity_id>\d+)/join",
    )
    def join_activity(
        self,
        request,
        pk=None,
        activity_id=None,
    ):
        group = self.get_object()

        is_member = CommunityGroupMember.objects.filter(
            group=group,
            member=request.user,
        ).exists()

        if not is_member:
            return Response(
                {
                    "error": "只有群組成員可以參加群組活動",
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        activity = CommunityGroupActivity.objects.filter(
            id=activity_id,
            group=group,
        ).first()

        if activity is None:
            return Response(
                {
                    "error": "找不到群組活動",
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        _, created = (
            CommunityGroupActivityParticipant.objects
            .get_or_create(
                activity=activity,
                member=request.user,
            )
        )

        if not created:
            return Response(
                {
                    "error": "你已經參加此活動",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            CommunityGroupActivitySerializer(
                activity,
                context={
                    "request": request,
                },
            ).data,
            status=status.HTTP_200_OK,
        )


    @action(
        detail=True,
        methods=["post"],
        url_path=r"activities/(?P<activity_id>\d+)/leave",
    )
    def leave_activity(
        self,
        request,
        pk=None,
        activity_id=None,
    ):
        group = self.get_object()

        is_member = CommunityGroupMember.objects.filter(
            group=group,
            member=request.user,
        ).exists()

        if not is_member:
            return Response(
                {
                    "error": "只有群組成員可以操作群組活動",
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        activity = CommunityGroupActivity.objects.filter(
            id=activity_id,
            group=group,
        ).first()

        if activity is None:
            return Response(
                {
                    "error": "找不到群組活動",
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        participation = (
            CommunityGroupActivityParticipant.objects
            .filter(
                activity=activity,
                member=request.user,
            )
            .first()
        )

        if participation is None:
            return Response(
                {
                    "error": "你尚未參加此活動",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        participation.delete()

        return Response(
            CommunityGroupActivitySerializer(
                activity,
                context={
                    "request": request,
                },
            ).data,
            status=status.HTTP_200_OK,
        )

    def _is_friend(self, user, other):
        return Friendship.objects.filter(
            Q(member1=user, member2=other)
            | Q(member1=other, member2=user)
        ).exists()


    def _is_group_member(self, group, member):
        return CommunityGroupMember.objects.filter(
            group=group,
            member=member,
        ).exists()

class CommunityGroupInvitationViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    @action(
        detail=False,
        methods=["get"],
        url_path="pending",
    )
    def pending(self, request):
        invitations = (
            CommunityGroupInvitation.objects
            .filter(
                invitee=request.user,
                status=CommunityGroupInvitation.STATUS_PENDING,
            )
            .select_related(
                "group",
                "inviter",
                "invitee",
            )
            .order_by("-created_at")
        )

        serializer = CommunityGroupInvitationSerializer(
            invitations,
            many=True,
        )

        return Response(
            serializer.data,
        )

    @action(
        detail=True,
        methods=["post"],
        url_path="respond",
    )
    @transaction.atomic
    def respond(self, request, pk=None):
        try:
            invitation = (
                CommunityGroupInvitation.objects
                .select_for_update()
                .select_related(
                    "group",
                    "inviter",
                    "invitee",
                )
                .get(
                    id=pk,
                    invitee=request.user,
                )
            )
        except CommunityGroupInvitation.DoesNotExist:
            return Response(
                {
                    "error": "找不到群組邀請",
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        if invitation.status != CommunityGroupInvitation.STATUS_PENDING:
            return Response(
                {
                    "error": "此群組邀請已處理",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        action_value = str(
            request.data.get(
                "action",
                "",
            )
        ).strip().lower()

        if action_value not in [
            "accept",
            "reject",
        ]:
            return Response(
                {
                    "error": "action 必須為 accept 或 reject",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if action_value == "reject":
            invitation.status = (
                CommunityGroupInvitation.STATUS_REJECTED
            )

            invitation.responded_at = timezone.now()

            invitation.save(
                update_fields=[
                    "status",
                    "responded_at",
                    "updated_at",
                ]
            )

            serializer = CommunityGroupInvitationSerializer(
                invitation,
            )

            return Response(
                serializer.data,
            )

        group = (
            CommunityGroup.objects
            .select_for_update()
            .get(
                id=invitation.group_id,
            )
        )

        already_member = CommunityGroupMember.objects.filter(
            group=group,
            member=request.user,
        ).exists()

        if already_member:
            invitation.status = (
                CommunityGroupInvitation.STATUS_ACCEPTED
            )

            invitation.responded_at = timezone.now()

            invitation.save(
                update_fields=[
                    "status",
                    "responded_at",
                    "updated_at",
                ]
            )

            serializer = CommunityGroupInvitationSerializer(
                invitation,
            )

            return Response(
                serializer.data,
            )

        if group.group_members.count() >= 30:
            return Response(
                {
                    "error": "群組已達 30 人上限",
                },
                status=status.HTTP_409_CONFLICT,
            )

        CommunityGroupMember.objects.create(
            group=group,
            member=request.user,
        )

        invitation.status = (
            CommunityGroupInvitation.STATUS_ACCEPTED
        )

        invitation.responded_at = timezone.now()

        invitation.save(
            update_fields=[
                "status",
                "responded_at",
                "updated_at",
            ]
        )

        return Response(
            serializer.data,
        )

POINT_FEATURES = {
    "personal_workout_plan": {
        "points": 70,
        "name": "個人化運動計畫",
    },
    "deep_analysis": {
        "points": 50,
        "name": "深度運動分析",
    },
    "full_analysis_report": {
        "points": 200,
        "name": "完整運動分析報告",
    },
    "pain_report": {
        "points": 130,
        "name": "疼痛報告",
    },
    "ad_free_7_days": {
        "points": 35,
        "name": "無廣告 7 天",
    },
    "advanced_reminder": {
        "points": 35,
        "name": "進階運動提醒",
    },
}

class PointsViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    @action(detail=False, methods=["get"], url_path="balance")
    def balance(self, request):
        user = request.user

        return Response({
            "balance": user.points,
            "user_id": user.id,
            "username": user.username,
        })

    @action(detail=False, methods=["get"], url_path="transactions")
    def transactions(self, request):
        user = request.user
        is_all = request.query_params.get("all") == "true"
        tran_type = request.query_params.get("type")

        # 如果帶有 all=true 且具有工作人員身份，就查全平台；否則只查自己
        if is_all and (getattr(user, "is_staff", False) or user.is_superuser):
            queryset = PointTransaction.objects.all().select_related("member")
        else:
            queryset = PointTransaction.objects.filter(member=user)

        # 支援類型篩選 (top_up, spend, reward)
        if tran_type and tran_type != "all":
            queryset = queryset.filter(tran_type=tran_type)

        transactions = queryset.order_by("-created_at")[:100]

        serializer = PointTransactionSerializer(
            transactions,
            many=True,
        )

        return Response(serializer.data)

    @action(detail=False, methods=["post"], url_path="use")
    @transaction.atomic
    def use_points(self, request):
        feature_code = str(
            request.data.get("feature_code", "")
        ).strip()

        feature = POINT_FEATURES.get(feature_code)

        if not feature:
            return Response(
                {
                    "error": "無效的付費功能",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = (
            Member.objects
            .select_for_update()
            .get(id=request.user.id)
        )

        points_to_use = feature["points"]
        feature_name = feature["name"]

        if user.points < points_to_use:
            return Response(
                {
                    "error": "點數餘額不足",
                    "balance": user.points,
                    "required_points": points_to_use,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.points -= points_to_use
        user.save(update_fields=["points"])

        tran = PointTransaction.objects.create(
            member=user,
            points_changed=-points_to_use,
            tran_type="spend",
            description=f"解鎖：{feature_name}",
            status="completed",
        )

        return Response(
            {
                "message": f"已解鎖{feature_name}",
                "feature_code": feature_code,
                "feature_name": feature_name,
                "points_used": points_to_use,
                "remaining_balance": user.points,
                "transaction": PointTransactionSerializer(
                    tran
                ).data,
            }
        )
    
    @action(
        detail=False,
        methods=["post"],
        url_path="ecpay/checkout",
    )
    @transaction.atomic
    def ecpay_checkout(self, request):
        user = request.user

        try:
            amount = int(
                request.data.get("amount", 33)
            )
            points = int(
                request.data.get("points", 160)
            )
        except (TypeError, ValueError):
            amount, points = 33, 160

        now_str = timezone.now().strftime(
            "%Y%m%d%H%M%S"
        )

        import random

        order_number = (
            f"SOM{now_str}"
            f"{random.randint(100, 999)}"
        )

        item_name = f"SlowOnMove {points}點儲值方案"

        description = (
            f"綠界金流儲值 "
            f"NT${amount} 得 {points}點"
        )

        tran = PointTransaction.objects.create(
            member=user,
            points_changed=points,
            tran_type="top_up",
            description=description,
            order_number=order_number,
            status="pending",
        )

        domain = request.build_absolute_uri("/")[:-1]

        return_url = (
            f"{domain}/api/points/"
            f"ecpay/callback/"
        )

        client_back_url = (
            f"{domain}/api/points/"
            f"ecpay/success/"
        )

        checkout_data = (
            ECPayService.create_checkout_params(
                order_number=order_number,
                amount=amount,
                item_name=item_name,
                return_url=return_url,
                client_back_url=client_back_url,
            )
        )

        return Response({
            "order_number": order_number,
            "amount": amount,
            "points": points,
            "checkout_url": checkout_data[
                "checkout_url"
            ],
            "ecpay_params": checkout_data[
                "params"
            ],
            "transaction_id": tran.id,
        })

    @action(
        detail=False,
        methods=["post"],
        url_path="ecpay/simulate",
    )
    @transaction.atomic
    def ecpay_simulate(self, request):
        user = (
            Member.objects
            .select_for_update()
            .get(id=request.user.id)
        )

        try:
            amount = int(
                request.data.get("amount", 33)
            )
            points = int(
                request.data.get("points", 160)
            )
        except (TypeError, ValueError):
            amount, points = 33, 160

        now_str = timezone.now().strftime(
            "%Y%m%d%H%M%S"
            )

        import random

        order_number = (
            f"SIM{now_str}"
            f"{random.randint(100, 999)}"
        )

        description = (
            f"綠界科技 (ECPay測試) 儲值 "
            f"NT${amount} 得 {points}點"
        )

        user.points += points
        user.save(update_fields=["points"])

        tran = PointTransaction.objects.create(
            member=user,
            points_changed=points,
            tran_type="top_up",
            description=description,
            order_number=order_number,
            status="completed",
        )

        return Response({
            "message": (
                f"綠界交易完成！"
                f"已成功入帳 {points} 點"
            ),
            "new_balance": user.points,
            "transaction": PointTransactionSerializer(
                tran
            ).data,
        })

    @action(
        detail=False,
        methods=["post"],
        permission_classes=[AllowAny],
        url_path="ecpay/callback",
    )
    @transaction.atomic
    def ecpay_callback(self, request):
        post_data = (
            request.data.dict()
            if hasattr(request.data, "dict")
            else dict(request.data)
        )

        if not ECPayService.verify_check_mac_value(
            post_data
        ):
            return Response(
                "0|CheckMacValue Error",
                status=status.HTTP_400_BAD_REQUEST,
            )

        order_number = post_data.get(
            "MerchantTradeNo"
        )

        rtn_code = str(
            post_data.get("RtnCode")
        )

        if rtn_code == "1":
            tran = (
                PointTransaction.objects
                .select_for_update()
                .filter(
                    order_number=order_number,
                    status="pending",
                )
                .first()
            )

            if tran:
                tran.status = "completed"
                tran.save(
                    update_fields=["status"]
                )

                member = (
                    Member.objects
                    .select_for_update()
                    .get(id=tran.member_id)
                )

                member.points += tran.points_changed

                member.save(
                    update_fields=["points"]
                )

        return Response("1|OK")

    @action(
        detail=False,
        methods=["get"],
        url_path="features",
    )
    def features(self, request):
        return Response([
            {
                "code": code,
                "name": feature["name"],
                "points": feature["points"],
            }
            for code, feature in POINT_FEATURES.items()
        ])

    @action(
        detail=False,
        methods=["get"],
        url_path="unlocks",
    )
    def unlocks(self, request):
        unlocks = (
            FeatureUnlock.objects
            .filter(member=request.user)
            .order_by("-unlocked_at")
        )

        data = [
            {
                "feature_code": unlock.feature_code,
                "reference_id": unlock.reference_id,
                "unlocked_at": unlock.unlocked_at,
            }
            for unlock in unlocks
        ]

        return Response(data)




def compute_admin_analytics(timeframe="all"):
    from datetime import timedelta
    # pyrefly: ignore [missing-import]
    from django.db.models.functions import TruncDate

    now = timezone.now()
    if timeframe == "7d":
        start_date = now - timedelta(days=7)
    elif timeframe == "30d":
        start_date = now - timedelta(days=30)
    else:
        start_date = None

    # 1. Member Analytics
    members_qs = Member.objects.all()
    total_users = members_qs.count()
    
    thirty_days_ago = now - timedelta(days=30)
    seven_days_ago = now - timedelta(days=7)
    new_users_30d = members_qs.filter(date_joined__gte=thirty_days_ago).count()
    
    active_users_7d = members_qs.filter(
        Q(training_logs__created_at__gte=seven_days_ago) |
        Q(posts__created_at__gte=seven_days_ago)
    ).distinct().count()

    providers = members_qs.values('login_provider').annotate(count=Count('id'))
    provider_dict = {'email': 0, 'google': 0, 'facebook': 0}
    for item in providers:
        prov = item['login_provider'] or 'email'
        if prov in provider_dict:
            provider_dict[prov] += item['count']
        else:
            provider_dict[prov] = item['count']

    # Registration trend (last 14 days)
    reg_start = now - timedelta(days=14)
    reg_trend_qs = members_qs.filter(date_joined__gte=reg_start)\
        .annotate(date=TruncDate('date_joined'))\
        .values('date')\
        .annotate(count=Count('id'))\
        .order_by('date')
    reg_trend = [{'date': item['date'].strftime('%m/%d'), 'count': item['count']} for item in reg_trend_qs if item.get('date')]

    # 2. Training Analytics
    tlog_qs = TrainingLog.objects.all()
    if start_date:
        tlog_qs_filtered = tlog_qs.filter(created_at__gte=start_date)
    else:
        tlog_qs_filtered = tlog_qs

    total_mins = tlog_qs_filtered.aggregate(val=Sum('total_mins'))['val'] or 0
    total_calories = tlog_qs_filtered.aggregate(val=Sum('calories'))['val'] or 0
    total_sessions = tlog_qs_filtered.count()

    ex_types = tlog_qs_filtered.values('exercise_type').annotate(count=Count('id'))
    ex_dict = {'slow_jogging': 0, 'squat': 0}
    for item in ex_types:
        key = item['exercise_type']
        if key in ex_dict:
            ex_dict[key] = item['count']

    scores = list(tlog_qs_filtered.values_list('posture_score', flat=True))
    if scores:
        avg_posture = round(sum(scores) / len(scores), 1)
    else:
        avg_posture = 0.0

    good_cnt = tlog_qs_filtered.filter(posture_score__gte=80).count()
    fair_cnt = tlog_qs_filtered.filter(posture_score__gte=60, posture_score__lt=80).count()
    needs_work_cnt = tlog_qs_filtered.filter(posture_score__lt=60).count()

    train_trend_qs = tlog_qs.filter(created_at__gte=seven_days_ago)\
        .annotate(date=TruncDate('created_at'))\
        .values('date')\
        .annotate(mins=Sum('total_mins'), sessions=Count('id'))\
        .order_by('date')
    train_trend = [{'date': item['date'].strftime('%m/%d'), 'mins': item['mins'] or 0, 'sessions': item['sessions']} for item in train_trend_qs if item.get('date')]

    # 3. Community Analytics
    post_qs = CommunityPost.objects.all()
    if start_date:
        post_qs_filtered = post_qs.filter(created_at__gte=start_date)
    else:
        post_qs_filtered = post_qs

    total_posts = post_qs_filtered.count()
    total_likes = PostLike.objects.filter(created_at__gte=start_date).count() if start_date else PostLike.objects.count()
    total_comments = PostComment.objects.filter(created_at__gte=start_date).count() if start_date else PostComment.objects.count()

    post_types_raw = post_qs_filtered.values('post_type').annotate(count=Count('id'))
    post_types_dict = {'journey': 0, 'plan': 0, 'recipe': 0}
    for item in post_types_raw:
        pt = item['post_type']
        if pt in post_types_dict:
            post_types_dict[pt] = item['count']

    reports_raw = PostReport.objects.values('status').annotate(count=Count('id'))
    reports_dict = {'pending': 0, 'resolved': 0}
    for item in reports_raw:
        st = item['status']
        if st == 'pending':
            reports_dict['pending'] += item['count']
        else:
            reports_dict['resolved'] += item['count']

    # 4. Financial & Points Analytics
    ptran_qs = PointTransaction.objects.filter(status='completed')
    if start_date:
        ptran_qs_filtered = ptran_qs.filter(created_at__gte=start_date)
    else:
        ptran_qs_filtered = ptran_qs

    total_transactions = ptran_qs_filtered.count()
    total_points_changed = ptran_qs_filtered.aggregate(val=Sum('points_changed'))['val'] or 0

    tran_types_raw = ptran_qs_filtered.values('tran_type').annotate(count=Count('id'))
    tran_types_dict = {'top_up': 0, 'spend': 0, 'reward': 0}
    for item in tran_types_raw:
        tt = item['tran_type']
        if tt in tran_types_dict:
            tran_types_dict[tt] = item['count']

    topup_trans = ptran_qs_filtered.filter(tran_type='top_up')
    total_revenue = 0
    amount_counts = {'33': 0, '170': 0, '490': 0, '990': 0, '1690': 0, '3290': 0}
    for t in topup_trans:
        desc = t.description or ''
        if 'NT$' in desc:
            try:
                amt_str = desc.split('NT$')[1].split(' ')[0]
                amt = int(amt_str)
                total_revenue += amt
                if str(amt) in amount_counts:
                    amount_counts[str(amt)] += 1
            except Exception:
                pass

    return {
        "timeframe": timeframe,
        "user_analytics": {
            "total_users": total_users,
            "new_users_30d": new_users_30d,
            "active_users_7d": active_users_7d,
            "login_providers": provider_dict,
            "registration_trend": reg_trend,
        },
        "exercise_analytics": {
            "total_mins": total_mins,
            "total_calories": total_calories,
            "total_sessions": total_sessions,
            "exercise_types": ex_dict,
            "posture_score": {
                "average": avg_posture,
                "good": good_cnt,
                "fair": fair_cnt,
                "needs_work": needs_work_cnt,
            },
            "daily_trend": train_trend,
        },
        "community_analytics": {
            "total_posts": total_posts,
            "total_likes": total_likes,
            "total_comments": total_comments,
            "post_types": post_types_dict,
            "report_status": reports_dict,
        },
        "points_analytics": {
            "total_ecpay_revenue_twd": total_revenue,
            "total_points_changed": total_points_changed,
            "total_transactions": total_transactions,
            "transaction_types": tran_types_dict,
            "topup_amounts": amount_counts,
        }
    }


class AdminAnalyticsView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        timeframe = request.query_params.get("timeframe", "all")
        data = compute_admin_analytics(timeframe=timeframe)

        # 確保 data 是字典結構
        if not isinstance(data, dict):
            data = {}

        # ----------------------------------------------------
        # 4. 跑後身體不適與疼痛部位統計 (Pain Analytics)
        # ----------------------------------------------------
        try:
            # 撈取有填寫 pain_parts 的紀錄（排除 None 與空列表）
            logs = TrainingLog.objects.exclude(pain_parts__isnull=True)
            
            total_pain_reports = 0
            top_pain_parts = {}

            for log in logs:
                parts = getattr(log, 'pain_parts', [])
                # 兼容 JSONField 與字串解析
                if isinstance(parts, str):
                    try:
                        import json
                        parts = json.loads(parts)
                    except Exception:
                        parts = []

                if isinstance(parts, list) and len(parts) > 0:
                    total_pain_reports += 1
                    for part in parts:
                        if part:
                            top_pain_parts[part] = top_pain_parts.get(part, 0) + 1

            # 依回報次數由高至低排序
            sorted_pain_parts = dict(
                sorted(top_pain_parts.items(), key=lambda item: item[1], reverse=True)
            )

            data['pain_analytics'] = {
                'total_pain_reports': total_pain_reports,
                'top_pain_parts': sorted_pain_parts,
            }
        except Exception as e:
            # 若發生例外則給予安全預設值，避免畫面炸開
            data['pain_analytics'] = {
                'total_pain_reports': 0,
                'top_pain_parts': {},
            }

        # 抓取真實近期動態 (運動紀錄 + 新會員 + 貼文)
        activities = []
        now = timezone.now()

        # 1. 最新 3 筆運動紀錄
        try:
            latest_trainings = TrainingLog.objects.select_related('member').order_by('-created_at')[:3]
            for log in latest_trainings:
                user_name = getattr(log.member, 'nickname', None) or getattr(log.member, 'username', '使用者')
                duration = getattr(log, 'total_mins', getattr(log, 'duration_mins', getattr(log, 'duration', 0)))
                activities.append({
                    'title': f"{user_name} 完成了 {duration} 分鐘運動",
                    'type': 'exercise',
                    'created_at': log.created_at.isoformat() if hasattr(log, 'created_at') else now.isoformat(),
                })
        except Exception:
            pass

        # 2. 最新 3 位新註冊會員
        try:
            date_field = '-created_at' if hasattr(Member, 'created_at') else '-date_joined'
            latest_members = Member.objects.order_by(date_field)[:3]
            for m in latest_members:
                user_name = getattr(m, 'nickname', None) or getattr(m, 'username', '新會員')
                join_time = getattr(m, 'created_at', getattr(m, 'date_joined', now))
                activities.append({
                    'title': f"{user_name} 加入了平台",
                    'type': 'user',
                    'created_at': join_time.isoformat() if hasattr(join_time, 'isoformat') else str(join_time),
                })
        except Exception:
            pass

        # 3. 最新 2 筆社群貼文
        try:
            latest_posts = CommunityPost.objects.select_related('member').order_by('-created_at')[:2]
            for p in latest_posts:
                p_user = getattr(p.member, 'nickname', None) or getattr(p.member, 'username', '會員')
                activities.append({
                    'title': f"{p_user} 發布了新貼文",
                    'type': 'post',
                    'created_at': p.created_at.isoformat() if hasattr(p, 'created_at') else now.isoformat(),
                })
        except Exception:
            pass

        # 依照時間排序取最新 5 筆
        activities.sort(key=lambda x: x.get('created_at', ''), reverse=True)

        # 注入近期動態清單到回傳資料中
        data['recent_activities'] = activities[:5]

        return Response(data, status=status.HTTP_200_OK)

@csrf_exempt
def line_webhook(request):
    if request.method == 'POST':
        signature = request.META.get('HTTP_X_LINE_SIGNATURE', '')
        body = request.body.decode('utf-8')

        try:
            events = parser.parse(body, signature)
        except InvalidSignatureError:
            return HttpResponseForbidden()
        except Exception as e:
            print(e)
            return HttpResponse(status=400)

        for event in events:
            if isinstance(event, MessageEvent) and isinstance(event.message, TextMessage):
                user_msg = event.message.text
                
                try:
                    # 1. 傳給 OpenAI 並要求回傳 JSON
                    import json
                    from core.models import LineUser, AICoachNote

                    # 取得或建立這個 LINE 帳號的使用者資料
                    line_user, _ = LineUser.objects.get_or_create(line_id=event.source.user_id)

                    sys_prompt = """
                    你是一個毒舌但是很關心學生的超慢跑教練。
                    請用繁體中文簡短、幽默地回覆。如果使用者提到任何身體狀況、疼痛、想改善的目標或習慣，請幫我記錄下來。
                    必須回傳 JSON 格式，包含兩個欄位：
                    "reply": 你的毒舌回覆內容
                    "note": 要記錄的重點(如果沒有就給空字串)
                    """

                    response = openai_client.chat.completions.create(
                        model="gpt-4o-mini",
                        response_format={ "type": "json_object" },
                        messages=[
                            {"role": "system", "content": sys_prompt},
                            {"role": "user", "content": user_msg}
                        ],
                        max_tokens=250,
                        temperature=0.7,
                    )
                    
                    data = json.loads(response.choices[0].message.content)
                    ai_reply = data.get("reply", "收到！")
                    note_str = data.get("note", "")

                    if note_str:
                        AICoachNote.objects.create(line_user=line_user, note=note_str)

                    # 2. 透過 LINE 回傳
                    line_bot_api.reply_message(
                        event.reply_token,
                        TextSendMessage(text=ai_reply)
                    )
                except Exception as e:
                    print(f"Error calling Gemini or LINE: {e}")

        return HttpResponse('OK', status=200)
    return HttpResponseForbidden()