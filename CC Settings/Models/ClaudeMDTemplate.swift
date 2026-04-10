import Foundation

struct ClaudeMDTemplate: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: String
    let content: String
}

struct ClaudeMDSection: Identifiable {
    let id: String
    let name: String
    let icon: String
    let content: String
}

// MARK: - Template Categories

let templateCategories: [String] = [
    "General", "Mobile", "Web", "Backend", "Infra", "Data"
]

// MARK: - Templates

let claudeMDTemplates: [ClaudeMDTemplate] = [

    // MARK: General

    ClaudeMDTemplate(
        id: "blank",
        name: "Blank",
        description: "Empty CLAUDE.md file",
        icon: "doc",
        category: "General",
        content: ""
    ),

    ClaudeMDTemplate(
        id: "minimal",
        name: "Minimal",
        description: "Concise overview, style, and commands",
        icon: "doc.text",
        category: "General",
        content: """
        # Project Name

        Brief description of what this project does and why it exists.

        ## Tech Stack

        - Language / framework / runtime
        - Database / storage
        - Key dependencies

        ## Code Style

        - Follow existing patterns in the codebase
        - Use descriptive variable and function names
        - Keep functions small and focused

        ## Common Commands

        ```bash
        # Install dependencies
        # Run development server
        # Run tests
        # Build for production
        ```

        ## Important Notes

        - Describe any non-obvious constraints or decisions here
        """
    ),

    ClaudeMDTemplate(
        id: "comprehensive",
        name: "Comprehensive",
        description: "All sections with real guidance — under 120 lines",
        icon: "doc.richtext",
        category: "General",
        content: """
        # Project Name

        One-line description. Link to docs if they exist.

        ## Tech Stack

        - **Language**: e.g. TypeScript 5.x, Python 3.12, Swift 6
        - **Framework**: e.g. Next.js 15, FastAPI, SwiftUI
        - **Database**: e.g. PostgreSQL 16, SQLite, none
        - **Package manager**: e.g. pnpm, poetry, SPM

        ## Project Structure

        ```
        src/
        ├── components/    # UI components
        ├── lib/           # Shared utilities
        ├── services/      # Business logic
        └── types/         # Type definitions
        ```

        ## Build & Run

        ```bash
        # Install
        pnpm install

        # Development
        pnpm dev

        # Test
        pnpm test

        # Build
        pnpm build
        ```

        ## Code Style

        - Follow existing patterns — don't introduce new conventions without discussion
        - Naming: camelCase for functions/variables, PascalCase for types/components
        - Files: one primary export per file, name matches the export
        - No comments on obvious code — only explain non-trivial logic
        - Prefer explicit types over inference when the type isn't obvious

        ## Architecture Decisions

        - Describe your data flow: e.g. "Components fetch data via hooks that call service functions"
        - State management approach: e.g. "React Context for global state, useState for local"
        - Error handling: e.g. "All API calls return Result types, never throw"

        ## Testing

        - Unit tests for business logic and utilities
        - Integration tests for API endpoints
        - Test file naming: `*.test.ts` next to the source file

        ```bash
        pnpm test              # all tests
        pnpm test -- --watch   # watch mode
        ```

        ## Environment

        Required env vars (do NOT commit `.env` files):
        - `DATABASE_URL` — connection string
        - `API_KEY` — third-party service key

        ## Important Constraints

        - NEVER commit secrets or API keys
        - All user input must be validated at the API boundary
        - Database migrations must be backwards-compatible
        """
    ),

    // MARK: Mobile

    ClaudeMDTemplate(
        id: "ios-swiftui",
        name: "iOS / SwiftUI",
        description: "Swift 6, SwiftUI, MVVM, SPM, XCTest",
        icon: "iphone",
        category: "Mobile",
        content: """
        # App Name — iOS

        Brief description. Minimum deployment target: iOS 18.0.

        ## Tech Stack

        - **Language**: Swift 6 with strict concurrency
        - **UI**: SwiftUI (no UIKit unless wrapping existing components)
        - **Architecture**: MVVM with @Observable
        - **Package manager**: Swift Package Manager
        - **Dependencies**: list key packages here

        ## Project Structure

        ```
        AppName/
        ├── App/           # @main entry point, App struct
        ├── Models/        # Data models, Codable structs
        ├── ViewModels/    # @Observable classes
        ├── Views/         # SwiftUI views by feature
        ├── Services/      # Networking, persistence, business logic
        └── Resources/     # Assets, Info.plist, entitlements
        ```

        ## Build & Run

        ```bash
        # Open in Xcode
        open AppName.xcodeproj
        # Or with SPM:
        swift build
        swift test
        ```

        ## Code Style

        - 4 spaces indentation
        - PascalCase for types, camelCase for properties/functions
        - One view per file, file name matches the view struct
        - Use `// MARK: -` for logical sections in larger files
        - Prefer value types (structs, enums) over classes
        - Use async/await, never completion handlers for new code

        ## Architecture

        - Views are thin — display state, send actions to ViewModel
        - ViewModels are @Observable, @MainActor, handle business logic
        - Services are injected via environment or init parameters
        - Navigation via NavigationStack with typed NavigationPath

        ## Testing

        - XCTest for unit and integration tests
        - Test ViewModels with mock services
        - UI tests for critical user flows only

        ## Important

        - Never force-unwrap optionals in production code
        - All network calls must handle errors gracefully
        - Support Dynamic Type and VoiceOver accessibility
        """
    ),

    ClaudeMDTemplate(
        id: "android-kotlin",
        name: "Android / Kotlin",
        description: "Kotlin, Jetpack Compose, MVVM, Gradle",
        icon: "apps.iphone",
        category: "Mobile",
        content: """
        # App Name — Android

        Brief description. Minimum SDK: 26 (Android 8.0).

        ## Tech Stack

        - **Language**: Kotlin 2.x
        - **UI**: Jetpack Compose (no XML layouts for new screens)
        - **Architecture**: MVVM with Hilt DI
        - **Build**: Gradle with Kotlin DSL
        - **Key libraries**: Retrofit, Room, Coroutines, Coil

        ## Project Structure

        ```
        app/src/main/
        ├── di/            # Hilt modules
        ├── data/          # Repositories, data sources, models
        ├── domain/        # Use cases, domain models
        ├── ui/            # Compose screens and components
        │   ├── theme/     # Material theme, colors, typography
        │   └── screens/   # One package per feature
        └── util/          # Extensions and helpers
        ```

        ## Build & Run

        ```bash
        ./gradlew assembleDebug
        ./gradlew test
        ./gradlew connectedAndroidTest
        ```

        ## Code Style

        - Follow Kotlin official style guide
        - Use data classes for models, sealed classes for state
        - Prefer Coroutines + Flow over RxJava
        - Compose: stateless composables, hoist state up

        ## Important

        - Never block the main thread
        - Use `remember` and `derivedStateOf` to avoid unnecessary recomposition
        - All strings must go through string resources for localization
        """
    ),

    // MARK: Web

    ClaudeMDTemplate(
        id: "nextjs-react",
        name: "Next.js / React",
        description: "TypeScript, App Router, Tailwind, testing",
        icon: "globe",
        category: "Web",
        content: """
        # Project Name

        Brief description. Built with Next.js 15 and React 19.

        ## Tech Stack

        - **Framework**: Next.js 15 (App Router)
        - **Language**: TypeScript 5.x (strict mode)
        - **Styling**: Tailwind CSS
        - **Database**: Prisma + PostgreSQL (or describe your stack)
        - **Auth**: NextAuth.js / Clerk / custom
        - **Package manager**: pnpm

        ## Project Structure

        ```
        src/
        ├── app/           # App Router pages and layouts
        │   ├── api/       # Route handlers
        │   └── (routes)/  # Page groups
        ├── components/    # Reusable UI components
        ├── lib/           # Server utilities, db client, auth
        ├── hooks/         # Custom React hooks
        └── types/         # Shared TypeScript types
        ```

        ## Commands

        ```bash
        pnpm install          # install deps
        pnpm dev              # dev server on localhost:3000
        pnpm build            # production build
        pnpm test             # run tests
        pnpm lint             # ESLint + Prettier check
        pnpm db:push          # push Prisma schema to db
        pnpm db:studio        # open Prisma Studio
        ```

        ## Code Style

        - Functional components only, no class components
        - Use `"use client"` only when needed — prefer server components
        - Colocate related files: `page.tsx`, `loading.tsx`, `error.tsx`
        - Name components with PascalCase, hooks with `use` prefix
        - Validate all user input with Zod schemas

        ## Important

        - Server Actions for mutations, Route Handlers for external API
        - Never expose server secrets to client components
        - Use `loading.tsx` and `error.tsx` for every route segment
        - Images must use `next/image` for optimization
        """
    ),

    ClaudeMDTemplate(
        id: "python-fastapi",
        name: "Python / FastAPI",
        description: "FastAPI, Poetry, SQLAlchemy, pytest",
        icon: "chevron.left.forwardslash.chevron.right",
        category: "Web",
        content: """
        # Project Name

        Brief description. Python 3.12+ REST API.

        ## Tech Stack

        - **Framework**: FastAPI
        - **Language**: Python 3.12+
        - **ORM**: SQLAlchemy 2.x with async support
        - **Package manager**: Poetry
        - **Testing**: pytest + httpx
        - **Linting**: ruff

        ## Project Structure

        ```
        src/
        ├── api/           # Route handlers (routers)
        ├── models/        # SQLAlchemy models
        ├── schemas/       # Pydantic request/response schemas
        ├── services/      # Business logic
        ├── core/          # Config, database, dependencies
        └── tests/         # Test files mirroring src/ structure
        ```

        ## Commands

        ```bash
        poetry install                # install deps
        poetry run uvicorn src.main:app --reload  # dev server
        poetry run pytest             # run tests
        poetry run ruff check .       # lint
        poetry run ruff format .      # format
        poetry run alembic upgrade head  # run migrations
        ```

        ## Code Style

        - Type hints on all function signatures — no `Any` unless justified
        - Use Pydantic models for all request/response validation
        - Async endpoints for I/O-bound operations
        - Dependency injection via FastAPI's `Depends()`
        - One router per resource, grouped in `api/`

        ## Important

        - Never use raw SQL — always go through SQLAlchemy
        - All endpoints must have Pydantic response models
        - Environment config via pydantic-settings, never hardcoded
        - Write tests for every endpoint — minimum: happy path + error case
        """
    ),

    ClaudeMDTemplate(
        id: "node-express",
        name: "Node.js / Express",
        description: "TypeScript, Express, Prisma, Jest",
        icon: "server.rack",
        category: "Web",
        content: """
        # Project Name

        Brief description. Node.js REST API.

        ## Tech Stack

        - **Runtime**: Node.js 22 LTS
        - **Framework**: Express 5
        - **Language**: TypeScript (strict mode)
        - **ORM**: Prisma
        - **Testing**: Jest + Supertest
        - **Package manager**: pnpm

        ## Project Structure

        ```
        src/
        ├── routes/        # Express route handlers
        ├── middleware/     # Auth, validation, error handling
        ├── services/      # Business logic
        ├── models/        # Prisma schema + generated types
        ├── utils/         # Shared helpers
        └── __tests__/     # Test files
        ```

        ## Commands

        ```bash
        pnpm install          # install deps
        pnpm dev              # dev server with hot reload
        pnpm build            # compile TypeScript
        pnpm start            # run production build
        pnpm test             # run tests
        pnpm lint             # ESLint check
        pnpm prisma:migrate   # run migrations
        ```

        ## Code Style

        - Use async/await, never callbacks
        - Validate request bodies with Zod or Joi
        - Error handling: throw custom AppError classes, catch in error middleware
        - One route file per resource
        - Environment variables via `dotenv`, typed with Zod schema

        ## Important

        - Never trust client input — validate everything
        - Use parameterized queries (Prisma handles this)
        - All routes must have error handling
        - Log structured JSON, not console.log
        """
    ),

    // MARK: Backend

    ClaudeMDTemplate(
        id: "go-api",
        name: "Go API",
        description: "Go modules, standard library, testing",
        icon: "bolt.horizontal",
        category: "Backend",
        content: """
        # Project Name

        Brief description. Go API service.

        ## Tech Stack

        - **Language**: Go 1.23+
        - **Router**: net/http (stdlib) or chi
        - **Database**: pgx + sqlc for PostgreSQL
        - **Testing**: stdlib testing + testify
        - **Linting**: golangci-lint

        ## Project Structure

        ```
        cmd/
        └── server/        # main.go entry point
        internal/
        ├── handler/       # HTTP handlers
        ├── service/       # Business logic
        ├── repository/    # Database access
        ├── model/         # Domain types
        └── middleware/     # HTTP middleware
        pkg/               # Exported packages (if any)
        migrations/        # SQL migration files
        ```

        ## Commands

        ```bash
        go run ./cmd/server         # run locally
        go test ./...               # run all tests
        go test -race ./...         # with race detector
        golangci-lint run           # lint
        sqlc generate               # regenerate DB code
        ```

        ## Code Style

        - Follow Effective Go and Go Code Review Comments
        - Error handling: return errors, don't panic. Wrap with `fmt.Errorf("context: %w", err)`
        - Use interfaces for dependency injection, define them where consumed
        - Table-driven tests for handler and service functions
        - Context propagation: always pass `context.Context` as first parameter

        ## Important

        - Never ignore errors — handle or explicitly discard with `_ =`
        - Use `context.Context` for cancellation and timeouts
        - Database queries must use parameterized statements
        - Keep handlers thin — delegate to service layer
        """
    ),

    ClaudeMDTemplate(
        id: "rust",
        name: "Rust",
        description: "Cargo, error handling, testing, clippy",
        icon: "hammer",
        category: "Backend",
        content: """
        # Project Name

        Brief description. Rust application/library.

        ## Tech Stack

        - **Language**: Rust (latest stable)
        - **Build**: Cargo
        - **Async**: Tokio (if async)
        - **Web**: Axum / Actix-web (if applicable)
        - **Serialization**: serde + serde_json

        ## Project Structure

        ```
        src/
        ├── main.rs        # Entry point (binary) or lib.rs (library)
        ├── config.rs      # Configuration
        ├── error.rs       # Custom error types
        ├── handlers/      # Request handlers (web)
        ├── models/        # Domain types
        └── services/      # Business logic
        tests/             # Integration tests
        ```

        ## Commands

        ```bash
        cargo build            # debug build
        cargo build --release  # release build
        cargo test             # run tests
        cargo clippy           # lint
        cargo fmt              # format
        cargo doc --open       # generate docs
        ```

        ## Code Style

        - Use `thiserror` for library errors, `anyhow` for application errors
        - Prefer `Result<T, E>` over `.unwrap()` — never unwrap in production
        - Use `#[derive(Debug, Clone, Serialize, Deserialize)]` generously
        - Module structure: one file per logical module, `mod.rs` for re-exports
        - `cargo clippy -- -W clippy::all` must pass with no warnings

        ## Important

        - Unsafe code requires a `// SAFETY:` comment explaining why it's sound
        - All public APIs must have doc comments (`///`)
        - Use `tracing` for structured logging, not `println!`
        - Pin dependency versions in `Cargo.toml`
        """
    ),

    // MARK: Infra

    ClaudeMDTemplate(
        id: "monorepo",
        name: "Monorepo",
        description: "Turborepo/Nx, workspace structure, nested CLAUDE.md",
        icon: "square.stack.3d.up",
        category: "Infra",
        content: """
        # Monorepo Name

        Brief description of this monorepo and its packages.

        ## Structure

        ```
        apps/
        ├── web/           # Next.js frontend
        ├── api/           # Backend service
        └── mobile/        # React Native / iOS / Android
        packages/
        ├── shared/        # Shared types and utilities
        ├── ui/            # Shared UI component library
        └── config/        # Shared ESLint, Prettier, TS configs
        ```

        ## CLAUDE.md Strategy

        This root CLAUDE.md contains universal rules. Each app/package has its own CLAUDE.md with domain-specific instructions. Nested files load IN ADDITION to this file, not instead of it.

        - `apps/web/CLAUDE.md` — frontend conventions
        - `apps/api/CLAUDE.md` — backend conventions
        - Keep each file under 100 lines

        ## Commands

        ```bash
        pnpm install              # install all deps
        pnpm dev                  # run all apps in dev mode
        pnpm build                # build all packages
        pnpm test                 # test all packages
        pnpm lint                 # lint all packages
        pnpm dev --filter=web     # run only web app
        pnpm test --filter=api    # test only api
        ```

        ## Conventions

        - Shared code goes in `packages/`, never duplicated across apps
        - Each package has its own `package.json`, `tsconfig.json`, and tests
        - Import shared packages via workspace protocol: `"@repo/shared": "workspace:*"`
        - Changes to `packages/` must not break any consumer — check with `pnpm build`

        ## Important

        - Never import between apps directly — go through a shared package
        - CI runs affected tests only (Turborepo caching)
        - Root `package.json` is for workspace scripts only, not dependencies
        """
    ),

    ClaudeMDTemplate(
        id: "cli-tool",
        name: "CLI Tool",
        description: "Command-line tool with argument parsing and testing",
        icon: "terminal",
        category: "Infra",
        content: """
        # Tool Name

        Brief description. What problem does this CLI solve?

        ## Usage

        ```bash
        tool-name <command> [options]
        tool-name init --name my-project
        tool-name build --release
        ```

        ## Project Structure

        ```
        src/
        ├── main.*         # Entry point, argument parsing
        ├── commands/      # One file per subcommand
        ├── config/        # Config file loading
        ├── output/        # Formatting, colors, progress bars
        └── util/          # Shared helpers
        tests/
        └── integration/   # End-to-end CLI tests
        ```

        ## Build & Test

        ```bash
        # Build
        # Run locally
        # Run tests
        # Install globally
        ```

        ## Code Style

        - Exit codes: 0 = success, 1 = user error, 2 = internal error
        - Use stderr for errors and progress, stdout for data output
        - Support `--json` flag for machine-readable output
        - Use a proper argument parser, not manual string parsing
        - Color output should respect `NO_COLOR` environment variable

        ## Important

        - Every command must have `--help` text
        - Errors should suggest how to fix the problem
        - Config files: support both local (project) and global (~/) locations
        - Test the CLI as a subprocess in integration tests, not just unit tests
        """
    ),

    // MARK: Data

    ClaudeMDTemplate(
        id: "data-science",
        name: "Data Science / ML",
        description: "Python, Jupyter, pandas, model training",
        icon: "chart.bar",
        category: "Data",
        content: """
        # Project Name

        Brief description. What data problem does this solve?

        ## Tech Stack

        - **Language**: Python 3.12+
        - **Data**: pandas, polars, numpy
        - **ML**: scikit-learn, PyTorch, or HuggingFace (pick yours)
        - **Notebooks**: Jupyter
        - **Package manager**: Poetry or pip + requirements.txt
        - **Experiment tracking**: MLflow / Weights & Biases (if applicable)

        ## Project Structure

        ```
        data/
        ├── raw/           # Original immutable data (gitignored)
        ├── processed/     # Cleaned data ready for modeling
        └── external/      # Third-party data sources
        notebooks/         # Exploration and analysis
        src/
        ├── data/          # Data loading and processing
        ├── features/      # Feature engineering
        ├── models/        # Model training and evaluation
        └── visualization/ # Plotting utilities
        models/            # Saved model artifacts (gitignored)
        ```

        ## Commands

        ```bash
        poetry install                # install deps
        jupyter lab                   # start notebooks
        python -m src.data.process    # run data pipeline
        python -m src.models.train    # train model
        pytest tests/                 # run tests
        ```

        ## Conventions

        - Raw data is immutable — never modify files in `data/raw/`
        - Notebooks are for exploration — production code goes in `src/`
        - Every function that transforms data must have a docstring explaining inputs/outputs
        - Use type hints, especially for DataFrame column expectations
        - Random seeds must be set explicitly for reproducibility

        ## Important

        - Never commit data files or model artifacts to git
        - Document data sources and their update frequency
        - Log all experiment parameters and metrics
        - Validate data quality before training: check for nulls, duplicates, distributions
        """
    ),
]

// MARK: - Insertable Sections

let claudeMDSections: [ClaudeMDSection] = [
    ClaudeMDSection(
        id: "overview",
        name: "Project Overview",
        icon: "info.circle",
        content: "## Project Overview\n\nBrief description of the project.\n"
    ),
    ClaudeMDSection(
        id: "style",
        name: "Code Style",
        icon: "paintbrush",
        content: "## Code Style\n\n- Follow existing patterns\n- Use consistent naming conventions\n"
    ),
    ClaudeMDSection(
        id: "testing",
        name: "Testing",
        icon: "checkmark.circle",
        content: "## Testing\n\nHow to run tests and testing conventions.\n\n```bash\n# Run tests\n```\n"
    ),
    ClaudeMDSection(
        id: "architecture",
        name: "Architecture",
        icon: "building.2",
        content: "## Architecture\n\nKey architectural decisions and patterns.\n"
    ),
    ClaudeMDSection(
        id: "dependencies",
        name: "Dependencies",
        icon: "shippingbox",
        content: "## Dependencies\n\nKey dependencies and their purposes.\n"
    ),
    ClaudeMDSection(
        id: "commands",
        name: "Common Commands",
        icon: "terminal",
        content: "## Common Commands\n\n```bash\n# Build\n# Test\n# Deploy\n```\n"
    ),
    ClaudeMDSection(
        id: "environment",
        name: "Environment Variables",
        icon: "key",
        content: "## Environment\n\nRequired environment variables (do NOT commit `.env`):\n\n- `DATABASE_URL` — connection string\n- `API_KEY` — service key\n"
    ),
    ClaudeMDSection(
        id: "constraints",
        name: "Important Constraints",
        icon: "exclamationmark.triangle",
        content: "## Important\n\n- NEVER commit secrets or API keys\n- All user input must be validated\n- Database migrations must be backwards-compatible\n"
    ),
]
