import os
import requests as http_requests
from django.db.models import Q

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from rest_framework import status

from django.contrib.auth import get_user_model, authenticate
from django.contrib.auth.hashers import make_password
from rest_framework_simplejwt.tokens import RefreshToken

from google.oauth2 import id_token
from google.auth.transport import requests as google_requests

Member = get_user_model()


def get_google_client_ids():
    client_ids = [
        os.getenv("GOOGLE_WEB_CLIENT_ID"),
        os.getenv("GOOGLE_ANDROID_CLIENT_ID"),
        os.getenv("GOOGLE_IOS_CLIENT_ID"),
        os.getenv("GOOGLE_OAUTH2_CLIENT_ID"),
    ]
    return [client_id for client_id in client_ids if client_id]


def create_jwt_response(user, created, message):
    refresh = RefreshToken.for_user(user)

    return Response({
        "message": message,
        "access": str(refresh.access_token),
        "refresh": str(refresh),
        "user": {
            "id": user.id,
            "email": user.email,
            "name": user.first_name,
            "avatar": getattr(user, "avatar", ""),
        },
        "is_new_user": created,
    }, status=status.HTTP_200_OK)


class GoogleLoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        id_token_value = request.data.get("id_token")
        access_token_value = request.data.get("access_token")

        if not id_token_value and not access_token_value:
            return Response(
                {"error": "No Google token provided"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            user_info = None

            if id_token_value:
                allowed_client_ids = get_google_client_ids()

                idinfo = id_token.verify_oauth2_token(
                    id_token_value,
                    google_requests.Request(),
                    None,
                    clock_skew_in_seconds=10,
                )

                token_audience = idinfo.get("aud")

                if allowed_client_ids and token_audience not in allowed_client_ids:
                    return Response(
                        {
                            "error": "Invalid Google token audience",
                            "aud": token_audience,
                            "allowed_client_ids": allowed_client_ids,
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                user_info = {
                    "email": idinfo.get("email"),
                    "name": idinfo.get("name", "Google User"),
                    "picture": idinfo.get("picture"),
                    "provider_id": idinfo.get("sub"),
                }

            elif access_token_value:
                google_response = http_requests.get(
                    "https://www.googleapis.com/oauth2/v3/userinfo",
                    headers={"Authorization": f"Bearer {access_token_value}"},
                    timeout=10,
                )

                if google_response.status_code != 200:
                    return Response(
                        {
                            "error": "Invalid Google access token",
                            "details": google_response.text,
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                data = google_response.json()

                user_info = {
                    "email": data.get("email"),
                    "name": data.get("name", "Google User"),
                    "picture": data.get("picture"),
                    "provider_id": data.get("sub"),
                }

            email = user_info.get("email")
            name = user_info.get("name")
            picture = user_info.get("picture")
            provider_id = user_info.get("provider_id")

            if not email:
                return Response(
                    {"error": "Google account missing email"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            user, created = Member.objects.get_or_create(
                username=email,
                defaults={
                    "email": email,
                    "first_name": name,
                },
            )

            updated = False

            if name and user.first_name != name:
                user.first_name = name
                updated = True

            if user.email != email:
                user.email = email
                updated = True

            if hasattr(user, "avatar") and picture:
                user.avatar = picture
                updated = True

            if hasattr(user, "login_provider"):
                user.login_provider = "google"
                updated = True

            if hasattr(user, "provider_id") and provider_id:
                user.provider_id = provider_id
                updated = True

            if updated:
                user.save()

            # 檢查停權狀態
            if not user.is_active:
                return Response(
                    {"error": "您的帳號已被管理員停權，無法登入系統！"},
                    status=status.HTTP_403_FORBIDDEN,
                )

            return create_jwt_response(user, created, "Google login successful")

        except ValueError as e:
            return Response(
                {
                    "error": "Invalid Google id_token",
                    "details": str(e),
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        except Exception as e:
            return Response(
                {
                    "error": "Google login failed",
                    "details": str(e),
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


class FacebookLoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        access_token = request.data.get("access_token")

        request_facebook_id = request.data.get("facebook_id")
        request_name = request.data.get("name")
        request_email = request.data.get("email")
        request_avatar = request.data.get("avatar")

        if not access_token:
            return Response(
                {"error": "No Facebook access token provided"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            provider_id = None
            name = None
            email = None
            picture = None

            if access_token:
                fb_response = http_requests.get(
                    "https://graph.facebook.com/me",
                    params={
                        "fields": "id,name,email,picture.width(200).height(200)",
                        "access_token": access_token,
                    },
                    timeout=10,
                )

                if fb_response.status_code == 200:
                    fb_data = fb_response.json()

                    provider_id = fb_data.get("id")
                    name = fb_data.get("name")
                    email = fb_data.get("email")

                    if fb_data.get("picture"):
                        picture = fb_data["picture"]["data"].get("url")
                else:
                    print("Facebook Graph API failed:", fb_response.text)

            provider_id = provider_id or request_facebook_id
            name = name or request_name or "Facebook User"
            email = email or request_email
            picture = picture or request_avatar

            if not provider_id:
                return Response(
                    {
                        "error": "Facebook login failed",
                        "details": "Missing facebook_id. Please send facebook_id from Flutter.",
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if not email:
                email = f"facebook_{provider_id}@facebook.local"

            user, created = Member.objects.get_or_create(
                username=email,
                defaults={
                    "email": email,
                    "first_name": name,
                },
            )

            updated = False

            if name and user.first_name != name:
                user.first_name = name
                updated = True

            if user.email != email:
                user.email = email
                updated = True

            if hasattr(user, "avatar") and picture:
                user.avatar = picture
                updated = True

            if hasattr(user, "login_provider"):
                user.login_provider = "facebook"
                updated = True

            if hasattr(user, "provider_id") and provider_id:
                user.provider_id = provider_id
                updated = True

            if updated:
                user.save()

            # 檢查停權狀態
            if not user.is_active:
                return Response(
                    {"error": "您的帳號已被管理員停權，無法登入系統！"},
                    status=status.HTTP_403_FORBIDDEN,
                )

            return create_jwt_response(
                user,
                created,
                "Facebook login successful",
            )

        except Exception as e:
            return Response(
                {
                    "error": "Facebook login failed",
                    "details": str(e),
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        username = request.data.get("username")
        email = request.data.get("email")
        password = request.data.get("password")
        name = request.data.get("name", "")

        if not username or not password or not email:
            return Response(
                {"error": "請填寫所有必要欄位 (用戶帳號、信箱、密碼)"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if Member.objects.filter(username=username).exists():
            return Response(
                {"error": "該用戶帳號已存在"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if Member.objects.filter(email=email).exists():
            return Response(
                {"error": "該電子信箱已被註冊"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            user = Member.objects.create(
                username=username,
                email=email,
                password=make_password(password),
                first_name=name,
            )
            
            if hasattr(user, "login_provider"):
                user.login_provider = "local"
                user.save()
                
            return create_jwt_response(user, True, "註冊成功")
        except Exception as e:
            return Response(
                {"error": f"註冊失敗: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        username_or_email = request.data.get("username", "").strip()
        password = request.data.get("password", "")

        if not username_or_email or not password:
            return Response(
                {"error": "請輸入用戶帳號與密碼"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # 1. 支援用 username 或 email 找出該使用者 (不管是不是 active 都先找出來)
        user = Member.objects.filter(
            Q(username=username_or_email) | Q(email=username_or_email)
        ).first()

        # 2. 找不到使用者，或密碼比對失敗
        if not user or not user.check_password(password):
            return Response(
                {"error": "帳號或密碼錯誤"},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        # 3. 密碼正確，但帳號已被管理員停權
        if not user.is_active:
            return Response(
                {"error": "您的帳號已被管理員停權，無法登入系統！"},
                status=status.HTTP_403_FORBIDDEN,
            )

        # 4. 驗證通過，發放 JWT
        return create_jwt_response(user, False, "登入成功")