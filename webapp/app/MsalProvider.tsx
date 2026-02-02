'use client';

import { MsalProvider as MsalReactProvider } from '@azure/msal-react';
import { PublicClientApplication } from '@azure/msal-browser';
import { msalConfig } from '@/lib/authConfig';
import { useMemo } from 'react';

export function MsalProvider({ children }: { children: React.ReactNode }) {
  const msalInstance = useMemo(() => {
    return new PublicClientApplication(msalConfig);
  }, []);

  return (
    <MsalReactProvider instance={msalInstance}>
      {children}
    </MsalReactProvider>
  );
}
