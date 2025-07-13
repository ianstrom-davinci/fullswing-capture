import cv2
import numpy as np
import pytesseract
import re
from typing import Dict, Optional, Tuple
from PIL import Image

class FullSwingOCR:
    def __init__(self):
        # Configure tesseract for better number recognition
        self.config = r'--oem 3 --psm 6 -c tessedit_char_whitelist=0123456789.-+mph°ft/s'
    
    def preprocess_image(self, image_path: str) -> np.ndarray:
        """Preprocess image for better OCR accuracy"""
        # Read image
        img = cv2.imread(image_path)
        
        # Convert to grayscale
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Apply bilateral filter to reduce noise while keeping edges sharp
        filtered = cv2.bilateralFilter(gray, 9, 75, 75)
        
        # Apply adaptive threshold
        thresh = cv2.adaptiveThreshold(
            filtered, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2
        )
        
        # Morphological operations to clean up
        kernel = np.ones((2, 2), np.uint8)
        cleaned = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
        
        # Resize for better OCR (if image is too small)
        height, width = cleaned.shape
        if height < 500:
            scale_factor = 500 / height
            new_width = int(width * scale_factor)
            cleaned = cv2.resize(cleaned, (new_width, 500), interpolation=cv2.INTER_CUBIC)
        
        return cleaned
    
    def extract_numbers_from_text(self, text: str) -> list:
        """Extract numeric values from OCR text"""
        numbers = []
        
        # Remove common OCR artifacts and normalize
        text = text.replace('O', '0').replace('o', '0').replace('l', '1').replace('I', '1')
        
        # Find all numeric patterns
        patterns = [
            r'(\d+\.?\d*)\s*mph',
            r'(\d+\.?\d*)\s*ft',
            r'(\d+\.?\d*)\s*°',
            r'(\d+\.?\d*)\s*rpm',
            r'(\d+\.?\d*)\s*/s',
            r'(-?\d+\.?\d*)',  # Any number (including negative)
        ]
        
        for pattern in patterns:
            matches = re.findall(pattern, text, re.IGNORECASE)
            for match in matches:
                try:
                    numbers.append(float(match))
                except ValueError:
                    continue
        
        return numbers
    
    def process_oled_display(self, image_path: str) -> Tuple[Dict[str, Optional[float]], str, float]:
        """Process Full Swing KIT OLED display (4 basic values)"""
        processed_img = self.preprocess_image(image_path)
        
        # Extract text
        text = pytesseract.image_to_string(processed_img, config=self.config)
        numbers = self.extract_numbers_from_text(text)
        
        # Map to expected OLED values (adjust based on your display layout)
        result = {
            'ball_speed': numbers[0] if len(numbers) > 0 else None,
            'club_head_speed': numbers[1] if len(numbers) > 1 else None,
            'carry_distance': numbers[2] if len(numbers) > 2 else None,
            'total_distance': numbers[3] if len(numbers) > 3 else None,
        }
        
        return result, text, len(numbers) / 4.0  # confidence score
    
    def process_ipad_display(self, image_path: str) -> Tuple[Dict[str, Optional[float]], str, float]:
        """Process iPad display with all 14-16 values"""
        processed_img = self.preprocess_image(image_path)
        
        # Extract text
        text = pytesseract.image_to_string(processed_img, config=self.config)
        numbers = self.extract_numbers_from_text(text)
        
        # Map to expected iPad values (you'll need to adjust this based on layout)
        fields = [
            'ball_speed', 'club_head_speed', 'smash_factor', 'carry_distance',
            'total_distance', 'launch_angle', 'spin_rate', 'side_spin',
            'angle_of_attack', 'club_path', 'face_angle', 'dynamic_loft',
            'impact_height', 'impact_toe', 'ball_height', 'descent_angle'
        ]
        
        result = {}
        for i, field in enumerate(fields):
            result[field] = numbers[i] if len(numbers) > i else None
            
        return result, text, min(1.0, len(numbers) / len(fields))
