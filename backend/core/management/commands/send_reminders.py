import os
from django.core.management.base import BaseCommand
from core.models import LineUser
from linebot import LineBotApi
from linebot.models import TextSendMessage
from dotenv import load_dotenv

class Command(BaseCommand):
    help = 'Sends a 21:00 reminder to all LINE users to exercise'

    def handle(self, *args, **kwargs):
        load_dotenv()
        line_bot_api = LineBotApi(os.getenv('LINE_CHANNEL_ACCESS_TOKEN'))
        users = LineUser.objects.all()
        count = 0
        
        for u in users:
            try:
                line_bot_api.push_message(
                    u.line_id,
                    TextSendMessage(text="都晚上九點了！你今天的超慢跑進度呢？別以為我不知道你想偷懶！快點給我換上跑鞋！")
                )
                count += 1
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'Failed to send to {u.line_id}: {e}'))
        
        self.stdout.write(self.style.SUCCESS(f'Successfully sent reminders to {count} users'))
