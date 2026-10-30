# Contributing Guidelines

Welcome to the AI-driven fruit export system for Sri Lankan fruits! This project is a 4-person university research project.

## Folder Rules
- **ONLY edit your own feature folder**. Each team member is responsible for one feature module under `lib/features/`.
- Features are completely decoupled. Do not import files from another feature folder.
- Changes to `lib/core/` (networking, config, themes) or `lib/shared/` (common widgets) **must be agreed upon with the entire team first** to avoid breaking each other's code.

## How to add a screen
1. Go to your feature's `presentation/screens` folder (e.g., `lib/features/identification/presentation/screens/`).
2. Add a new `.dart` file for your screen.
3. Add the route for your screen in your feature's route file (e.g., `identification_routes.dart`).
4. Ensure the new route is working by testing it in your local environment. 

## Mock vs Real API
We have a mock API setup to work without a backend.
- To switch between mock and real API, change the `useMockApi` boolean in `lib/core/config/app_config.dart`.
- Ensure `useMockApi` is set to `true` while the backend is still under development.
- Each data layer has an abstract service, a `MockService`, and an `ApiService`. A Riverpod provider injects the correct one based on `AppConfig.useMockApi`.

## Git Branch Naming
Please use the following naming convention for your branches:
- `feature/identification`
- `feature/defect-detection`
- `feature/shelf-life`
- `feature/traceability`
- `core/<change-description>` (if making a team-agreed core change)
- `fix/<bug-description>`

Good luck with the project!
