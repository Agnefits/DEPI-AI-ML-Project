# ClinicAI — AI-Powered Clinical Intelligence Platform

**ClinicAI** is a state-of-the-art, secure clinical intelligence platform designed to empower radiologists, doctors, and hospital administrators. It streamlines clinical workflows by integrating AI-powered medical scan classification (focusing on chest X-rays), real-time case management, automated clinical reporting, and organization-wide analytics.

---

## 🎓 Graduation Project Details

This project is submitted as the final Graduation Project for the **Digital Egypt Pioneers Initiative (DEPI)**.

*   **Track:** Microsoft Machine Learning Track
*   **Group Code:** `AST4_AIS2_S1`
*   **Under the Auspices of:** EYouth
*   **Project Supervisor:** Eng. Mahmoud Talaat

---

## 👥 Team Members & Roles

| # | Name | ID | Email | Phone | Core Contributions |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | **Abdallah Salah Abdallah** | `21071891` | abdallah1662005@gmail.com | 01024040895 | **Leader + Fullstack Developer + Computer Vision Engineer** |
| **2** | **Ahmed Adel Rasmy** | `21094136` | ahmed.adel201864@gmail.com | 01098379012 | **NLP Engineer + Data Analyst** |
| **3** | **Morad Ahmed Helmy** | `21072609` | morad3ayada@gmail.com | 01062239634 | **Mobile App Developer + NLP Engineer** |
| **4** | **Shahd Mohamed Abdelaal** | `21036608` | shahdmoh129@gmail.com | 01068826210 | **Computer Vision Engineer** |
| **5** | **Youssef Ahmed Kamal** | `21078737` | youssefelsharawy491@gmail.com | 01110178780 | **Computer Vision Engineer + Data Analyst** |

---

## 🛠️ Technology Stack

ClinicAI utilizes a modern, distributed architecture combining high-performance backend frameworks, interactive frontend engines, and state-of-the-art deep learning architectures.

### 1. Web Portal & Backend Services
*   **Framework:** ASP.NET Core (targets .NET 9.0)
*   **Database ORM:** Entity Framework Core (SQL Server)
*   **Authentication & Security:** ASP.NET Identity, JWT Bearer Token validation, Role-Based Access Control (RBAC)
*   **UI/UX Design:** HTML5, CSS3 (Modern Glassmorphism & Custom Light/Dark themes), JavaScript (ES6+), FontAwesome 6, Bootstrap

### 2. AI Model & Inference Engine
*   **Frameworks:** PyTorch, FastAPI (Python 3.10+)
*   **Model Backbone:** ConvNeXt-Base (trained on NIH Chest X-ray dataset)
*   **Data Augmentation:** Albumentations
*   **API Security:** Custom API Key Header security model (`X-API-Key`)
*   **Classes Detected:** Atelectasis, Cardiomegaly, Effusion, Infiltration, Mass, Nodule, Pneumonia, Pneumothorax, Consolidation, Edema, Emphysema, Fibrosis, Pleural Thickening, Hernia.

### 3. Mobile Application
*   Provides clinical queue coordination, AI diagnosis review, and real-time status updates for doctors and radiologists on-the-go.

---

## 🌟 Key Features

*   **AI Scan Classification:** Upload an X-ray scan and receive predictions for 14 pathological conditions in under 2 seconds.
*   **Role-Based Dashboards:** Tailored user interfaces for Super Admins, Admins, Radiologists, Doctors, and Hospital Chiefs.
*   **Auto-mapping Diagnostic Standards:** AI findings automatically map to ICD-10 medical coding standards.
*   **Automated Reporting:** Generates downloadable reports with physician signatures and digital audit trails.
*   **Live Analytics & Metrics:** Interactive charts monitoring cases, throughput, and model performance.
*   **Flexible Fallback Mode:** Robust client-side mock data fallback system ensuring continuity of app functionality even when the Python model server is offline.

---

## 🚀 Getting Started

### Prerequisites
*   [.NET 9.0 SDK](https://dotnet.microsoft.com/download/dotnet/9.0)
*   [SQL Server / LocalDB](https://www.microsoft.com/en-us/sql-server/sql-server-downloads)
*   [Python 3.10+](https://www.python.org/downloads/)

### 1. Running the AI Model API
1. Navigate to the model directory:
   ```bash
   cd "ClinicAI Model APIs"
   ```
2. Create and activate a virtual environment:
   ```bash
   python -m venv venv
   # On Windows:
   .\venv\Scripts\activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Start the FastAPI server:
   ```bash
   uvicorn Main:app --reload --host 127.0.0.1 --port 8000
   ```

### 2. Running the Web Application
1. Navigate to the web folder:
   ```bash
   cd Web/ClinicAI
   ```
2. Restore package dependencies and compile:
   ```bash
   dotnet build
   ```
3. Run the development server:
   ```bash
   dotnet run
   ```
4. Access the web portal locally at: `https://localhost:7198` or `http://localhost:5242`.