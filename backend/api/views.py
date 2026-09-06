from rest_framework import viewsets, status
from rest_framework.permissions import IsAuthenticated,AllowAny
from rest_framework.decorators import action
from rest_framework.response import Response

from django.utils import timezone
from django.db import transaction
from django.db.models import Count, Sum, Q
from api.leaderboard_service import get_leaderboard

from core.models import (
    Member, BodyRecord, BloodPressureRecord, BoardRanking, CommunityPost, Favorite, TrainingLog,
    PostLike, PostComment, PostReport, PoseAnalysis, PointTransaction,
    Task, MemberTask, Badge, MemberBadge, WorkoutMenu, WorkoutItem, PostTag,
    PostWorkoutPlan,
    PostWorkoutPlanStep,FriendRequest,
    Friendship, ChatMessage, RunInvitation,
    CommunityGroup, CommunityGroupMember, CommunityGroupInvitation,
    CommunityGroupActivity,
    CommunityGroupActivityParticipant,
    CommunityGroupJoinRequest,
)
from .serializers import (
    MemberSerializer, AdminMemberListSerializer,AdminPostReportSerializer, BodyRecordSerializer, BloodPressureRecordSerializer, BoardRankingSerializer,
    CommunityPostSerializer, FavoriteSerializer, TrainingLogSerializer,
    PostLikeSerializer, PostCommentSerializer, PostReportSerializer, PoseAnalysisSerializer, PointTransactionSerializer,
    TaskSerializer, MemberTaskSerializer, BadgeSerializer, MemberBadgeSerializer, WorkoutMenuSerializer, WorkoutItemSerializer,FriendMemberSerializer,
    FriendRequestSerializer,
    FriendSearchSerializer,
    ChatMessageSerializer,
    RunInvitationSerializer,
    CommunityGroupSerializer,
    CommunityGroupInvitationSerializer,
    CommunityGroupActivitySerializer,
    CommunityGroupJoinRequestSerializer,
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

        serializer = CommunityGroupInvitationSerializer(
            invitation,
        )

        return Response(
            serializer.data,
        )
