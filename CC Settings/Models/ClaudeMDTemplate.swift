import Foundation

struct ClaudeMDTemplate: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let content: String
}

struct ClaudeMDSection: Identifiable {
    let id: String
    let name: String
    let icon: String
    let content: String
}

let claudeMDTemplates: [ClaudeMDTemplate] = [
    ClaudeMDTemplate(
        id: "blank",
        name: "Blank",
        description: "Empty CLAUDE.md file",
        icon: "doc",
        content: ""
    ),
    ClaudeMDTemplate(
        id: "minimal",
        name: "Minimal",
        description: "Basic project structure with overview and style guidelines",
        icon: "doc.text",
        content: """
        # Project Overview

        Brief description of this project.

        ## Code Style

        - Follow existing patterns
        - Use consistent naming conventions
        """
    ),
    ClaudeMDTemplate(
        id: "full",
        name: "Full",
        description: "Complete template with all common sections",
        icon: "doc.richtext",
        content: """
        # Project Overview

        Description of this project.

        ## Architecture

        Key architectural decisions and patterns.

        ## Code Style

        - Style guidelines here
        - Naming conventions
        - File organization

        ## Testing

        How to run tests and testing conventions.

        ## Dependencies

        Key dependencies and their purposes.

        ## Common Commands

        ```bash
        # Build
        # Test
        # Deploy
        ```
        """
    ),
    ClaudeMDTemplate(
        id: "library",
        name: "Library / Package",
        description: "Template for libraries and reusable packages",
        icon: "shippingbox",
        content: """
        # Library Name

        Brief description of what this library does.

        ## Installation

        How to add this library as a dependency.

        ## API Overview

        Key public APIs and their usage.

        ## Architecture

        Internal structure and design decisions.

        ## Code Style

        - Follow semantic versioning
        - Document all public APIs
        - Write unit tests for all public methods

        ## Testing

        ```bash
        # Run tests
        # Run tests with coverage
        ```

        ## Publishing

        Steps to publish a new version.
        """
    ),
    ClaudeMDTemplate(
        id: "webapp",
        name: "Web App",
        description: "Template for web applications with frontend and backend",
        icon: "globe",
        content: """
        # Web App Name

        Brief description of this web application.

        ## Architecture

        - Frontend: Framework and structure
        - Backend: API framework and patterns
        - Database: Schema and migrations

        ## Code Style

        - Follow existing patterns
        - Use TypeScript strict mode
        - Component naming conventions

        ## Environment Setup

        Required environment variables and configuration.

        ## Testing

        ```bash
        # Run unit tests
        # Run integration tests
        # Run e2e tests
        ```

        ## Deployment

        ```bash
        # Build for production
        # Deploy
        ```

        ## API Documentation

        Key API endpoints and their purposes.
        """
    ),
]

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
]
