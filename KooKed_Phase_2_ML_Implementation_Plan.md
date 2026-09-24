# KooKed — Phase 2 ML Implementation Plan

## Objective

Train and evaluate the first lightweight local food-classification model for KooKed.

The model predicts two independent outputs:
1. Food Category
2. Inventory State

The model must be lightweight enough for eventual on-device/mobile inference.

## Scope

### Included
- Dataset validation
- Data leakage checks
- Text normalization
- TF-IDF experiments
- Logistic Regression training
- Separate category classifier
- Separate inventory-state classifier
- Validation and test evaluation
- Confidence analysis
- Confusion matrices
- Model-size measurement
- CPU inference benchmark
- Model export
- Local inference testing
- Phase 2 report

### Not Included
- Flutter modification
- FastAPI service
- Gemini/LLM integration
- LLM fallback
- Camera recognition
- OCR
- TensorFlow Lite conversion
- Production mobile inference

## Target Architecture

```text
                    Food Text
                       |
                Normalization
                       |
             +---------+---------+
             |                   |
             v                   v
        TF-IDF Vectorizer   TF-IDF Vectorizer
             |                   |
             v                   v
      Category Model       State Model
             |                   |
             v                   v
         Category             State
       + confidence        + confidence
```

Train two independent classifiers. Do not combine category and inventory state into one label.

## KooKed Category Taxonomy

Use the finalized Phase 1 taxonomy. Expected initial categories:

- Produce
- Dairy
- Meat & Seafood
- Grains & Bread
- Canned & Jarred
- Spices & Seasonings
- Oils & Condiments
- Frozen
- Beverages
- Snacks
- Prepared Food
- Other

## Inventory-State Taxonomy

Expected initial values:

- Raw
- Packaged
- Prepared
- Leftover
- Frozen
- Other

Food category and inventory state are separate concepts.

Examples:

```text
Tomato
Category = Produce
State = Raw

Bread
Category = Grains & Bread
State = Packaged

Tomato Rice
Category = Prepared Food
State = Prepared
```

## Dataset Inputs

Use:

```text
ml/data/train/train.csv
ml/data/validation/validation.csv
ml/data/test/test.csv
```

Inspect the actual column names before training.

Also inspect, if available:

```text
ml/data/processed/dataset_statistics.json
ml/data/processed/data_quality_report.json
```

Do not modify source datasets.

## Data Validation

Before training, check:
- Missing/empty text
- Missing labels
- Invalid category/state values
- Duplicate samples
- Conflicting labels

Report training, validation, and test sizes.

Stop and report serious data-quality problems instead of silently changing labels.

## Data Leakage

Normalize text before checking duplicates.

Treat `Tomato`, `tomato`, and `TOMATO` as the same normalized input.

Check exact, normalized, alias, and near-duplicate leakage where practical.

Do not tune on the test set.

## Text Normalization

Implement a reusable normalizer handling:
- lowercase
- leading/trailing whitespace
- repeated whitespace
- safe punctuation normalization

Do not aggressively stem or destroy meaningful food distinctions such as:
- coconut
- coconut milk
- coconut oil

## Model

Initial baseline:

**TF-IDF + Logistic Regression**

Use:
- Python
- pandas
- NumPy
- scikit-learn
- joblib

Do not use LLMs or deep learning in this phase.

## TF-IDF Experiments

Evaluate:
1. Word unigrams: `ngram_range=(1,1)`
2. Word unigrams + bigrams: `ngram_range=(1,2)`
3. Character n-grams if useful for spelling variations, aliases, and Indian transliterations

Record:
- vocabulary size
- number of features
- model size
- validation performance

Prefer the smallest model with strong performance.

## Logistic Regression Experiments

Evaluate a small set of regularization values:

```text
C = 0.1
C = 1
C = 10
```

Use `class_weight="balanced"` only if validation results justify it.

Train separately:
- category model
- inventory-state model

## Model Selection

Use:

```text
TRAIN
  ↓
VALIDATION
  ↓
Select best configuration
  ↓
FINAL TEST
```

Select using a balance of:
- Macro F1
- Weighted F1
- Accuracy
- Model size
- Inference speed

Never select using test performance.

## Final Evaluation

On the untouched test set, calculate for both models:
- Accuracy
- Precision
- Recall
- F1
- Macro F1
- Weighted F1

Generate per-class metrics.

## Confusion Matrices

Generate:

```text
ml/models/evaluation/category_confusion_matrix.png
ml/models/evaluation/state_confusion_matrix.png
```

Pay special attention to confusion among:
- Raw
- Packaged
- Prepared
- Leftover
- Frozen

## Confidence

Use `predict_proba()` where appropriate.

Example:

```text
Input: tomato

Category:
Produce
Confidence: 0.98

Inventory State:
Raw
Confidence: 0.97
```

These are confidence estimates, not guarantees.

## Confidence Threshold

Do not choose a threshold arbitrarily.

Evaluate:

```text
0.50
0.60
0.70
0.80
0.90
0.95
```

Using validation data, measure:
- coverage
- accepted-prediction accuracy
- rejection rate

Recommend a practical threshold for high vs low confidence.

Do not implement the LLM fallback yet.

## Ambiguity Tests

Test:

```text
rice
chicken
bread
milk
curry
dal
beans
```

Analyze whether confidence decreases appropriately for ambiguous inputs.

## Indian Food Evaluation

Create a manually reviewed evaluation list containing:

```text
Tomato Rice
Curd Rice
Sambar
Rasam
Brinjal Curry
Poriyal
Kootu
Biryani
Dosa
Idli
Pongal
Upma
Chapati
Parotta
Paneer Butter Masala
Chicken Curry
```

Save:

```text
ml/models/evaluation/indian_food_evaluation.csv
```

Keep this separate from official test metrics.

## Model Export

Save:

```text
ml/models/
├── category/
│   ├── vectorizer.joblib
│   └── model.joblib
├── inventory_state/
│   ├── vectorizer.joblib
│   └── model.joblib
└── evaluation/
```

Also create:

```text
ml/models/model_metadata.json
```

## Metadata

Include:
- model_version
- dataset_version
- training_date
- algorithm
- vectorizer configuration
- classifier configuration
- training/validation/test counts
- category metrics
- state metrics
- vocabulary size
- model size
- recommended confidence threshold
- Python version
- scikit-learn version
- random seed

## Reproducibility

Create:

```text
ml/scripts/train_model.py
```

Running:

```bash
python scripts/train_model.py
```

must reproduce the final model.

Use a fixed random seed.

Useful supporting scripts:

```text
ml/scripts/
├── train_model.py
├── evaluate_model.py
├── experiment.py
└── test_inference.py
```

## Local Inference

Create:

```text
ml/scripts/test_inference.py
```

Example:

```bash
python scripts/test_inference.py "tomato"
```

Expected output:

```text
Food: tomato
Category: Produce
Confidence: XX%
Inventory State: Raw
Confidence: XX%
```

Also support:

```bash
python scripts/test_inference.py --file examples.txt
```

Save batch results to:

```text
ml/models/evaluation/inference_examples.csv
```

## Model Size

Measure:
- category vectorizer
- category model
- state vectorizer
- state model
- total package size

Report in KB/MB.

## CPU Inference Benchmark

Benchmark at least 100 and 1000 predictions where practical.

Report:
- average inference time
- median inference time
- P95 inference time

## Mobile Considerations

Do not convert to TensorFlow Lite yet.

First establish:
- accuracy
- F1
- confidence behavior
- model size
- CPU inference speed

The mobile deployment format will be selected after Phase 2.

## Limitations

Create:

```text
ml/models/evaluation/limitations.md
```

Document:
- weak classes
- ambiguous foods
- dataset imbalance
- unsupported foods
- language limitations
- Indian food limitations
- packaged product limitations
- raw/prepared ambiguity

## Phase 2 Report

Create:

```text
ml/models/evaluation/PHASE_2_REPORT.md
```

Include:
- dataset sizes
- category metrics
- inventory-state metrics
- best configuration
- model size
- inference speed
- recommended confidence threshold
- Indian food evaluation
- weak classes
- limitations
- recommendation: ready or needs improvement

## Success Checklist

- [ ] Dataset loaded
- [ ] Leakage checked
- [ ] Normalization implemented
- [ ] Category model trained
- [ ] State model trained
- [ ] TF-IDF experiments completed
- [ ] Logistic Regression experiments completed
- [ ] Validation model selection completed
- [ ] Final test evaluation completed
- [ ] Confusion matrices generated
- [ ] Classification reports generated
- [ ] Confidence evaluated
- [ ] Threshold recommended
- [ ] Indian food evaluation completed
- [ ] Model size measured
- [ ] CPU inference measured
- [ ] Models saved
- [ ] Vectorizers saved
- [ ] Metadata saved
- [ ] Reproducible training script created
- [ ] Local inference script created
- [ ] Phase 2 report created
- [ ] No Flutter integration
- [ ] No LLM integration
- [ ] No camera/OCR implementation

## Final Future Architecture

```text
User Input
    ↓
Local Normalization
    ↓
Local ML Model
    ↓
Confidence
   / HIGH LOW
 |    |
 v    v
Accept Backend
       ↓
   LLM Fallback
       ↓
User Confirmation
```

Only the local ML portion belongs to Phase 2.

## Final Deliverables

Report:
1. Category accuracy
2. Category Macro F1
3. Inventory-state accuracy
4. Inventory-state Macro F1
5. Recommended confidence threshold
6. Total model size
7. Average inference time
8. Training sample count
9. Number of classes
10. Weakest classes
11. Mobile-readiness recommendation
12. Exact training command

Do not proceed to Phase 3.

The complete pipeline is:

```text
DATASET
   ↓
VALIDATION
   ↓
LEAKAGE CHECK
   ↓
NORMALIZATION
   ↓
TF-IDF EXPERIMENTS
   ↓
LOGISTIC REGRESSION
   ↓
VALIDATION
   ↓
FINAL TEST
   ↓
CONFIDENCE ANALYSIS
   ↓
MODEL EXPORT
   ↓
INFERENCE TEST
   ↓
PERFORMANCE BENCHMARK
   ↓
PHASE 2 REPORT
```
