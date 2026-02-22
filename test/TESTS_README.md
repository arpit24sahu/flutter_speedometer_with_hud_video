# Speedometer App Test Suite

This directory contains the automated tests for the Speedometer Flutter application.

## Directory Structure

The test suite is organized into the following directories:

-   **`unit/`**: Contains unit tests for models, services, repositories, and utility functions. These tests are fast and do not depend on the Flutter framework or external resources (unless mocked).
-   **`bloc/`**: Contains tests for BLoCs (Business Logic Components). These tests verify state changes in response to events using the `bloc_test` package.
-   **`integration/`**: Contains integration tests that verify the interaction between multiple parts of the app or with external services (simulated).
-   **`ui/`**: Contains widget tests that verify the UI components and their interactions.
-   **`helpers/`**: Contains helper classes, mock objects, and test utilities shared across multiple tests.

## Testing Strategy

We follow the "Testing Pyramid" approach:

1.  **Unit & Bloc Tests**: The foundation of our test suite. Focus on testing individual components in isolation. Aim for high coverage here.
2.  **Widget (UI) Tests**: Verify that widgets render correctly and respond to user interactions.
3.  **Integration Tests**: Verify critical user flows and app stability.

## Libraries

-   **`flutter_test`**: The core Flutter testing library.
-   **`bloc_test`**: For testing BLoCs.
-   **`mocktail`**: For mocking dependencies. favored over `mockito` as it doesn't require code generation.

## Running Tests

To run all tests:

```bash
flutter test
```

To run tests in a specific directory:

```bash
flutter test test/unit
flutter test test/bloc
```

## Coverage

We aim for high test coverage, especially for business logic (BLoCs and Services).

To generate a coverage report:

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Best Practices

-   **SOLID Principles**: Ensure code and tests follow SOLID principles.
-   **DRY (Don't Repeat Yourself)**: Use helper functions and shared mocks in `test/helpers`.
-   **Naming**: Test files should end with `_test.dart`. Test descriptions should be clear and descriptive.
-   **Arrange-Act-Assert**: Structure tests using the AAA pattern.

---
**Maintained by:** Lead Software Engineer
