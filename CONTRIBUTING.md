# Contributing to Coffee Mapper Android 🌱

First off, thank you for considering contributing to Coffee Mapper Android! It's people like you that make Coffee Mapper such a great tool for the Koraput coffee farming community. 👏

## 📝 Code of Conduct

By participating in this project, you are expected to uphold our Code of Conduct:

- Use welcoming and inclusive language
- Be respectful of differing viewpoints and experiences
- Gracefully accept constructive criticism
- Focus on what is best for the community
- Show empathy towards other community members

## 🚀 How Can I Contribute?

### 🐛 Reporting Bugs

Before creating bug reports, please check the issue list as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

* Use a clear and descriptive title
* Describe the exact steps which reproduce the problem
* Provide specific examples to demonstrate the steps
* Describe the behavior you observed after following the steps
* Explain which behavior you expected to see instead and why
* Include screenshots and logs if possible
* Include device and Android version information
* Specify if the issue occurs in debug or release mode

### 💡 Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

* Use a clear and descriptive title
* Provide a step-by-step description of the suggested enhancement
* Provide specific examples to demonstrate the steps
* Describe the current behavior and explain which behavior you expected to see instead
* Explain why this enhancement would be useful to most Coffee Mapper users
* Consider the impact on different Android versions and devices

### 🔧 Pull Requests

1. Fork the repo and create your branch from `main`.
2. If you've added code that should be tested, add tests.
3. If you've changed APIs, update the documentation.
4. Ensure the test suite passes.
5. Make sure your code lints.
6. Test on different Android versions and devices.
7. Issue that pull request!

## 📋 Development Process

1. **Branch Naming Convention**
   - Feature: `feature/your-feature-name`
   - Bug Fix: `fix/bug-name`
   - Documentation: `docs/what-you-documented`
   - UI Enhancement: `ui/what-you-improved`

2. **Commit Message Guidelines**
   ```
   type(scope): subject

   body

   footer
   ```
   Types: feat, fix, docs, style, refactor, test, chore

3. **Code Style**
   - Follow the [Flutter style guide](https://flutter.dev/docs/development/tools/formatting)
   - Run `flutter analyze` before committing
   - Maintain consistent file structure
   - Follow Android best practices

## 🧪 Testing

- Write unit tests for new features
- Include widget tests for UI components
- Add integration tests for critical flows
- Test on different Android versions (minimum Android 6.0)
- Test on various screen sizes and densities
- Verify offline functionality
- Test GPS and location features in different conditions

## 📚 Documentation

- Update README.md with details of changes
- Document new features and APIs
- Add comments to complex code sections
- Update the changelog
- Include setup instructions for new features
- Document Android-specific configurations

## 🛠️ Development Setup

1. **Prerequisites**
   ```bash
   flutter --version  # >= 3.5.4
   dart --version    # >= 3.5.0
   java --version    # JDK >= 11
   ```

2. **Local Development**
   ```bash
   # Get dependencies
   flutter pub get

   # Run tests
   flutter test

   # Run the app
   flutter run

   # Build APK
   flutter build apk
   ```

3. **Environment Setup**
   - Configure Google Maps API key
   - Set up Firebase project
   - Configure signing keys
   - Set up development environment variables

## 🔒 Security

- Follow Android security best practices
- Properly handle sensitive data
- Implement proper permission handling
- Use secure storage for credentials
- Follow Firebase security rules
- Implement proper error handling

## 📱 Platform Considerations

- Support minimum Android SDK version (Android 6.0/API 23)
- Handle different screen sizes and densities
- Implement proper permission handling
- Consider battery and resource usage
- Follow Material Design guidelines
- Ensure offline functionality

## 💬 Questions?

Don't hesitate to reach out to the maintainer team:
- Create an issue
- Email us at geospatialtech.production@gmail.com

## 🙏 Recognition

Contributors are recognized in our:
- README.md
- Release notes
- Project documentation
- Community showcase

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

Thank you for your contribution! 🎉 