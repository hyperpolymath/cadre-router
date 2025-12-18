# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |

## Security Measures

This repository implements the following security controls:

### GitHub Actions Security

1. **Action Pinning**: All third-party actions are pinned to specific commit SHAs, not version tags. This prevents supply chain attacks from compromised action releases.

2. **Least Privilege Permissions**: The workflow uses `permissions: contents: read` to minimize the blast radius of any potential compromise.

3. **Concurrency Control**: Workflow concurrency is managed to prevent race conditions that could lead to inconsistent state.

### SSH Security

1. **Known Hosts Verification**: SSH connections validate host keys using `ssh-keyscan` to prevent man-in-the-middle attacks.

2. **Key Isolation**: Each mirror target uses a dedicated SSH key, limiting exposure if one key is compromised.

3. **Secure Key Storage**: SSH private keys are stored in GitHub encrypted secrets, never in code.

### Recommendations for Maintainers

1. **Rotate SSH Keys**: Periodically rotate mirror SSH keys (recommended: annually)

2. **Audit Access**: Regularly review who has access to repository secrets

3. **Monitor Workflows**: Enable GitHub's audit log to track workflow executions

4. **Use Deploy Keys**: When possible, use deploy keys with write access only to specific repositories rather than user SSH keys

## Reporting a Vulnerability

If you discover a security vulnerability in this project:

1. **Do NOT** open a public issue
2. Email the maintainers directly at: security@example.com
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

We will acknowledge receipt within 48 hours and provide a detailed response within 7 days.

## Security Updates

Security updates will be applied to the `main` branch. Users should regularly pull updates to ensure they have the latest security fixes.
