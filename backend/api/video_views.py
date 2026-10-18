"""Issue room-scoped LiveKit credentials; API secrets never leave Django."""
import time
from urllib.parse import urlsplit

import jwt
from django.conf import settings
from django.shortcuts import get_object_or_404
from rest_framework import serializers, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.models import (
    CommunityGroup, CommunityGroupActivity, CommunityGroupActivityParticipant,
    CommunityGroupMember,
)


class RoomJoinSerializer(serializers.Serializer):
    group_id = serializers.IntegerField(min_value=1, required=False)
    activity_id = serializers.IntegerField(min_value=1, required=False)

    def validate(self, attrs):
        if ('group_id' in attrs) == ('activity_id' in attrs):
            raise serializers.ValidationError('請指定一個群組或活動。')
        return attrs


class GroupRunTokenView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = RoomJoinSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        activity = None
        if 'activity_id' in data:
            activity = get_object_or_404(
                CommunityGroupActivity.objects.select_related('group'),
                pk=data['activity_id'],
            )
            group = activity.group
        else:
            group = get_object_or_404(CommunityGroup, pk=data['group_id'])

        member = request.user
        is_owner = group.owner_id == member.pk
        is_member = CommunityGroupMember.objects.filter(
            group=group, member=member,
        ).exists()
        if not (is_owner or is_member):
            return Response({'detail': '僅群組成員可加入揪團視訊。'}, status=403)
        if activity and not (
            is_owner or activity.creator_id == member.pk or
            CommunityGroupActivityParticipant.objects.filter(
                activity=activity, member=member,
            ).exists()
        ):
            return Response({'detail': '請先報名這個活動再加入視訊。'}, status=403)

        url = settings.LIVEKIT_URL
        api_key = settings.LIVEKIT_API_KEY
        secret = settings.LIVEKIT_API_SECRET
        parsed = urlsplit(url)
        if not (api_key and secret and parsed.scheme in ('ws', 'wss') and parsed.netloc):
            return Response(
                {'detail': '揪團視訊尚未開放，請稍後再試。'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        room_name = (
            f'group-{group.pk}-activity-{activity.pk}' if activity
            else f'group-{group.pk}'
        )
        now = int(time.time())
        claims = {
            'iss': api_key, 'sub': f'member-{member.pk}',
            'name': member.get_full_name() or member.username,
            'nbf': now - 5, 'iat': now, 'exp': now + 600,
            'video': {
                'roomJoin': True, 'room': room_name,
                'canPublish': True, 'canSubscribe': True,
                'canPublishData': True,
                'canPublishSources': ['camera', 'microphone'],
            },
        }
        token = jwt.encode(claims, secret, algorithm='HS256')
        response = Response({'url': url, 'token': token, 'room': room_name})
        response['Cache-Control'] = 'no-store'
        return response
