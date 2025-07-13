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
