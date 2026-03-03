import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Nftables Panel',
  description: 'Serverless Forwarding Panel',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <script src="https://cdn.tailwindcss.com"></script>
        <script dangerouslySetInnerHTML={{__html: `tailwind.config = { darkMode: 'class', theme: { extend: { colors: { primary: '#3b82f6' } } } }`}} />
        {/* 👇 加上这一行来加载 Material 符号图标 */}
        <link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL,GRAD@20..48,100..700,0..1,-50..200" rel="stylesheet" />
      </head>
      <body className="bg-gray-50 dark:bg-gray-900 text-gray-900 dark:text-gray-100 min-h-screen">
        {children}
      </body>
    </html>
  )
}
