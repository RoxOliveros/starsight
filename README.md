## Getting Started

# StarSight

StarSight is an educational mobile application developed using Flutter and Dart.
The application contains interactive learning worlds and mini-games designed
to support children's learning through play-based activities.

## Tech Stack

- Flutter
- Dart
- Firebase
- Git / GitHub

## Project Structure

starsight/
├── assets/
│   ├── animations/
│   ├── audio/
│   ├── fonts/
│   ├── gifs/
│   └── images/
├── lib/
│   ├── data_layer/
│   ├── business_layer/
│   ├── games_ui_layer/
│   │   ├── alphabet_forest/
│   │   ├── arctic_numberland/
│   │   ├── discovery_lagoon/
│   │   ├── lumi_town/
│   │   └── puzzle_glade/
│   ├── ui_layer/
│   └── main.dart
└── test/

## Branching Strategy

StarSight uses GitHub Flow with a `develop` integration branch.

- `master` - stable, QA-tested, and SA-approved code
- `develop` - integration branch for development work
- `feature/*` - new features
- `fix/*` - bug fixes
- `chore/*` - maintenance changes

Working branches must be created from the latest `develop` branch.

Branch naming:

feature/<ticket>-<short-description>
fix/<ticket>-<short-description>
chore/<ticket>-<short-description>

Example:

feature/SCRUM-91-odd-one-out

## Development Workflow

Prioritized Jira Task / Requirement
→ Task Assignment
→ Create Branch from develop
→ Develop
→ Developer Self-Testing
→ Commit and Push
→ Create Pull Request
→ Peer Code Review
→ Resolve Review Comments
→ Merge to develop
→ QA Testing
→ Feature Demonstration
→ Final SA Review and Approval
→ Integrate to master
→ Tag Jira Task as Done

If QA or SA does not approve the change, it returns to development for
correction and goes through the required review and testing process again.

## Commit Convention

Commit messages must be precise and concise.

Format:

<ticket>: <short description>

Examples:

SCRUM-91: add odd one out game
SCRUM-128: fix narration overlap
SCRUM-124: update puzzle assets

Avoid vague messages such as:

update
changes
fixed stuff
final
final final

## Pull Requests and Code Review

- Pull Requests should normally target `develop`.
- At least one developer other than the author must review the change.
- All BLOCKING review comments must be resolved before merging.
- The developer must test the affected functionality before requesting review.
- Reviewers verify correctness, code quality, StarSight consistency,
  functionality, regression risk, security/data handling, and documentation
  where applicable.

## Minimum Testing Before QA

Before handing work to QA:

- The application must build and run successfully.
- Requirements and acceptance criteria must be satisfied.
- No known critical crash or blocker should remain.
- Navigation and affected functionality must work correctly.
- UI and orientation must display correctly.
- Audio, narration, SFX, animations, and game logic must work where applicable.
- Level progress and saved data must work where applicable.
- Firebase-related behavior must be checked where applicable.
- Related existing functionality should be checked for regression.
- The feature should be tested on an emulator and/or supported physical device.

## Definition of Done

A Jira task may be marked Done only when all applicable requirements are met:

- Requirements and acceptance criteria are satisfied.
- Development and developer self-testing are complete.
- Pull Request and peer code review are complete.
- Blocking review comments are resolved.
- QA testing has passed.
- Required evidence and documentation are available.
- The feature has been demonstrated.
- Final review and approval have been completed by the System Analyst (SA).
- Approved code has been integrated into `master`.

## Development Process Documentation

For the complete development workflow, branching rules, code review process,
testing requirements, required artifacts, and Definition of Done, refer to the
StarSight Development Process & Workflow documentation.
