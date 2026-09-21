# Production Firebase Android configuration

> [!NOTE]
> **BEGINNER NOTE: Environment Separation & Deployment Independence**
> 1. **Project Isolation**: PaperRoute maintains two entirely distinct Firebase projects:
>    - `paperroutedev`: Used for active feature testing and development.
>    - `paperroute-production`: Houses live business and user data.
> 2. **Never Mix Client Files**: `google-services.json` contains project IDs and client API keys tailored to specific package IDs. Mixing them causes dev builds to write to prod or prod builds to fail App Check.
> 3. **Firebase Deploy vs Git Deploy**:
>    - Git commits update source code and app bundles.
>    - Firebase deployments (`firebase deploy --only firestore:rules,firestore:indexes --project <project>`) update live server-side database rules and indexes immediately. These are separate operations that must be coordinated deliberately.

This flavor intentionally has no Firebase client configuration yet. After the
separate production project is approved and created, register Android package
`in.paperroute.paper_route.prod` and place the downloaded public client file at:

`android/app/src/production/google-services.json`

The file is not a service-account credential, but it must identify the approved
production project. Run `node tool/validate_release_config.mjs --production`
before any production build. Never copy the PaperRouteDev file into this folder.
