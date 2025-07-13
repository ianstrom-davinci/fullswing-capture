from rest_framework import serializers
from .models import Session, Shot

class ShotSerializer(serializers.ModelSerializer):
    class Meta:
        model = Shot
        fields = '__all__'

class SessionSerializer(serializers.ModelSerializer):
    shot_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Session
        fields = ['id', 'name', 'created_at', 'notes', 'shot_count']
    
    def get_shot_count(self, obj):
        return obj.shots.count()
