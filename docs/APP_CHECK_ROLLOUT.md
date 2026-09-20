# Firebase App Check rollout

App Check is defense in depth; it does not replace Authentication or Firestore
Rules. No provider or enforcement is enabled by this repository change.

1. Register Android production with Play Integrity and Web production with
   reCAPTCHA Enterprise or the currently supported Firebase-recommended Web
   provider. Re-check provider quotas/costs before enabling; remain on free
   options unless billing is separately approved.
2. Use only App Check debug tokens for local emulators and explicitly registered
   development devices. Store debug tokens as secrets, never in Git.
3. Ship a production build with token acquisition enabled but enforcement off.
   Monitor valid, outdated, and invalid request ratios for at least one normal
   operating cycle and verify older supported app versions.
4. Resolve legitimate failures, define an emergency disable owner, and record a
   rollback window. Obtain explicit approval.
5. Enforce Firestore first during a low-risk window; observe authentication and
   core workflows. Enforce other supported products separately. Disable
   enforcement immediately if verified clients are blocked.

Development and production App Check registrations and metrics must never be
mixed. Emulator use stays local and must not require a production token.
