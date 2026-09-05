import os
from django.apps import AppConfig
from django.db import OperationalError, ProgrammingError

class CoreConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = 'core'

    def ready(self):
        if os.getenv("CREATE_DEV_USER", "False") != "True":
            return

        try:
            from core.models import Member

            username = os.getenv("DEV_USER_USERNAME", "dev")
            email = os.getenv("DEV_USER_EMAIL", "dev@example.com")
            password = os.getenv("DEV_USER_PASSWORD", "dev123456")
            name = os.getenv("DEV_USER_NAME", "Dev User")

            user, created = Member.objects.get_or_create(
                username=username,
                defaults={
                    "email": email,
                    "first_name": name,
                    "login_provider": "local",
                },
            )

            if created:
                user.set_password(password)
                user.save()

                print(f"[DEV] Created test user: {username}")
            else:
                print(f"[DEV] Test user already exists: {username}")

        except (OperationalError, ProgrammingError):
            # migrate / database 尚未準備完成時不要讓 Django 啟動失敗
            pass
