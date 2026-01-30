# Simulating OLM Upgrades for Development

This document helps you choose the right approach for simulating OLM upgrades during development.

## Choose Your Approach

### ✅ With Personal Registry (Recommended)

**Use this if you have:** Registry access (e.g., `registry.tannerjc.net`, `quay.io`, etc.)

**Advantages:**
- More production-like workflow
- Persistent bundle images
- Can create real catalogs
- Easy to share and debug
- Simpler command flow

**See:** [UPGRADE-HACK-REGISTRY.md](./UPGRADE-HACK-REGISTRY.md)

### ⚡ Without Registry (Quick Testing)

**Use this if:** You don't have registry access and need quick testing

**Advantages:**
- No registry setup required
- Quick to get started
- Uses make targets

**Trade-offs:**
- Less production-like
- Temporary bundles
- Can't easily share

**See:** [UPGRADE-HACK-NO-REGISTRY.md](./UPGRADE-HACK-NO-REGISTRY.md)

## Quick Comparison

| Feature | With Registry | Without Registry |
|---------|---------------|------------------|
| Production-like | ✅ Yes | ⚠️ Somewhat |
| Bundle persistence | ✅ Persistent | ❌ Temporary |
| Can build catalogs | ✅ Yes | ❌ No |
| Shareable | ✅ Yes | ❌ No |
| Registry required | ⚠️ Yes | ✅ No |
| Setup complexity | ⚠️ Medium | ✅ Simple |

## Related Documentation

- **OLM-UPGRADES.md**: Deep dive into how OLM upgrades work internally
- **ODH-UPGRADE-HYPOTHESIS.md**: What happens during v2.25.0 → v3.0.0 upgrade
- **UPGRADE-HACK-REGISTRY.md**: Detailed instructions for registry-based approach
- **UPGRADE-HACK-NO-REGISTRY.md**: Detailed instructions for no-registry approach
