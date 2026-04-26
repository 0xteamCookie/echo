# Security Policy

Echo is built for crisis response. A vulnerability in Echo is not a theoretical risk — it could mean a missed SOS or a spoofed dispatch. We take security reports seriously and we will respond fast.

## Supported Versions

The mobile app is in active prototype development for **Google Solution Challenge 2026**. Only the `main` branch is supported; please report against the latest commit.

| Version | Supported |
|---|---|
| `main` | yes |
| anything else | no |

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security problems.**

Instead, use one of:

1. **GitHub Private Vulnerability Reporting** — `Security` tab → *Report a vulnerability*.
2. **Email** — open a placeholder issue titled "Security contact request" (without details) and a maintainer will respond with an encrypted channel.

Please include:

- A clear description of the issue and its impact
- Step-by-step reproduction
- Affected commit / version
- Your assessment of severity (Critical / High / Medium / Low)
- Whether you intend to disclose publicly, and on what timeline

We aim to:

- Acknowledge your report within **72 hours**
- Provide an initial assessment within **7 days**
- Ship a fix or mitigation within **30 days** for High/Critical issues

We will credit you in the release notes unless you ask us not to.

## Scope

In scope:

- The Flutter app in this repository
- The BLE wire format, signature verification, and dedupe logic
- Authentication, JWT handling, and secure storage usage
- Backend integration touchpoints

Out of scope (please report to the relevant project upstream):

- Vulnerabilities in third-party Flutter plugins (`flutter_blue_plus`, `ble_peripheral`, etc.)
- Vulnerabilities in the Echo backend — see [`echo-backend/SECURITY.md`](../echo-backend/SECURITY.md)
- Generic Android OS or vendor BLE-stack issues

## Hardening posture

Echo already implements:

- **Ed25519 packet signing** — every relay verifies the originator before forwarding (`lib/crypto/ed25519.dart`, `lib/mesh/packet_codec.dart`).
- **RS256 rescuer-JWT verification** with a hard-coded admin public key (`lib/auth/auth_service.dart`).
- **Replay protection** via `messageId` + `expiresAt` + per-peer dedupe table (`lib/database/`).
- **Secrets in `flutter_secure_storage`** — never `SharedPreferences`.
- **Firebase App Check** required on backend ingest in production.
- **No PII in logs** in release builds.

If you find a way around any of the above, we *especially* want to hear from you.

## Responsible disclosure

We follow a 90-day coordinated-disclosure window by default and are happy to negotiate longer for systemic issues.

Thank you for helping keep Echo — and the people who depend on it — safe.
