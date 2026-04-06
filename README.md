# 📦 Davao MSME Hub

A Flutter-based mobile application designed to streamline operations and provide a centralized dashboard for local MSMEs. This project focuses on a robust authentication system and seamless data integration.

---

## 🚀 Getting Started (Migration Guide)

Follow these steps to set up the project on a new development machine.

### 1. Clone the Repository
Open your terminal, navigate to your desired development directory, and run:
```bash
git clone [https://github.com/jcvelos/davao_msme_hub.git](https://github.com/jcvelos/davao_msme_hub.git)
cd davao_msme_hub

2. Restore Project Structure
Because this repository contains only the core logic and Android configurations, you need to regenerate the platform-specific boilerplate:
# This "heals" the project by adding missing platform folders (iOS, Web, etc.)

flutter create .

3. Install Dependencies
Fetch all the necessary packages defined in the pubspec.yaml:

flutter pub get

4. Verification & Execution
Ensure your environment is correctly configured:
flutter doctor

If everything is green, launch the application:

flutter run --no-enable-impeller
