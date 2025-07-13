#!/bin/bash

echo "🔍 Debugging frontend structure..."

# Check current directory structure
echo "Current directory:"
pwd

echo "Contents of frontend/src:"
ls -la src/

echo "Contents of all files in src:"
find src/ -type f -exec echo "File: {}" \; -exec head -5 {} \; -exec echo "---" \;

# Remove any problematic files and recreate everything fresh
echo "🧹 Cleaning and recreating frontend files..."

rm -rf src/*

# Create all required directories
mkdir -p src/components src/hooks src/services

# Create the complete React app files
echo "📄 Creating React app files..."

# Create types.ts
cat > src/types.ts << 'EOF'
export interface Shot {
  id: number;
  timestamp: string;
  image: string;
  ball_speed?: number;
  club_head_speed?: number;
  carry_distance?: number;
  total_distance?: number;
  smash_factor?: number;
  launch_angle?: number;
  spin_rate?: number;
  side_spin?: number;
  angle_of_attack?: number;
  club_path?: number;
  face_angle?: number;
  dynamic_loft?: number;
  impact_height?: number;
  impact_toe?: number;
  ball_height?: number;
  descent_angle?: number;
  apex_height?: number;
  hang_time?: number;
  offline?: number;
  processed: boolean;
  confidence_score?: number;
  processing_errors?: string;
}

export interface Session {
  id: number;
  name: string;
  created_at: string;
  notes: string;
  shot_count: number;
}

export interface CaptureSettings {
  interval: number;
  displayType: 'oled' | 'ipad';
  autoCapture: boolean;
}
EOF

# Create useCamera hook
cat > src/hooks/useCamera.ts << 'EOF'
import { useRef, useState, useCallback } from 'react';

export const useCamera = () => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [isStreaming, setIsStreaming] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const startCamera = useCallback(async () => {
    try {
      setError(null);
      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: 'environment',
          width: { ideal: 1920 },
          height: { ideal: 1080 }
        }
      });
      
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        setIsStreaming(true);
      }
    } catch (err) {
      setError('Failed to access camera. Please ensure camera permissions are granted.');
      console.error('Camera error:', err);
    }
  }, []);

  const stopCamera = useCallback(() => {
    if (videoRef.current?.srcObject) {
      const stream = videoRef.current.srcObject as MediaStream;
      stream.getTracks().forEach(track => track.stop());
      videoRef.current.srcObject = null;
      setIsStreaming(false);
    }
  }, []);

  const capturePhoto = useCallback((): Promise<Blob | null> => {
    return new Promise((resolve) => {
      if (!videoRef.current || !canvasRef.current) {
        resolve(null);
        return;
      }

      const video = videoRef.current;
      const canvas = canvasRef.current;
      const ctx = canvas.getContext('2d');

      if (!ctx) {
        resolve(null);
        return;
      }

      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      ctx.drawImage(video, 0, 0);

      canvas.toBlob(resolve, 'image/jpeg', 0.9);
    });
  }, []);

  return {
    videoRef,
    canvasRef,
    isStreaming,
    error,
    startCamera,
    stopCamera,
    capturePhoto
  };
};
EOF

# Create API service
cat > src/services/api.ts << 'EOF'
import { Session, Shot } from '../types';

const API_BASE = '/api';

export const api = {
  async uploadImage(imageBlob: Blob, sessionId?: number, displayType: string = 'oled') {
    const formData = new FormData();
    formData.append('image', imageBlob, 'capture.jpg');
    if (sessionId) formData.append('session_id', sessionId.toString());
    formData.append('display_type', displayType);

    const response = await fetch(`${API_BASE}/process-image/`, {
      method: 'POST',
      body: formData,
    });

    if (!response.ok) {
      throw new Error(`Upload failed: ${response.statusText}`);
    }

    return response.json();
  },

  async getSessions(): Promise<Session[]> {
    const response = await fetch(`${API_BASE}/sessions/`);
    if (!response.ok) throw new Error('Failed to fetch sessions');
    return response.json();
  },

  async createSession(name: string, notes?: string): Promise<Session> {
    const response = await fetch(`${API_BASE}/sessions/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, notes }),
    });
    if (!response.ok) throw new Error('Failed to create session');
    return response.json();
  },

  async getSessionShots(sessionId: number): Promise<Shot[]> {
    const response = await fetch(`${API_BASE}/sessions/${sessionId}/shots/`);
    if (!response.ok) throw new Error('Failed to fetch shots');
    return response.json();
  }
};
EOF

# Create App.tsx
cat > src/App.tsx << 'EOF'
import React, { useState, useEffect } from 'react';
import { api } from './services/api';
import { Session, Shot, CaptureSettings } from './types';
import { useCamera } from './hooks/useCamera';

function App() {
  const { videoRef, canvasRef, isStreaming, error: cameraError, startCamera, stopCamera, capturePhoto } = useCamera();
  const [settings, setSettings] = useState<CaptureSettings>({
    interval: 3,
    displayType: 'oled',
    autoCapture: false
  });
  
  const [sessions, setSessions] = useState<Session[]>([]);
  const [currentSession, setCurrentSession] = useState<Session | undefined>();
  const [recentShots, setRecentShots] = useState<Shot[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [isCapturing, setIsCapturing] = useState(false);

  useEffect(() => {
    loadSessions();
  }, []);

  useEffect(() => {
    if (cameraError) {
      setError(cameraError);
    }
  }, [cameraError]);

  const loadSessions = async () => {
    try {
      const sessionsData = await api.getSessions();
      setSessions(sessionsData);
      if (sessionsData.length > 0 && !currentSession) {
        setCurrentSession(sessionsData[0]);
      }
    } catch (err) {
      setError('Failed to load sessions');
    }
  };

  const createNewSession = async () => {
    try {
      setLoading(true);
      const sessionName = `Session ${new Date().toLocaleDateString()} ${new Date().toLocaleTimeString()}`;
      const newSession = await api.createSession(sessionName);
      setSessions(prev => [newSession, ...prev]);
      setCurrentSession(newSession);
      setRecentShots([]);
    } catch (err) {
      setError('Failed to create session');
    } finally {
      setLoading(false);
    }
  };

  const handleSingleCapture = async () => {
    if (!isStreaming) return;
    
    setIsCapturing(true);
    try {
      const imageBlob = await capturePhoto();
      if (imageBlob) {
        const result = await api.uploadImage(
          imageBlob, 
          currentSession?.id, 
          settings.displayType
        );
        
        if (currentSession) {
          loadSessionShots(currentSession.id);
        }
        
        setError(null);
      }
    } catch (err) {
      setError(`Capture failed: ${err instanceof Error ? err.message : 'Unknown error'}`);
    } finally {
      setIsCapturing(false);
    }
  };

  const loadSessionShots = async (sessionId: number) => {
    try {
      const shots = await api.getSessionShots(sessionId);
      setRecentShots(shots.slice(0, 5));
    } catch (err) {
      setError('Failed to load shots');
    }
  };

  useEffect(() => {
    if (currentSession) {
      loadSessionShots(currentSession.id);
    }
  }, [currentSession]);

  return (
    <div className="min-h-screen bg-gray-100">
      <div className="container mx-auto px-4 py-8">
        <h1 className="text-3xl font-bold text-center mb-8">
          Full Swing Data Capture
        </h1>
        
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded mb-6">
            {error}
            <button 
              onClick={() => setError(null)}
              className="float-right text-red-500 hover:text-red-700"
            >
              ×
            </button>
          </div>
        )}
        
        <div className="space-y-8">
          {/* Camera Section */}
          <div className="relative w-full max-w-2xl mx-auto">
            <div className="relative bg-black rounded-lg overflow-hidden">
              <video
                ref={videoRef}
                autoPlay
                playsInline
                muted
                className="w-full h-auto max-h-96 object-cover"
              />
              <canvas ref={canvasRef} className="hidden" />
              
              {isCapturing && (
                <div className="absolute top-4 right-4 bg-red-500 text-white px-3 py-1 rounded-full text-sm">
                  Recording...
                </div>
              )}
            </div>
            
            <div className="mt-4 space-y-3">
              <div className="flex flex-wrap gap-3 justify-center">
                {!isStreaming ? (
                  <button
                    onClick={startCamera}
                    className="bg-blue-500 hover:bg-blue-600 text-white px-6 py-3 rounded-lg text-lg font-semibold"
                  >
                    Start Camera
                  </button>
                ) : (
                  <>
                    <button
                      onClick={handleSingleCapture}
                      disabled={isCapturing}
                      className="bg-green-500 hover:bg-green-600 disabled:bg-gray-400 text-white px-6 py-3 rounded-lg text-lg font-semibold"
                    >
                      Capture Shot
                    </button>
                    
                    <button
                      onClick={stopCamera}
                      className="bg-gray-500 hover:bg-gray-600 text-white px-4 py-3 rounded-lg font-semibold"
                    >
                      Stop Camera
                    </button>
                  </>
                )}
              </div>
            </div>
          </div>
          
          {/* Settings and Session Management */}
          <div className="grid md:grid-cols-2 gap-6 max-w-4xl mx-auto">
            {/* Settings */}
            <div className="bg-white rounded-lg shadow-md p-6">
              <h3 className="text-lg font-semibold mb-4">Settings</h3>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Display Type
                </label>
                <select
                  value={settings.displayType}
                  onChange={(e) => setSettings({
                    ...settings,
                    displayType: e.target.value as 'oled' | 'ipad'
                  })}
                  className="w-full p-2 border border-gray-300 rounded-md"
                >
                  <option value="oled">Full Swing KIT OLED (4 values)</option>
                  <option value="ipad">iPad Display (14-16 values)</option>
                </select>
              </div>
            </div>
            
            {/* Session Management */}
            <div className="bg-white rounded-lg shadow-md p-6">
              <h3 className="text-lg font-semibold mb-4">Session</h3>
              <div className="space-y-4">
                <button
                  onClick={createNewSession}
                  disabled={loading}
                  className="w-full bg-blue-500 hover:bg-blue-600 disabled:bg-gray-400 text-white py-2 px-4 rounded"
                >
                  {loading ? 'Creating...' : 'New Session'}
                </button>
                
                <select
                  value={currentSession?.id || ''}
                  onChange={(e) => {
                    const sessionId = parseInt(e.target.value);
                    const session = sessions.find(s => s.id === sessionId);
                    setCurrentSession(session);
                  }}
                  className="w-full p-2 border border-gray-300 rounded"
                >
                  <option value="">Select Session</option>
                  {sessions.map(session => (
                    <option key={session.id} value={session.id}>
                      {session.name} ({session.shot_count} shots)
                    </option>
                  ))}
                </select>
                
                {currentSession && (
                  <div className="text-sm text-gray-600">
                    <div>Current: {currentSession.name}</div>
                  </div>
                )}
              </div>
            </div>
          </div>
          
          {/* Recent Shots */}
          <div className="max-w-4xl mx-auto">
            <h3 className="text-lg font-semibold mb-4">Recent Shots</h3>
            {recentShots.length === 0 ? (
              <div className="text-gray-500 text-center py-8 bg-white rounded-lg">
                No shots captured yet
              </div>
            ) : (
              <div className="grid gap-4">
                {recentShots.map(shot => (
                  <div key={shot.id} className="bg-white rounded-lg shadow-md p-6">
                    <div className="flex justify-between items-start mb-4">
                      <h4 className="text-lg font-semibold">Shot #{shot.id}</h4>
                      <div className="text-sm text-gray-500">
                        {new Date(shot.timestamp).toLocaleTimeString()}
                      </div>
                    </div>
                    
                    {shot.confidence_score && (
                      <div className="mb-4">
                        <div className="text-sm text-gray-600">
                          Confidence: {(shot.confidence_score * 100).toFixed(1)}%
                        </div>
                        <div className="w-full bg-gray-200 rounded-full h-2">
                          <div
                            className="bg-blue-600 h-2 rounded-full"
                            style={{ width: `${shot.confidence_score * 100}%` }}
                          />
                        </div>
                      </div>
                    )}
                    
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                      {[
                        { key: 'ball_speed', label: 'Ball Speed', unit: 'mph' },
                        { key: 'club_head_speed', label: 'Club Speed', unit: 'mph' },
                        { key: 'carry_distance', label: 'Carry', unit: 'yds' },
                        { key: 'total_distance', label: 'Total', unit: 'yds' },
                      ].map(field => (
                        <div key={field.key} className="bg-gray-50 p-3 rounded">
                          <div className="text-sm text-gray-600">{field.label}</div>
                          <div className="text-xl font-bold">
                            {shot[field.key as keyof Shot] ? 
                              `${shot[field.key as keyof Shot]}${field.unit}` : 
                              '---'
                            }
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;
EOF

# Create index.tsx
cat > src/index.tsx << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

# Create index.css
cat > src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
EOF

echo "✅ All frontend files recreated"
echo ""
echo "Files created:"
ls -la src/
echo ""
echo "Now try building again:"
echo "docker build -t fullswing-frontend:latest ."
