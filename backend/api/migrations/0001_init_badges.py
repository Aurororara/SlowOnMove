from django.db import migrations

BADGES_DATA = [
    {"name": "起步之星", "desc": "完成首次訓練"},
    {"name": "超慢跑新星", "desc": "累積 5 次超慢跑訓練"},
    {"name": "深蹲入門生", "desc": "累積 5 次深蹲訓練"},
    {"name": "穩穩前進", "desc": "連續運動 3 天"},
    {"name": "節奏守護者", "desc": "連續運動 7 天"},
    {"name": "不間斷玩家", "desc": "連續運動 30 天"},
    {"name": "今日萬步王", "desc": "單日累積步數突破 10000 步"},
    {"name": "姿勢優等生", "desc": "單次運動姿勢分數達 80 分以上"},
    {"name": "穩定輸出王", "desc": "連續 5 次姿勢分數超過 90 分"},
    {"name": "燃脂小火苗", "desc": "累積消耗超過 500 大卡"},
    {"name": "燃燒模式", "desc": "累積消耗超過 3000 大卡"},
    {"name": "社群冒險家", "desc": "發布第一篇社群貼文"},
    {"name": "人氣回應王", "desc": "單篇貼文獲得 20 則以上留言"},
    {"name": "按讚收集者", "desc": "累積獲得超過 100 個讚"},
]

def create_initial_badges(apps, schema_editor):
    Badge = apps.get_model('core', 'Badge')
    
    field_names = [f.name for f in Badge._meta.get_fields()]
    name_field = 'badge_name' if 'badge_name' in field_names else 'name'
    desc_field = 'description' if 'description' in field_names else None

    for item in BADGES_DATA:
        lookup = {name_field: item["name"]}
        defaults = {desc_field: item["desc"]} if desc_field else {}
        Badge.objects.get_or_create(**lookup, defaults=defaults)

def reverse_func(apps, schema_editor):
    pass

class Migration(migrations.Migration):

    dependencies = [  ('core', '__latest__'),  ]

    operations = [
        migrations.RunPython(create_initial_badges, reverse_func),
    ]