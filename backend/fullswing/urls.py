from django.urls import path
from . import views

urlpatterns = [
    path('process-image/', views.process_image, name='process_image'),
    path('sessions/', views.sessions, name='sessions'),
    path('sessions/<int:session_id>/shots/', views.session_shots, name='session_shots'),
]
