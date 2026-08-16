export function buildVisionPrompt() {
  return `Analyze this image of food items or groceries. Identify EVERY food item visible.

For each item, return a JSON array with this exact structure:
[
  {
    "name": "item name",
    "quantity": estimated number (as a number, e.g. 3),
    "unit": "pcs" | "g" | "kg" | "ml" | "L" | "cups" | "bunch" | "pack",
    "category": "Produce" | "Dairy" | "Meat & Seafood" | "Grains & Bread" | "Canned & Jarred" | "Spices & Seasonings" | "Oils & Condiments" | "Frozen" | "Beverages" | "Snacks" | "Leftovers" | "Other",
    "type": "Raw" | "Packaged" | "Leftover"
  }
]

Rules:
- Be as accurate as possible with quantities based on visual estimation
- Use "pcs" for countable items, "g"/"kg" for weight, "ml"/"L" for liquids
- If an item is in packaging, mark type as "Packaged"
- If you cannot determine quantity, use a reasonable default (1 for countable, 500 for g, 1 for L)
- Return ONLY the JSON array, no other text`;
}

export function buildOcrPrompt() {
  return `Analyze this grocery receipt/bill image. Extract ALL food/grocery items purchased.

For each item, return a JSON object with this structure:
{
  "items": [
    {
      "name": "item name",
      "quantity": quantity as a number,
      "unit": "pcs" | "g" | "kg" | "ml" | "L" | "pack"
    }
  ]
}

Rules:
- Extract only food/grocery items, skip non-food items
- If quantity is not shown, default to 1
- Infer unit from item name if possible (e.g., "Milk 1L" → quantity: 1, unit: "L")
- Normalize item names (remove brand names, keep product name)
- Return ONLY the JSON object, no other text`;
}

export function buildChatSystemPrompt(pantryContext) {
  const pantryList = pantryContext
    .map((item) => `- ${item.name}: ${item.quantity} ${item.unit} (${item.category})`)
    .join('\n');

  return `You are KooKed's AI Kitchen Assistant. You help users cook meals using ingredients they already have in their pantry.

Current pantry contents:
${pantryList || '(empty pantry)'}

Rules:
- Only suggest recipes using ingredients the user has or mostly has
- Be concise and helpful
- When suggesting a recipe, list ingredients needed and steps
- If the user is missing ingredients, suggest what they could substitute
- Keep responses under 300 words
- Use a friendly, encouraging tone
- Format recipes with clear ingredient lists and numbered steps`;
}

export function buildRecipeGenerationPrompt(ingredients) {
  const ingredientList = ingredients
    .map((i) => `- ${i.name}: ${i.quantity} ${i.unit}`)
    .join('\n');

  return `Generate a recipe using these available ingredients:
${ingredientList}

Return a JSON object with this exact structure:
{
  "title": "Recipe Name",
  "cuisine": "Indian" | "Italian" | "Mexican" | "Chinese" | "Japanese" | "Thai" | "Mediterranean" | "American" | "French" | "Korean" | "Other",
  "prepTimeMinutes": number,
  "cookTimeMinutes": number,
  "servings": number,
  "difficulty": "Easy" | "Medium" | "Hard",
  "ingredients": [
    { "name": "ingredient", "quantity": number, "unit": "unit" }
  ],
  "steps": ["Step 1 description", "Step 2 description"]
}

Rules:
- Max 8 ingredients, prefer using what's available
- Keep prep + cook time under 45 minutes
- Return ONLY the JSON object, no other text`;
}

export function buildEstimationPrompt(recipe, pantry) {
  return `For the recipe "${recipe.title}" with these ingredients:
${recipe.ingredients.map((i) => `- ${i.name}: ${i.quantity} ${i.unit}`).join('\n')}

Estimate how much of each ingredient is consumed for 1 serving.

Return a JSON object:
{
  "consumptions": [
    { "name": "ingredient name", "quantityConsumed": number, "unit": "unit" }
  ]
}

Rules:
- Estimate reasonable consumption per serving
- Return ONLY the JSON object, no other text`;
}
