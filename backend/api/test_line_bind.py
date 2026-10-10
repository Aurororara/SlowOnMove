from unittest.mock import patch, MagicMock

from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from core.models import Member, LineUser

LINE_ID = "U1234567890abcdef"


def _mock_line(verify_status=200, client_id="2011921761", profile_status=200, user_id=LINE_ID):
    """依序回傳 LINE verify / profile 的假回應。"""
    verify = MagicMock(status_code=verify_status)
    verify.json.return_value = {"client_id": client_id, "expires_in": 3600}
    profile = MagicMock(status_code=profile_status)
    profile.json.return_value = {"userId": user_id, "displayName": "測試用LINE"}
    return [verify, profile]


@override_settings(ROOT_URLCONF="slow_on_move.urls")
class LineBindApiTests(TestCase):
    URL = "/api/line/bind/"

    def setUp(self):
        self.member = Member.objects.create(username="alice", email="a@test.com")
        self.other = Member.objects.create(username="bob", email="b@test.com")
        self.client = APIClient()
        self.client.force_authenticate(self.member)

    @patch.dict("os.environ", {"LINE_LOGIN_CHANNEL_ID": "2011921761"})
    @patch("api.line_views.http_requests.get")
    def test_bind_success(self, mock_get):
        mock_get.side_effect = _mock_line()
        res = self.client.post(self.URL, {"access_token": "tok"}, format="json")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(LineUser.objects.get(line_id=LINE_ID).member, self.member)

    def test_requires_login(self):
        res = APIClient().post(self.URL, {"access_token": "tok"}, format="json")
        self.assertEqual(res.status_code, 401)

    def test_missing_token(self):
        res = self.client.post(self.URL, {}, format="json")
        self.assertEqual(res.status_code, 400)

    @patch("api.line_views.http_requests.get")
    def test_invalid_token(self, mock_get):
        mock_get.side_effect = _mock_line(verify_status=400)
        res = self.client.post(self.URL, {"access_token": "bad"}, format="json")
        self.assertEqual(res.status_code, 400)
        self.assertFalse(LineUser.objects.exists())

    @patch.dict("os.environ", {"LINE_LOGIN_CHANNEL_ID": "2011921761"})
    @patch("api.line_views.http_requests.get")
    def test_wrong_channel_rejected(self, mock_get):
        mock_get.side_effect = _mock_line(client_id="9999999999")
        res = self.client.post(self.URL, {"access_token": "tok"}, format="json")
        self.assertEqual(res.status_code, 400)
        self.assertFalse(LineUser.objects.exists())

    @patch("api.line_views.http_requests.get")
    def test_line_already_bound_to_other_member(self, mock_get):
        LineUser.objects.create(line_id=LINE_ID, member=self.other)
        mock_get.side_effect = _mock_line()
        res = self.client.post(self.URL, {"access_token": "tok"}, format="json")
        self.assertEqual(res.status_code, 409)
        self.assertEqual(LineUser.objects.get(line_id=LINE_ID).member, self.other)

    @patch("api.line_views.http_requests.get")
    def test_bind_existing_webhook_record(self, mock_get):
        """機器人先建立了無主的 LineUser，綁定時應沿用同一筆。"""
        orphan = LineUser.objects.create(line_id=LINE_ID)
        mock_get.side_effect = _mock_line()
        res = self.client.post(self.URL, {"access_token": "tok"}, format="json")
        self.assertEqual(res.status_code, 200)
        orphan.refresh_from_db()
        self.assertEqual(orphan.member, self.member)
        self.assertEqual(LineUser.objects.count(), 1)

    @patch("api.line_views.http_requests.get")
    def test_rebind_replaces_old_line(self, mock_get):
        old = LineUser.objects.create(line_id="Uold", member=self.member)
        mock_get.side_effect = _mock_line()
        self.client.post(self.URL, {"access_token": "tok"}, format="json")
        old.refresh_from_db()
        self.assertIsNone(old.member)
        self.assertEqual(LineUser.objects.get(line_id=LINE_ID).member, self.member)

    def test_status_and_unbind(self):
        LineUser.objects.create(line_id=LINE_ID, member=self.member)
        self.assertTrue(self.client.get(self.URL).data["is_bound"])
        res = self.client.delete(self.URL)
        self.assertEqual(res.status_code, 200)
        self.assertFalse(self.client.get(self.URL).data["is_bound"])
