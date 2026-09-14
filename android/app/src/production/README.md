# Production Firebase Android configuration

This flavor intentionally has no Firebase client configuration yet. After the
separate production project is approved and created, register Android package
`in.paperroute.paper_route.prod` and place the downloaded public client file at:

`android/app/src/production/google-services.json`

The file is not a service-account credential, but it must identify the approved
production project. Run `node tool/validate_release_config.mjs --production`
before any production build. Never copy the PaperRouteDev file into this folder.
