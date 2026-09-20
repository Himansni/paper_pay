# Production UX and accessibility review

The Phase 8 review focused on operational risk rather than visual redesign.

| Area | Verified behavior / change | Remaining validation |
|---|---|---|
| Mobile and outdoor reading | Darkened secondary text from `#627D98` to `#486581` (WCAG AA contrast on white); retained large address, landmark, house and outstanding-balance hierarchy | Check representative low-end devices in direct sunlight |
| Large text | Shared actions retain padded 48dp targets and a 2x text-scale widget regression passes | Manual Android font-size/display-size sweep before release |
| Tap targets | Text, outlined and icon buttons now have shared 48dp minimums; primary filled actions remain 52dp | Check dense platform navigation on smallest supported screen |
| Keyboard/forms | Existing validation, input types, next/done actions, scrolling forms and explicit save actions remain in place | Manual hardware/software keyboard pass on production candidate |
| Loading/empty/error | Connected pages retain loading cards, actionable empty states, validation messages and retry controls | Test airplane-mode recovery on release device |
| Role navigation | Authoritative membership still selects Head/Employee destinations and hides Head-only reporting, settings and financial mutation from employees | Repeat two-role release-candidate smoke test |
| Daily Pricing | Region context, date selection, load/error states, newspaper rows and audited corrections remain explicit | Test with actual catalog volume in approved production tenant |
| Collections | Outstanding is labelled server-confirmed; QR is explicitly a request, not receipt; confirmation and reversal show success only after server readback | Live receipt needs real funds or an approved test transaction mechanism |

Financial actions must not use optimistic success. A timeout or offline result is
uncertain, not confirmed. The existing deterministic IDs and bounded read-back
recovery remain the approved retry mechanism.
