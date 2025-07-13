from django.db import models
from django.utils import timezone

class Session(models.Model):
    name = models.CharField(max_length=100)
    created_at = models.DateTimeField(default=timezone.now)
    notes = models.TextField(blank=True)
    
    def __str__(self):
        return f"{self.name} - {self.created_at.strftime('%Y-%m-%d %H:%M')}"

class Shot(models.Model):
    session = models.ForeignKey(Session, on_delete=models.CASCADE, related_name='shots')
    timestamp = models.DateTimeField(default=timezone.now)
    image = models.ImageField(upload_to='shots/')
    
    # Full Swing KIT basic data (4 values on OLED)
    ball_speed = models.FloatField(null=True, blank=True)
    club_head_speed = models.FloatField(null=True, blank=True)
    carry_distance = models.FloatField(null=True, blank=True)
    total_distance = models.FloatField(null=True, blank=True)
    
    # Extended iPad data (14-16 values)
    smash_factor = models.FloatField(null=True, blank=True)
    launch_angle = models.FloatField(null=True, blank=True)
    spin_rate = models.FloatField(null=True, blank=True)
    side_spin = models.FloatField(null=True, blank=True)
    angle_of_attack = models.FloatField(null=True, blank=True)
    club_path = models.FloatField(null=True, blank=True)
    face_angle = models.FloatField(null=True, blank=True)
    dynamic_loft = models.FloatField(null=True, blank=True)
    impact_height = models.FloatField(null=True, blank=True)
    impact_toe = models.FloatField(null=True, blank=True)
    ball_height = models.FloatField(null=True, blank=True)
    descent_angle = models.FloatField(null=True, blank=True)
    apex_height = models.FloatField(null=True, blank=True)
    hang_time = models.FloatField(null=True, blank=True)
    offline = models.FloatField(null=True, blank=True)
    
    # Processing metadata
    processed = models.BooleanField(default=False)
    processing_errors = models.TextField(blank=True)
    confidence_score = models.FloatField(null=True, blank=True)
    
    def __str__(self):
        return f"Shot {self.id} - {self.timestamp.strftime('%H:%M:%S')}"
