import os
import django
from django.conf import settings

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'slow_on_move.settings')
django.setup()

from django.apps import apps
app = apps.get_app_config('core')

mermaid = ["erDiagram"]

for model_name, model in app.models.items():
    mermaid.append(f"    {model_name} {{")
    for field in model._meta.get_fields():
        if field.is_relation and (field.many_to_one or field.one_to_one) and hasattr(field, 'target_field'):
            pass # Handle relations separately
        if not field.is_relation or getattr(field, 'primary_key', False):
            field_type = field.__class__.__name__
            mermaid.append(f"        {field_type} {field.name}")
    mermaid.append("    }")

    # Add relationships
    for field in model._meta.get_fields():
        if field.is_relation and field.many_to_one and hasattr(field, 'target_field'):
            target_model = field.related_model._meta.model_name
            mermaid.append(f"    {target_model} ||--o{{ {model_name} : \"{field.name}\"")
        elif field.is_relation and field.one_to_one and hasattr(field, 'target_field'):
            target_model = field.related_model._meta.model_name
            mermaid.append(f"    {target_model} ||--|| {model_name} : \"{field.name}\"")

with open('er_diagram.mmd', 'w') as f:
    f.write("\n".join(mermaid))
print("Mermaid diagram generated at er_diagram.mmd")
