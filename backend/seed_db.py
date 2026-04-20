import os
import django
import datetime
from django.utils import timezone

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'slow_on_move.settings')
django.setup()

from core.models import Member, BodyRecord, TrainingLog, CommunityPost

def seed():
    print("Starting database seeding...")
    
    # 1. Create a Test Member
    user, created = Member.objects.get_or_create(
        username='testuser', 
        email='test@example.com'
    )
    if created:
        user.set_password('password123')
        user.save()
        print(f"Created user: {user.username}")
    else:
        print(f"User {user.username} already exists.")

    # 2. Create Body Record
    BodyRecord.objects.get_or_create(
        member=user,
        record_date=datetime.date.today(),
        height=175,
        weight=70
    )
    print("Created/Checked BodyRecord.")

    # 3. Create Training Logs
    now = timezone.now()
    for i in range(5):
        TrainingLog.objects.get_or_create(
            member=user,
            start_time=now - datetime.timedelta(days=i, hours=1),
            end_time=now - datetime.timedelta(days=i),
            total_mins=60,
            posture_score=85 + i,
            calories=300 + (i * 10)
        )
    print("Created 5 TrainingLogs.")

    # 4. Create Community Posts
    CommunityPost.objects.get_or_create(
        member=user,
        content="今天完成了 60 分鐘的超慢跑！感覺真棒！🏃‍♂️",
        like_count=12
    )
    print("Created CommunityPost.")

    print("Seeding complete! You now have data to work with.")

if __name__ == '__main__':
    seed()
