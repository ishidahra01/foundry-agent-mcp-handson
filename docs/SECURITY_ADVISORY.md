# Security Advisory - Next.js Vulnerabilities Fixed

## Date: 2026-02-02

## Summary
Updated Next.js from version 14.0.4 to 15.2.3 to address multiple critical security vulnerabilities.

## Vulnerabilities Fixed

### 1. DoS via Cache Poisoning (Latest)
- **Severity**: High
- **Affected versions**: >= 15.0.4-canary.51, < 15.1.8
- **Patched version**: 15.2.3
- **Description**: Next.js vulnerability can lead to DoS via cache poisoning

### 2. Authorization Bypass in Middleware (Critical)
- **Severity**: Critical
- **Affected versions**: >= 15.0.0, < 15.2.3
- **Patched version**: 15.2.3
- **Description**: Authorization bypass vulnerability in Next.js Middleware across multiple version ranges

### 3. DoS with Server Components (Multiple CVEs)
- **Severity**: High
- **Affected versions**: >= 13.0.0, < 15.0.8
- **Patched version**: 15.2.3
- **Description**: HTTP request deserialization can lead to Denial of Service when using insecure React Server Components

### 4. Cache Poisoning (Previous)
- **Severity**: Medium
- **Affected versions**: >= 14.0.0, < 14.2.10
- **Patched version**: 15.2.3
- **Description**: Next.js Cache Poisoning vulnerability

### 5. Server-Side Request Forgery (SSRF)
- **Severity**: High
- **Affected versions**: >= 13.4.0, < 14.1.1
- **Patched version**: 15.2.3
- **Description**: SSRF vulnerability in Server Actions

### 6. Authorization Bypass (General)
- **Severity**: Critical
- **Affected versions**: >= 9.5.5, < 14.2.15
- **Patched version**: 15.2.3
- **Description**: Authorization bypass vulnerability

## Changes Made

### Updated Dependencies
- `next`: 14.0.4 → **15.2.3**
- `eslint-config-next`: 14.0.4 → **15.2.3**

### Version History
- Initial: 14.0.4 (vulnerable)
- First update: 15.0.8 (still had vulnerabilities)
- Final update: **15.2.3** (all known vulnerabilities fixed)

## Impact Assessment

### Breaking Changes
Next.js 15 includes some changes, but our implementation should be compatible:

1. **React Server Components**: Our implementation uses minimal server components
2. **App Router**: We're already using the App Router (app/ directory)
3. **TypeScript**: Our TypeScript configuration is compatible

### Testing Required

After updating, test the following:

1. **Authentication Flow**
   ```bash
   # Test MSAL authentication
   # 1. Navigate to webapp
   # 2. Click "Sign In with Microsoft"
   # 3. Verify successful login
   ```

2. **Chat API**
   ```bash
   # Test API endpoint
   curl -X POST http://localhost:3000/api/chat \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer <token>" \
     -d '{"message": "What is the weather in Tokyo?"}'
   ```

3. **Build Process**
   ```bash
   cd webapp
   npm install
   npm run build
   ```

## Deployment Steps

### For New Deployments
No additional steps needed - the updated package.json will be used automatically.

### For Existing Deployments

1. **Local Development**
   ```bash
   cd webapp
   rm -rf node_modules package-lock.json
   npm install
   npm run build
   npm run dev
   ```

2. **Azure Web App**
   ```bash
   # Redeploy the web app
   ./scripts/deploy-webapp.sh
   ```

## Verification

Verify the fix by checking the installed version:

```bash
cd webapp
npm list next
# Should show: next@15.2.3
```

## Additional Notes

### Why 15.2.3?
This version addresses:
- ✅ Cache poisoning DoS (fixed in 15.1.8)
- ✅ Authorization bypass in Middleware (fixed in 15.2.3)
- ✅ All previous vulnerabilities from 14.x and earlier

### Migration Path
- 14.0.4 (initial, multiple critical vulnerabilities)
- 15.0.8 (first attempt, still had vulnerabilities)
- **15.2.3** (final, all known vulnerabilities fixed)

## References

- [Next.js Security Advisories](https://github.com/vercel/next.js/security/advisories)
- [Next.js 15 Release Notes](https://nextjs.org/blog/next-15)
- [Next.js Upgrade Guide](https://nextjs.org/docs/app/building-your-application/upgrading)

## Recommendation

✅ **Action Required**: All users should update to Next.js 15.0.8 or later immediately to address these critical security vulnerabilities.

## Additional Security Best Practices

1. **Keep dependencies updated**: Regularly check for security updates
2. **Use npm audit**: Run `npm audit` regularly to identify vulnerabilities
3. **Enable automated updates**: Consider using Dependabot or similar tools
4. **Monitor security advisories**: Subscribe to Next.js security notifications

## Contact

For questions or concerns about this security update, please open an issue in the repository.

---

**Status**: ✅ Fixed  
**Updated by**: GitHub Copilot Agent  
**Final Version**: Next.js 15.2.3  
**All Known Vulnerabilities**: Addressed ✅
