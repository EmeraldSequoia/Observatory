# Emerald Observatory

## Future feature ideas

- **Phase on a rotary** (from Bill's review): stepping by Phase could choose its target — next
  phase, New, First Quarter, Full, Third Quarter — on a rotary around the ◀ ▶ pair, like the body dial
  that rise / set / transit get.
- **Hold-to-scrub for the astronomical units**: rise, set, transit and phase are tap-only by design (each
  tap is one search). Commit `a04dc13` (reverted by `e87e8b6`) made them hold, scrub one search
  per tick, and lock hands-free like the calendar units; `git revert e87e8b6` brings it back.
  Untested on a device: watch the search cost at 20 per second, and whether that rate is too fast to follow.
