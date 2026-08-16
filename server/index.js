import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import geminiRoutes from './routes/gemini.js';
import healthRoutes from './routes/health.js';
import { apiLimiter } from './middleware/rateLimit.js';

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors({ origin: true }));
app.use(express.json({ limit: '10mb' }));
app.use('/api', apiLimiter);

app.use('/api/gemini', geminiRoutes);
app.use('/api/health', healthRoutes);

app.listen(PORT, () => {
  console.log(`KooKed API running on port ${PORT}`);
});
