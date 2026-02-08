# Contributing to ArgoCD AKS Demo

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## How to Contribute

### Reporting Issues

- Use the GitHub issue tracker
- Check if the issue already exists
- Provide detailed information:
  - Steps to reproduce
  - Expected behavior
  - Actual behavior
  - Environment details (AKS version, ArgoCD version, etc.)

### Suggesting Enhancements

- Open a GitHub issue with the "enhancement" label
- Clearly describe the feature
- Explain why it would be useful
- Provide examples if possible

### Pull Requests

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Follow existing code style
   - Update documentation
   - Add tests if applicable

4. **Test your changes**
   - Build and test locally
   - Deploy to a test AKS cluster
   - Verify ArgoCD sync works

5. **Commit your changes**
   ```bash
   git commit -m "feat: add new feature"
   ```
   
   Use conventional commits:
   - `feat:` - New feature
   - `fix:` - Bug fix
   - `docs:` - Documentation changes
   - `chore:` - Maintenance tasks
   - `refactor:` - Code refactoring
   - `test:` - Adding tests

6. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request**
   - Provide a clear description
   - Reference any related issues
   - Wait for review

## Development Guidelines

### Code Style

- **Bicep:** Follow Azure best practices
- **YAML:** Use 2-space indentation
- **Shell scripts:** Use shellcheck
- **Node.js:** Follow Airbnb style guide

### Documentation

- Update README.md if needed
- Add comments for complex logic
- Update relevant documentation files
- Include examples

### Testing

Before submitting:

```bash
# Test infrastructure
cd infrastructure/bicep
az bicep build --file main.bicep

# Test application
cd app
npm install
npm test

# Test Kubernetes manifests
kubectl kustomize kubernetes/overlays/dev
kubectl kustomize kubernetes/overlays/prod

# Test scripts
shellcheck infrastructure/scripts/*.sh
```

## Project Structure

Understanding the project layout:

```
.
├── app/                    # Sample application
├── argocd/                 # ArgoCD configurations
├── docs/                   # Documentation
├── infrastructure/         # IaC templates
├── kubernetes/            # K8s manifests
└── .github/               # CI/CD workflows
```

## Questions?

Feel free to open an issue for questions or join discussions.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
