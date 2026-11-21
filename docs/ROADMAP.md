# Delivery roadmap

## Phase 0 — foundations (current)

Validate product boundaries and platform research. Establish project documentation, safe-development rules, and initial threat model. Keep the existing Python prototype labeled experimental; do not expand destructive functionality until the safety gate is met.

## Phase 1 — runnable Flutter foundation (in progress)

Create Flutter project with Windows, macOS, Linux, Android and iOS hosts; pin SDK and configure format/analyze/test CI. Build a capability-aware shell, accessibility baseline, navigation and honest unsupported states. Add a fake scan repository and unit/widget tests; no real file access or deletion. Build and test on available hosts; mark other platforms unverified.

## Phase 2 — read-only scan adapters

In progress: desktop folder selection, session-only path exclusions, an extension-based storage breakdown, largest-file listing, optional size/SHA-256 matching, project artifact discovery and limited global cache candidates are implemented read-only, with cancellation and partial results. Matching has a 20,000-file cap and does not identify hard links. Further work must validate native picker builds, race-resistant scope confinement, cache configurations, exclusion aliases, file identity and macOS/Linux behavior. Android: selected documents and permitted media. iOS: authorized photos and documents. Validate on named OS versions and devices. Set performance budgets after measuring representative devices.

## Phase 3 — review and recoverable removal

Complete platform-specific threat review. Implement recovery-capable operations only where verified; report per-item outcomes and skip unsupported operations. Complete the safety test matrix before a limited beta with an incident response path.

## Phase 4 — expansion

Evaluate cleanup rules, persistence, subscriptions and cloud features independently. Security scanning needs a separately qualified engine, validation and product decision.

## Release gates

A platform is supported only after its build, permissions, accessibility, failure modes and integration tests pass on named OS versions and devices. Store acceptance is not assumed. Pricing and minimum supported versions remain product decisions.

