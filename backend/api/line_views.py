"""
LINE 帳號綁定 API（方法一：App 端完成 LINE Login，把 access token 交給後端驗證並綁定）

流程：
1. Flutter App 透過 LINE Login SDK 取得 LINE access token
2. App 以「已登入的 JWT」呼叫 POST /api/line/bind/，帶上 access_token
3. 後端向 LINE 官方 API 驗證 token，取得 LINE userId
4. 將 LineUser(line_id=userId).member 綁定到目前登入的 Member

注意：LINE Login channel 與 Messaging API（機器人）channel 必須在同一個 Provider 底下，
      這樣 LINE Login 取得的 userId 才會和 webhook 收到的 event.source.user_id 一致。

環境變數：
- LINE_LOGIN_CHANNEL_ID（選填）：預設為 2011921761；要換 channel 時可在 .env 覆寫
"""
import os

import requests as http_requests
from django.db import transaction
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.models import LineUser

LINE_VERIFY_URL = "https://api.line.me/oauth2/v2.1/verify"
LINE_PROFILE_URL = "https://api.line.me/v2/profile"
# Channel ID 不是機密，內建預設值，確保 token 一定是發給我們自己的 LINE Login channel
DEFAULT_LINE_LOGIN_CHANNEL_ID = "2011921761"


class LineTokenError(Exception):
    """LINE access token 驗證失敗。"""


def fetch_line_profile(access_token):
    """
    驗證 LINE access token 並回傳 profile dict（含 userId、displayName、pictureUrl）。
    驗證失敗會丟出 LineTokenError。
    """
    # 1. 驗證 token 是否有效、是否屬於我們的 LINE Login channel
    try:
        verify_res = http_requests.get(
            LINE_VERIFY_URL,
            params={"access_token": access_token},
            timeout=10,
        )
    except http_requests.RequestException as e:
        raise LineTokenError(f"無法連線到 LINE 伺服器：{e}")

    if verify_res.status_code != 200:
        raise LineTokenError("LINE access token 無效或已過期")

    expected_channel_id = os.getenv("LINE_LOGIN_CHANNEL_ID", DEFAULT_LINE_LOGIN_CHANNEL_ID)
    if expected_channel_id:
        token_channel_id = str(verify_res.json().get("client_id", ""))
        if token_channel_id != str(expected_channel_id):
            raise LineTokenError("此 LINE token 不屬於本 App 的 LINE Login channel")

    # 2. 取得 LINE 使用者資料
    try:
        profile_res = http_requests.get(
            LINE_PROFILE_URL,
            headers={"Authorization": f"Bearer {access_token}"},
            timeout=10,
        )
    except http_requests.RequestException as e:
        raise LineTokenError(f"無法連線到 LINE 伺服器：{e}")

    if profile_res.status_code != 200:
        raise LineTokenError("無法取得 LINE 使用者資料（請確認已授權 profile scope）")

    profile = profile_res.json()
    if not profile.get("userId"):
        raise LineTokenError("LINE 回傳資料缺少 userId")

    return profile


class LineBindView(APIView):
    """
    GET    /api/line/bind/  查詢目前帳號的 LINE 綁定狀態
    POST   /api/line/bind/  綁定 LINE 帳號（body: {"access_token": "..."}）
    DELETE /api/line/bind/  解除綁定
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        line_user = LineUser.objects.filter(member=request.user).first()
        return Response(
            {"is_bound": line_user is not None},
            status=status.HTTP_200_OK,
        )

    def post(self, request):
        access_token = request.data.get("access_token")
        if not access_token:
            return Response(
                {"error": "請提供 LINE access_token"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            profile = fetch_line_profile(access_token)
        except LineTokenError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        line_id = profile["userId"]

        with transaction.atomic():
            line_user, _ = LineUser.objects.select_for_update().get_or_create(
                line_id=line_id
            )

            # 這個 LINE 帳號已經綁給別的 App 帳號
            if line_user.member_id and line_user.member_id != request.user.id:
                return Response(
                    {"error": "此 LINE 帳號已綁定其他 App 帳號"},
                    status=status.HTTP_409_CONFLICT,
                )

            # 一個 App 帳號只保留一個 LINE 綁定：先解除舊的
            LineUser.objects.filter(member=request.user).exclude(
                pk=line_user.pk
            ).update(member=None)

            line_user.member = request.user
            line_user.save(update_fields=["member"])

        return Response(
            {
                "message": "LINE 綁定成功",
                "is_bound": True,
                "line_display_name": profile.get("displayName"),
            },
            status=status.HTTP_200_OK,
        )

    def delete(self, request):
        updated = LineUser.objects.filter(member=request.user).update(member=None)
        return Response(
            {"message": "已解除 LINE 綁定" if updated else "目前沒有綁定 LINE", "is_bound": False},
            status=status.HTTP_200_OK,
        )
