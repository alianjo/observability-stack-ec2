# Contributing to Observability Stack

Thank you for your interest in contributing to this project! This document provides guidelines for contributing.

## How to Contribute

### Reporting Issues

If you find a bug or have a suggestion:

1. **Check existing issues** to avoid duplicates
2. **Create a new issue** with a clear title and description
3. **Include details**:
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Environment details (OS, Terraform version, AWS region)
   - Relevant logs or error messages

### Suggesting Enhancements

For feature requests:

1. **Describe the use case** clearly
2. **Explain the benefit** to users
3. **Provide examples** if possible
4. **Consider alternatives** you've thought about

### Pull Requests

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature-name`
3. **Make your changes**:
   - Follow existing code style
   - Add comments for complex logic
   - Update documentation if needed
4. **Test your changes**:
   - Run `terraform validate`
   - Test deployment in your AWS account
   - Verify all services work correctly
5. **Commit your changes**: Use clear, descriptive commit messages
6. **Push to your fork**: `git push origin feature/your-feature-name`
7. **Create a Pull Request**:
   - Describe what you changed and why
   - Reference any related issues
   - Include testing steps

## Development Guidelines

### Code Style

**Terraform**:
- Use 2 spaces for indentation
- Add comments for complex resources
- Use meaningful variable names
- Group related resources together

**Python**:
- Follow PEP 8 style guide
- Use type hints where appropriate
- Add docstrings for functions
- Keep functions focused and small

**Shell Scripts**:
- Use `#!/bin/bash` shebang
- Add `set -e` for error handling
- Comment complex commands
- Use meaningful variable names

### Documentation

- Update README.md for user-facing changes
- Update ARCHITECTURE.md for architectural changes
- Add troubleshooting entries for common issues
- Include examples in documentation

### Testing

Before submitting a PR:

1. **Terraform validation**:
   ```bash
   cd terraform
   terraform fmt -recursive
   terraform validate
   ```

2. **Test deployment**:
   ```bash
   terraform plan
   terraform apply
   ```

3. **Run test script**:
   ```bash
   bash scripts/test_stack.sh
   ```

4. **Verify functionality**:
   - Check all services are accessible
   - Verify metrics are being collected
   - Confirm logs are being shipped
   - Test Grafana dashboard

5. **Clean up**:
   ```bash
   terraform destroy
   ```

## Project Structure

```
observability-stack-ec2/
├── terraform/          # Terraform configuration
├── scripts/           # Setup and utility scripts
├── app/              # Flask application
├── configs/          # Configuration templates
├── dashboards/       # Grafana dashboards
└── docs/             # Additional documentation
```

## Areas for Contribution

### High Priority

- [ ] Add support for multiple availability zones
- [ ] Implement auto-scaling for Flask app
- [ ] Add Alertmanager configuration
- [ ] Create additional Grafana dashboards
- [ ] Add CloudWatch integration
- [ ] Implement TLS/SSL support

### Medium Priority

- [ ] Add more sample applications (Node.js, Go, etc.)
- [ ] Create Terraform modules for reusability
- [ ] Add CI/CD pipeline examples
- [ ] Implement log rotation policies
- [ ] Add cost optimization features
- [ ] Create video tutorials

### Low Priority

- [ ] Add support for other cloud providers
- [ ] Create Kubernetes deployment option
- [ ] Add performance benchmarking tools
- [ ] Implement backup automation
- [ ] Add more dashboard examples

## Questions?

Feel free to open an issue for any questions about contributing.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
