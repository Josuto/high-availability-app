# Contributing to High-Availability NestJS App with AWS & Terraform

Thank you for your interest in contributing to this learning project! This document provides guidelines to help you contribute effectively.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Workflow](#development-workflow)
4. [Code Style and Standards](#code-style-and-standards)
5. [Commit Message Guidelines](#commit-message-guidelines)
6. [Testing Requirements](#testing-requirements)
7. [Documentation Standards](#documentation-standards)
8. [Pull Request Process](#pull-request-process)
9. [Issue Reporting](#issue-reporting)

## Code of Conduct

This project is a learning resource. Please be respectful, constructive, and helpful in all interactions.

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- **AWS Account** with appropriate IAM permissions
- **Terraform** 1.0+ installed
- **Pre-commit** framework installed
- **TFLint**, **Trivy**, **terraform-docs**, **detect-secrets** installed
- **Node.js** and **pnpm** for application development
- **kubectl** and **helm** (for EKS contributions)

### Setting Up Your Environment

1. **Fork the repository** on GitHub

2. **Clone your fork**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/terraform-course-dummy-nestjs-app.git
   cd terraform-course-dummy-nestjs-app
   ```

3. **Install pre-commit hooks**:
   ```bash
   pre-commit install # To allow running hooks that exec before each commit
   pre-commit install --hook-type pre-push # To allow running hooks that exec before pushing code

   ```

4. **Install dependencies** (for NestJS app):
   ```bash
   pnpm install
   ```

5. **Verify your setup**:
   ```bash
   # Test pre-commit hooks
   pre-commit run --all-files

   # Test Terraform formatting
   terraform fmt -recursive infra-ecs/
   terraform fmt -recursive infra-eks/
   ```

## Development Workflow

1. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```

2. **Make your changes** following the code style guidelines

3. **Test your changes** thoroughly (see Testing Requirements)

4. **Format and validate** before committing:
   ```bash
   # Format Terraform files
   terraform fmt -recursive infra-ecs/
   terraform fmt -recursive infra-eks/

   # Run pre-commit hooks manually
   pre-commit run --all-files
   ```

5. **Commit your changes** using conventional commit format

6. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Open a Pull Request** on GitHub

## Code Style and Standards

### Terraform

- **Format all files**: Run `terraform fmt -recursive` before committing
- **Use consistent naming**: Follow existing patterns (`project_name-environment-resource`)
- **Add comments**: Explain complex logic or non-obvious design decisions
- **Validate syntax**: Ensure `terraform validate` passes in all modules
- **Use variables**: Avoid hardcoded values; use variables with clear descriptions
- **Output important values**: Add outputs for values that other modules may need
- **Tag all resources**: Include standard tags (Project, Environment, etc.)

### NestJS/TypeScript

- **Follow existing patterns**: Match the style of existing code
- **Use TypeScript strict mode**: No `any` types without justification
- **Format with Prettier**: Run `pnpm format` before committing
- **Lint with ESLint**: Run `pnpm lint` and fix all warnings
- **Add JSDoc comments**: Document public methods and complex logic

### Documentation

- **Use GitHub-flavored Markdown**
- **Keep lines under 120 characters** for readability
- **Use proper heading hierarchy** (don't skip levels)
- **Include code examples** with proper syntax highlighting
- **Add links** to related documentation sections
- **Keep table of contents updated** when adding/removing sections

## Commit Message Guidelines

This project follows [Conventional Commits](https://www.conventionalcommits.org/) specification.

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation only changes
- **style**: Code style changes (formatting, missing semicolons, etc.)
- **refactor**: Code change that neither fixes a bug nor adds a feature
- **perf**: Performance improvement
- **test**: Adding or updating tests
- **chore**: Changes to build process, dependencies, or auxiliary tools

### Scope (optional)

- `ecs`: ECS-related changes
- `eks`: EKS-related changes
- `app`: NestJS application changes
- `docs`: Documentation changes
- `ci`: CI/CD workflow changes
- `infra`: General infrastructure changes

### Examples

```bash
feat(ecs): add support for Fargate capacity provider

fix(eks): correct node group IAM policy attachments

docs(readme): update quick start guide with domain setup

chore(deps): upgrade Terraform AWS provider to v5.0
```

### Guidelines

- Use **present tense** ("add feature" not "added feature")
- Use **imperative mood** ("move cursor to..." not "moves cursor to...")
- **First line should be 50 characters or less**
- **Body should wrap at 72 characters**
- Reference issues and PRs in footer (e.g., "Fixes #123")

## Testing Requirements

### Before Submitting a PR

1. **Run pre-commit hooks**:
   ```bash
   pre-commit run --all-files
   ```

2. **Run Terraform module tests**:
   ```bash
   # For ECS modules
   cd infra-ecs/
   ./run-tests.sh

   # For EKS modules
   cd infra-eks/
   ./run-tests.sh
   ```

   **Note:** These tests also run automatically via pre-push hooks when you push changes to Terraform files.

3. **Terraform validation** (if not using test script):
   ```bash
   # Validate all modules
   cd infra-ecs/modules/<module-name>
   terraform init
   terraform validate

   # Run terraform test if tests exist
   terraform test
   ```

3. **NestJS tests** (if applicable):
   ```bash
   # Unit tests
   pnpm test

   # E2E tests
   pnpm test:e2e

   # Test coverage
   pnpm test:cov
   ```

4. **Security scanning**:
   ```bash
   # Trivy should run via pre-commit, but you can run manually:
   trivy infra-ecs/
   trivy infra-eks/
   ```

5. **Documentation generation**:
   ```bash
   # terraform-docs should run via pre-commit, but verify:
   terraform-docs markdown table --output-file README.md infra-ecs/modules/<module-name>
   ```

### Integration Testing

If your changes affect infrastructure:

1. **Test in a clean environment**
2. **Verify `terraform plan` output** is as expected
3. **Test `terraform apply`** in a non-production environment
4. **Verify resources are created correctly** in AWS Console
5. **Test `terraform destroy`** to ensure clean teardown
6. **Document any manual steps** required (e.g., DNS propagation)

## Documentation Standards

### When to Update Documentation

Update documentation when you:

- Add new infrastructure modules or resources
- Change existing module inputs/outputs
- Modify deployment procedures
- Add new features to the NestJS application
- Change CI/CD workflows
- Add new prerequisites or dependencies

### Files to Update

Depending on your changes, update:

- **`README.md`** (root): High-level project overview
- **`infra-ecs/README.md`**: ECS-specific documentation
- **`infra-eks/README.md`**: EKS-specific documentation
- **Module `README.md`**: Auto-generated via terraform-docs (update inputs/outputs)
- **`CLAUDE.md`**: Project instructions for AI assistance (if adding new patterns)

### Documentation Checklist

- [ ] Updated relevant README files
- [ ] Added/updated code comments for complex logic
- [ ] Regenerated terraform-docs for modified modules
- [ ] Updated table of contents if section structure changed
- [ ] Verified all links work correctly
- [ ] Added examples for new features
- [ ] Updated architecture diagrams if structure changed

## Pull Request Process

### Before Opening a PR

1. **Ensure all tests pass** (see Testing Requirements)
2. **Update documentation** as needed
3. **Rebase on latest main**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```
4. **Squash commits** if you have multiple small commits (optional but recommended)

### PR Title

Use the same format as commit messages:
```
feat(ecs): add support for Fargate capacity provider
```

### PR Description Template

```markdown
## Description
Brief description of what this PR does.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Infrastructure change
- [ ] CI/CD update

## Motivation and Context
Why is this change required? What problem does it solve?
Fixes # (issue)

## How Has This Been Tested?
Describe the tests you ran to verify your changes.

## Screenshots (if applicable)
Add screenshots to help explain your changes.

## Checklist
- [ ] My code follows the code style of this project
- [ ] I have run pre-commit hooks and all checks pass
- [ ] I have updated the documentation accordingly
- [ ] I have added tests to cover my changes (if applicable)
- [ ] All new and existing tests pass
- [ ] My changes generate no new warnings
- [ ] I have checked my code and corrected any misspellings
```

### Review Process

1. Maintainers will review your PR within a few days
2. Address any feedback or requested changes
3. Once approved, a maintainer will merge your PR
4. Your branch will be deleted after merge

### After Your PR is Merged

1. **Delete your feature branch**:
   ```bash
   git branch -d feature/your-feature-name
   git push origin --delete feature/your-feature-name
   ```

2. **Update your local main**:
   ```bash
   git checkout main
   git pull upstream main
   ```

## Issue Reporting

### Before Opening an Issue

1. **Search existing issues** to avoid duplicates
2. **Check the documentation** to ensure it's not already covered
3. **Verify the issue** in a clean environment

### Issue Template

**For Bug Reports:**
```markdown
## Bug Description
A clear description of what the bug is.

## Steps to Reproduce
1. Go to '...'
2. Run command '...'
3. See error

## Expected Behavior
What you expected to happen.

## Actual Behavior
What actually happened.

## Environment
- OS: [e.g., macOS 14.0]
- Terraform version: [e.g., 1.7.0]
- AWS region: [e.g., us-east-1]
- Approach: [ECS or EKS]

## Logs/Error Messages
```
Paste relevant logs or error messages here
```

## Additional Context
Any other context about the problem.
```

**For Feature Requests:**
```markdown
## Feature Description
Clear description of the feature you'd like.

## Use Case
Why is this feature needed? What problem does it solve?

## Proposed Solution
How you envision this feature working.

## Alternatives Considered
Other solutions you've considered.

## Additional Context
Any other context or screenshots.
```

## Questions?

If you have questions about contributing:

1. **Check existing documentation**: [README.md](README.md), [infra-ecs/README.md](infra-ecs/README.md), [infra-eks/README.md](infra-eks/README.md)
2. **Search closed issues**: Someone may have asked the same question
3. **Open a new issue**: Use the "Question" label

---

Thank you for contributing to this learning project! Your improvements help others learn AWS, Terraform, and cloud infrastructure patterns.
