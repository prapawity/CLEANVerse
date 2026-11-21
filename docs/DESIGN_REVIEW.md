# Design, UI/UX, and frontend review

Apply this review to each change, proportionate to its impact. The owner has requested that design, UI/UX, and frontend concerns be checked throughout development.

## Skill workflow

1. Before work, consult the `design`, `ui-ux-pro-max`, and `frontend-design` skills if available. Use their instructions where applicable, and identify the actual Flutter stack. If a skill is unavailable, use this checklist and state the limitation.
2. Read existing product, safety, and architecture decisions. Describe any proposed changes to the user experience before changing established direction. Do not claim an unapproved style guide is final.
3. Check the result after implementation; run appropriate widget and behavior tests. When the environment supports it, inspect the actual app at desktop and mobile sizes with normal and larger text; distinguish real screenshots from mockups and disclose any test-rendering substitutions.
4. Record in the change summary which checks were performed, relevant limitations, and any issue that remains. For a non-visual change, briefly assess user-facing behavior and explain why visual testing is not relevant.

## Review checklist

- **Trust and clarity:** clearly distinguish real scans from examples, explain permissions and scope, and never imply that unavailable functionality works. Report partial results and errors accurately.
- **Visual design:** use a coherent hierarchy, readable typography and spacing, deliberate color choices and consistent components. Keep text and labels specific to the task.
- **Accessibility:** readable contrast, text scaling, meaningful semantic labels, visible focus, keyboard access, and sufficiently large touch targets. Do not depend on color alone.
- **Interaction:** verify empty, loading, cancellation, success, failure, disabled and partially completed states where applicable. Test long paths and narrow windows without overflow.
- **Platform fit:** adapt behavior to each platform's actual capabilities and permissions. Never make mobile appear to provide desktop-only features.
- **Privacy and safety:** check sensitive paths, confirmation language, recoverability and cloud-sync implications against `SAFETY.md`.

## Current state

The initial Flutter screen is an early functional prototype, not an approved visual identity. Its desktop preview contains an example scan and a separate read-only folder scan. Mobile support and broader accessibility validation remain unverified. Define and review a visual direction before undertaking a full redesign.
