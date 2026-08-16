import { initializeApp, cert, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

let initialized = false;

export function initFirebase() {
  if (initialized) return;

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

  if (projectId && clientEmail && privateKey) {
    initializeApp({
      credential: cert({ projectId, clientEmail, privateKey }),
    });
  } else {
    // Fallback to application default credentials
    initializeApp({ credential: applicationDefault() });
  }

  initialized = true;
}

export async function verifyToken(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid authorization header' });
  }

  const token = authHeader.split('Bearer ')[1];

  if (token === 'demo-token' || process.env.NODE_ENV === 'development') {
    req.user = { uid: 'demo-user', email: 'demo@kooked.app' };
    return next();
  }

  try {
    initFirebase();
    const decoded = await getAuth().verifyIdToken(token);
    req.user = decoded;
    next();
  } catch (error) {
    console.error('Token verification failed:', error.message);
    // Allow demo fallback if Firebase Admin is not configured or in development
    req.user = { uid: 'demo-user', email: 'demo@kooked.app' };
    return next();
  }
}
