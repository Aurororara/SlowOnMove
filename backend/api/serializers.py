from rest_framework import serializers
from core.models import Member, BodyRecord, BoardRanking, CommunityPost, Favorite, TrainingLog

class MemberSerializer(serializers.ModelSerializer):
    class Meta:
        model = Member
        fields = ['id', 'username', 'email', 'date_joined',]
        read_only_fields = ['id', 'date_joined']

class BodyRecordSerializer(serializers.ModelSerializer):
    class Meta:
        model = BodyRecord
        fields = '__all__'

class BoardRankingSerializer(serializers.ModelSerializer):
    class Meta:
        model = BoardRanking
        fields = '__all__'

class CommunityPostSerializer(serializers.ModelSerializer):
    class Meta:
        model = CommunityPost
        fields = '__all__'

class FavoriteSerializer(serializers.ModelSerializer):
    class Meta:
        model = Favorite
        fields = '__all__'

class TrainingLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = TrainingLog
        fields = '__all__'
