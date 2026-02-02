import './globals.css'
import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import { MsalProvider } from './MsalProvider'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'Foundry MCP Handson',
  description: 'Azure AI Foundry Agent with MCP Tools',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <MsalProvider>
          {children}
        </MsalProvider>
      </body>
    </html>
  )
}
