from django.contrib import admin
from .models import Session, Shot

@admin.register(Session)
class SessionAdmin(admin.ModelAdmin):
    list_display = ['name', 'created_at', 'shot_count']
    list_filter = ['created_at']
    search_fields = ['name']
    
    def shot_count(self, obj):
        return obj.shots.count()

@admin.register(Shot)
class ShotAdmin(admin.ModelAdmin):
    list_display = ['id', 'session', 'timestamp', 'ball_speed', 'club_head_speed', 'confidence_score', 'processed']
    list_filter = ['session', 'processed', 'timestamp']
    readonly_fields = ['timestamp', 'image']
    fieldsets = (
        ('Basic Info', {
            'fields': ('session', 'timestamp', 'image', 'processed', 'confidence_score', 'processing_errors')
        }),
        ('Basic Data', {
            'fields': ('ball_speed', 'club_head_speed', 'carry_distance', 'total_distance')
        }),
        ('Advanced Data', {
            'fields': ('smash_factor', 'launch_angle', 'spin_rate', 'side_spin', 'angle_of_attack', 
                      'club_path', 'face_angle', 'dynamic_loft', 'impact_height', 'impact_toe',
                      'ball_height', 'descent_angle', 'apex_height', 'hang_time', 'offline')
        }),
    )
