import { GoogleGenerativeAI } from '@google/generative-ai';
import { Router } from 'express';
import { verifyToken } from '../middleware/auth.js';
import { geminiLimiter } from '../middleware/rateLimit.js';
import {
  buildVisionPrompt,
  buildOcrPrompt,
  buildChatSystemPrompt,
  buildRecipeGenerationPrompt,
  buildEstimationPrompt,
  buildClassificationPrompt,
} from '../utils/prompts.js';

const router = Router();
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

function parseJsonResponse(text) {
  const cleaned = text.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
  return JSON.parse(cleaned);
}

// POST /api/gemini/vision — Camera scan food detection
router.post('/vision', verifyToken, geminiLimiter, async (req, res) => {
  try {
    const { image, prompt } = req.body;
    if (!image) return res.status(400).json({ error: 'Image data required' });

    const model = genAI.getGenerativeModel({ model: 'gemini-3.5-flash' });
    const result = await model.generateContent([
      prompt || buildVisionPrompt(),
      {
        inlineData: {
          mimeType: 'image/jpeg',
          data: image,
        },
      },
    ]);

    const response = result.response.text();
    const items = parseJsonResponse(response);

    res.json({ items: Array.isArray(items) ? items : items.items || [] });
  } catch (error) {
    console.error('Vision error:', error.message);
    res.status(500).json({ error: 'Failed to analyze image' });
  }
});

// POST /api/gemini/ocr — Bill/receipt OCR
router.post('/ocr', verifyToken, geminiLimiter, async (req, res) => {
  try {
    const { image } = req.body;
    if (!image) return res.status(400).json({ error: 'Image data required' });

    const model = genAI.getGenerativeModel({ model: 'gemini-3.5-flash' });
    const result = await model.generateContent([
      buildOcrPrompt(),
      {
        inlineData: {
          mimeType: 'image/jpeg',
          data: image,
        },
      },
    ]);

    const response = result.response.text();
    const parsed = parseJsonResponse(response);

    res.json({ items: parsed.items || parsed });
  } catch (error) {
    console.error('OCR error:', error.message);
    res.status(500).json({ error: 'Failed to read receipt' });
  }
});

// POST /api/gemini/chat — Kitchen assistant chat
router.post('/chat', verifyToken, geminiLimiter, async (req, res) => {
  try {
    const { message, pantry = [], chefMode = false } = req.body;
    if (!message) return res.status(400).json({ error: 'Message required' });

    const systemPrompt = buildChatSystemPrompt(pantry);
    const chefSuffix = chefMode
      ? '\n\nYou are in Chef Mode. Provide step-by-step cooking guidance with clear numbered instructions.'
      : '';

    const model = genAI.getGenerativeModel({
      model: 'gemini-3.5-flash',
      systemInstruction: systemPrompt + chefSuffix,
    });

    const result = await model.generateContent(message);
    const reply = result.response.text();

    res.json({ reply });
  } catch (error) {
    console.error('Chat error:', error.message);

    // Fallback response when API key quota is exceeded (429) or offline
    if (error.message?.includes('429') || error.message?.includes('quota')) {
      const fallbackReply = chefMode
        ? `Here are general cooking steps for your request:\n1. Prepare your ingredients from your pantry.\n2. Heat your cooking pan/pot on medium heat.\n3. Cook ingredients thoroughly until done.\n4. Season to taste and serve hot!`
        : `I'm currently operating in offline backup mode (API quota limit reached). You can still ask me about your pantry items or check out the Recipes tab!`;
      return res.json({ reply: fallbackReply });
    }

    res.status(500).json({ error: 'Failed to get response' });
  }
});

// POST /api/gemini/recipe — Generate recipe from ingredients
router.post('/recipe', verifyToken, geminiLimiter, async (req, res) => {
  try {
    const { ingredients = [] } = req.body;
    if (!ingredients.length) {
      return res.status(400).json({ error: 'Ingredients required' });
    }

    const model = genAI.getGenerativeModel({ model: 'gemini-3.5-flash' });
    const result = await model.generateContent(buildRecipeGenerationPrompt(ingredients));
    const response = result.response.text();
    const recipe = parseJsonResponse(response);

    res.json(recipe);
  } catch (error) {
    console.error('Recipe gen error:', error.message);
    res.status(500).json({ error: 'Failed to generate recipe' });
  }
});

// POST /api/gemini/estimate — Estimate ingredient consumption
router.post('/estimate', verifyToken, geminiLimiter, async (req, res) => {
  try {
    const { recipe, pantry = [] } = req.body;
    if (!recipe) return res.status(400).json({ error: 'Recipe required' });

    const model = genAI.getGenerativeModel({ model: 'gemini-3.5-flash' });
    const result = await model.generateContent(buildEstimationPrompt(recipe, pantry));
    const response = result.response.text();
    const estimate = parseJsonResponse(response);

    res.json(estimate);
  } catch (error) {
    console.error('Estimation error:', error.message);
    // Fallback if AI call fails or quota exceeded
    if (req.body?.recipe?.ingredients) {
      const consumptions = req.body.recipe.ingredients.map((ing) => ({
        name: ing.name,
        quantityConsumed: ing.quantity || 1,
        unit: ing.unit || 'pcs',
      }));
      return res.json({ consumptions });
    }
    res.status(500).json({ error: 'Failed to estimate consumption' });
  }
});

// POST /api/gemini/classify — Classify unknown food item
router.post('/classify', verifyToken, geminiLimiter, async (req, res) => {
  try {
    const { name } = req.body;
    if (!name) return res.status(400).json({ error: 'Name required' });

    const model = genAI.getGenerativeModel({ model: 'gemini-3.5-flash' });
    const result = await model.generateContent(buildClassificationPrompt(name));
    const response = result.response.text();
    const classification = parseJsonResponse(response);

    res.json(classification);
  } catch (error) {
    console.error('Classification error:', error.message);
    res.status(500).json({ error: 'Failed to classify food item' });
  }
});

export default router;
