import time

import jwt
from django.test import override_settings
from django.utils import timezone
from rest_framework.test import APITestCase

from core.models import (
    Member, CommunityGroup, CommunityGroupMember, CommunityGroupActivity,
    CommunityGroupActivityParticipant,
)


@override_settings(
    LIVEKIT_URL='wss://video.example.test',
    LIVEKIT_API_KEY='test-key',
    LIVEKIT_API_SECRET='test-secret-at-least-thirty-two-characters',
)
class GroupRunVideoTests(APITestCase):
    url = '/api/group-runs/token/'

    def setUp(self):
        self.owner = Member.objects.create_user(username='video-owner')
        self.member = Member.objects.create_user(username='video-member')
        self.outsider = Member.objects.create_user(username='video-outsider')
        self.group = CommunityGroup.objects.create(owner=self.owner, name='跑團')
        CommunityGroupMember.objects.create(group=self.group, member=self.member)
        self.activity = CommunityGroupActivity.objects.create(
            group=self.group, creator=self.owner, title='一起跑',
            exercise_type='slow_jogging', scheduled_at=timezone.now(),
        )

    def join(self, user, **data):
        self.client.force_authenticate(user=user)
        return self.client.post(self.url, data, format='json')

    def test_anonymous_rejected(self):
        self.assertEqual(self.client.post(self.url, {'group_id': self.group.pk}).status_code, 401)

    def test_outsider_cannot_claim_member_identity(self):
        response = self.join(self.outsider, group_id=self.group.pk, member_id=self.owner.pk)
        self.assertEqual(response.status_code, 403)
        self.assertNotIn('token', response.data)

    def test_group_token_has_verified_identity_and_room_scope(self):
        response = self.join(self.member, group_id=self.group.pk, member_id=self.owner.pk)
        self.assertEqual(response.status_code, 200)
        claims = jwt.decode(response.data['token'],
                            'test-secret-at-least-thirty-two-characters',
                            algorithms=['HS256'], issuer='test-key')
        self.assertEqual(claims['sub'], f'member-{self.member.pk}')
        self.assertEqual(claims['video']['room'], f'group-{self.group.pk}')
        self.assertTrue(claims['video']['roomJoin'])
        self.assertTrue(claims['video']['canPublishData'])
        self.assertEqual(claims['video']['canPublishSources'], ['camera', 'microphone'])
        self.assertLessEqual(claims['exp'] - time.time(), 600)
        self.assertNotIn('roomAdmin', claims['video'])
        self.assertEqual(response['Cache-Control'], 'no-store')
        self.assertNotIn('secret', response.data)

    def test_activity_requires_enrolment(self):
        self.assertEqual(self.join(self.member, activity_id=self.activity.pk).status_code, 403)
        CommunityGroupActivityParticipant.objects.create(activity=self.activity, member=self.member)
        response = self.join(self.member, activity_id=self.activity.pk)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['room'], f'group-{self.group.pk}-activity-{self.activity.pk}')

    def test_owner_can_join_without_membership_row(self):
        self.assertEqual(self.join(self.owner, activity_id=self.activity.pk).status_code, 200)

    def test_removed_member_cannot_use_previous_activity_enrolment(self):
        CommunityGroupActivityParticipant.objects.create(activity=self.activity, member=self.outsider)
        self.assertEqual(self.join(self.outsider, activity_id=self.activity.pk).status_code, 403)

    def test_exactly_one_positive_identifier_required(self):
        for data in ({}, {'group_id': 0}, {'activity_id': 'bad'},
                     {'group_id': self.group.pk, 'activity_id': self.activity.pk}):
            with self.subTest(data=data):
                self.assertEqual(self.join(self.owner, **data).status_code, 400)

    def test_missing_group_and_activity(self):
        self.assertEqual(self.join(self.owner, group_id=99999).status_code, 404)
        self.assertEqual(self.join(self.owner, activity_id=99999).status_code, 404)

    @override_settings(LIVEKIT_API_SECRET='')
    def test_missing_configuration_returns_no_token(self):
        response = self.join(self.owner, group_id=self.group.pk)
        self.assertEqual(response.status_code, 503)
        self.assertNotIn('token', response.data)

    @override_settings(LIVEKIT_URL='https://invalid.example.test')
    def test_non_websocket_url_rejected(self):
        self.assertEqual(self.join(self.owner, group_id=self.group.pk).status_code, 503)
