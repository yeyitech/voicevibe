# Security Policy

## Supported Versions

VoiceVibe is currently maintained on the latest release line only.

| Version | Supported |
| --- | --- |
| Latest release | Yes |
| Older releases | No |
| Unreleased local forks | No |

## Reporting a Vulnerability

Do not open a public GitHub issue for security vulnerabilities.

Use one of these private channels instead:

1. GitHub Security Advisories for this repository:
   https://github.com/yeyitech/voicevibe/security
2. If private reporting is unavailable, contact the maintainer privately through GitHub:
   https://github.com/yeyitech

When reporting, include:

- affected version
- environment details
- reproduction steps
- impact assessment
- proof of concept if available
- whether the issue touches provider credentials, clipboard behavior, permissions, or local model execution

## Response Expectations

The maintainer will try to:

- acknowledge the report within 7 days
- confirm severity and reproduction status as soon as practical
- publish a fix or mitigation in a future release when validated

## Disclosure Policy

- Please give the maintainer reasonable time to investigate and patch the issue before public disclosure.
- Once a fix is available, the project may publish a release note or advisory summary.
- If the issue only affects a third-party provider or deployment, the maintainer may redirect the report to the relevant vendor.

## Security Scope Notes

This repository handles desktop dictation flows and may involve:

- provider API keys
- microphone access
- accessibility permissions
- clipboard fallback behavior
- local `whisper.cpp` execution
- self-hosted VibeVoice endpoints

Reports in those areas are especially useful.
