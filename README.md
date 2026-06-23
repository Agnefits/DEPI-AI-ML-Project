# Medical Image Diagnosis Support & Clinical NLP Project

> 📋 **[→ View the Full A-to-Z Implementation Plan with Architecture Diagrams](docs/FULL_PLAN.md)**

This project implements an intelligent, AI-powered healthcare decision-support system. It contains two primary pipelines designed to assist healthcare professionals in diagnosing patient conditions and automating clinical documentation:
1.  **Clinical Note NLP Pipeline**: Extracts clinical entities and classifies notes to ICD-10 medical codes.
2.  **Medical Image Diagnosis Support (Chest X-ray)**: Detects lung and cardiology abnormalities from chest X-ray images.

---

## 📂 Repository Directory Structure

*   **[models/clinical_nlp_workspace.py](file:///c:/DEPI-AI-ML-Project/models/clinical_nlp_workspace.py)**:
    *   *What it is*: Main interactive model playground.
    *   *What it does*: Implements the neural network architectures (`BiLSTM_CRF_NER` and `CNNDiagnosisClassifier`) and runs pipeline mock-runs for quick validation.
*   **[plan.md](file:///c:/DEPI-AI-ML-Project/plan.md)**: Contains literature reviews, model comparisons, and PubMed citations.
*   **[Web/](file:///c:/DEPI-AI-ML-Project/Web/)**: Implements preprocessing functions, embedding models, test cases, and the interactive Gradio web application (`Web/app.py`).
*   **[specs/](file:///c:/DEPI-AI-ML-Project/specs/)**: Contains Spec-Driven Development files (specifications, plans, checkpoints).

---

## 📝 1. Clinical NLP (Task 1 & Task 2)

### 📌 AI Problem Definition & Scope
*   **Named Entity Recognition (NER)**: Extract medical entities (diseases, drugs, symptoms, lab values) from clinical notes.
*   **Text Classification**: Map notes to ICD-10-CM diagnostic categories or department specialties.
*   **Summarization**: Condense long discharge notes into key findings (chief complaints, findings, plans).

### 🤖 Model Recommendations
*   **Primary (NER)**: **BioBERT + BiLSTM + CRF** (SOTA F1: ~87-94% on BC5CDR, PubMed pre-trained).
*   **Secondary (ICD-10 Classification)**: **CNN + Word2Vec / GloVe** (Fast, interpretable, up to 98% departmental F1).

---

## 🖼️ 2. Medical Image Diagnosis Support (Chest X-ray)

### 📌 Problem Definition (تعريف المشكلة)
Analyzing chest X-rays manually is time-consuming and relies heavily on radiologist availability and expertise. This system integrates deep learning to automatically detect common abnormalities and generate clinical observations.

### 🩺 Targeted Diseases & Expected Model Accuracies

| Targeted Disease | Medical Description (الوصف الطبي) | Model Accuracy | Doctor Difficulty |
| :--- | :--- | :--- | :--- |
| **Pneumonia (الالتهاب الرئوي)** | Infection in the lung's air sacs | 88–94% | 80% (Moderate) |
| **Pleural Effusion (الانصباب الجنبي)** | Fluid accumulation around the lungs | 90–95% | 85% (Easy/Moderate) |
| **Atelectasis (الانخماص الرئوي)** | Partial or complete collapse of a lung | 82–90% | 70% (Difficult) |
| **Cardiomegaly (تضخم القلب)** | Abnormal enlargement of the heart | 92–96% | 90% (Easy) |
| **Lung Nodule / Mass (كتلة/عقدة رئوية)**| A small growth or mass in the lung tissue | 80–88% | 65% (Very Difficult) |
| **Fibrosis (تليف الرئة)** | Scarring of the lung tissue | 78–85% | 60% (Very Difficult) |

---

## 🛠️ 3. The 15-Step AI Implementation Workflow

Both pipelines follow a rigorous 15-step AI engineering lifecycle:

1.  **Define the AI Problem**: Formulate the medical target (e.g. X-ray abnormality detection or NER parsing).
2.  **Research Related Work**: Conduct literature reviews onPubMed (e.g. BioBERT, ResNet, DenseNet, EfficientNet).
3.  **Collect Datasets**: Gather medical datasets (MIMIC-III, MIMIC-IV, ChestX-ray14, BC5CDR).
4.  **Explore the Dataset**: Perform Exploratory Data Analysis (EDA) on image distributions/label frequencies.
5.  **Preprocess Data**: Clean/tokenize clinical text and resize/normalize input images.
6.  **Data Augmentation**: Apply rotations, flips, and color jitters to combat overfitting on images.
7.  **Choose the Model**: Select backbone architectures (BioBERT + BiLSTM for NLP; DenseNet/ResNet for X-rays).
8.  **Train the Model**: Run training loops using PyTorch / TensorFlow.
9.  **Evaluate the Model**: Calculate Accuracy, F1-Score, Precision, and Recall.
10. **Improve the Model**: Tune hyper-parameters and implement regularization.
11. **Save the Trained Model**: Serialise and export weights/checkpoints.
12. **Create AI API**: Wrap the model in a FastAPI or Flask web service.
13. **Integrate AI with Backend**: Link predictions to the mobile app and case-management database.
14. **Test the AI System**: Run inference tests on unseen validation samples.
15. **Document the AI Module**: Document datasets, architectures, and evaluation results.

---

## 🚀 Quickstart

1.  **Install requirements**:
    ```bash
    pip install -r Web/requirements.txt
    ```
2.  **Run the NLP workspace playground**:
    ```bash
    uv run models/clinical_nlp_workspace.py
    ```
3.  **Run the Gradio web UI locally**:
    ```bash
    python Web/app.py
    ```