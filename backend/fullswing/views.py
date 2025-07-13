from rest_framework.decorators import api_view, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone
from .models import Session, Shot
from .ocr_processor import FullSwingOCR
from .serializers import SessionSerializer, ShotSerializer

@api_view(['POST'])
@parser_classes([MultiPartParser, FormParser])
def process_image(request):
    """Process uploaded image and extract shot data"""
    try:
        image_file = request.FILES.get('image')
        session_id = request.data.get('session_id')
        display_type = request.data.get('display_type', 'oled')  # 'oled' or 'ipad'
        
        if not image_file:
            return Response({'error': 'No image provided'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Get or create session
        session = None
        if session_id:
            try:
                session = Session.objects.get(id=session_id)
            except Session.DoesNotExist:
                pass
        
        if not session:
            session = Session.objects.create(name=f"Session {timezone.now().strftime('%Y-%m-%d %H:%M')}")
        
        # Create shot record
        shot = Shot.objects.create(session=session, image=image_file)
        
        # Process image with OCR
        ocr_processor = FullSwingOCR()
        
        try:
            if display_type == 'oled':
                data, raw_text, confidence = ocr_processor.process_oled_display(shot.image.path)
            else:
                data, raw_text, confidence = ocr_processor.process_ipad_display(shot.image.path)
            
            # Update shot with extracted data
            for field, value in data.items():
                if value is not None and hasattr(shot, field):
                    setattr(shot, field, value)
            
            shot.processed = True
            shot.confidence_score = confidence
            shot.save()
            
            return Response({
                'shot_id': shot.id,
                'session_id': session.id,
                'data': data,
                'confidence': confidence,
                'raw_text': raw_text
            })
            
        except Exception as e:
            shot.processing_errors = str(e)
            shot.save()
            return Response({
                'error': f'Processing failed: {str(e)}',
                'shot_id': shot.id
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
            
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET', 'POST'])
def sessions(request):
    """Get all sessions or create new session"""
    if request.method == 'GET':
        sessions = Session.objects.all().order_by('-created_at')
        serializer = SessionSerializer(sessions, many=True)
        return Response(serializer.data)
    
    elif request.method == 'POST':
        serializer = SessionSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET'])
def session_shots(request, session_id):
    """Get all shots for a session"""
    try:
        session = Session.objects.get(id=session_id)
        shots = session.shots.all().order_by('-timestamp')
        serializer = ShotSerializer(shots, many=True)
        return Response(serializer.data)
    except Session.DoesNotExist:
        return Response({'error': 'Session not found'}, status=status.HTTP_404_NOT_FOUND)
