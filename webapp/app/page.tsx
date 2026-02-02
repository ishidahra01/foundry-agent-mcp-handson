'use client';

import { useState } from 'react';
import { useMsal } from '@azure/msal-react';
import { loginRequest } from '@/lib/authConfig';
import styles from './page.module.css';

interface Message {
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
}

export default function Home() {
  const { instance, accounts } = useMsal();
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);

  const handleLogin = async () => {
    try {
      await instance.loginPopup(loginRequest);
    } catch (e) {
      console.error(e);
    }
  };

  const handleLogout = () => {
    instance.logoutPopup();
  };

  const sendMessage = async () => {
    if (!input.trim() || loading) return;

    const userMessage: Message = {
      role: 'user',
      content: input,
      timestamp: new Date(),
    };

    setMessages((prev) => [...prev, userMessage]);
    setInput('');
    setLoading(true);

    try {
      // Get access token
      const tokenResponse = await instance.acquireTokenSilent({
        ...loginRequest,
        account: accounts[0],
      });

      // Call the chat API
      const response = await fetch('/api/chat', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${tokenResponse.accessToken}`,
        },
        body: JSON.stringify({ message: input }),
      });

      const data = await response.json();

      const assistantMessage: Message = {
        role: 'assistant',
        content: data.response || 'No response received',
        timestamp: new Date(),
      };

      setMessages((prev) => [...prev, assistantMessage]);
    } catch (error) {
      console.error('Error sending message:', error);
      const errorMessage: Message = {
        role: 'assistant',
        content: `Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
        timestamp: new Date(),
      };
      setMessages((prev) => [...prev, errorMessage]);
    } finally {
      setLoading(false);
    }
  };

  const isAuthenticated = accounts.length > 0;

  return (
    <main className={styles.main}>
      <div className={styles.container}>
        <h1 className={styles.title}>Foundry MCP Handson</h1>
        
        {!isAuthenticated ? (
          <div className={styles.loginSection}>
            <p>Please sign in to use the chat</p>
            <button onClick={handleLogin} className={styles.button}>
              Sign In with Microsoft
            </button>
          </div>
        ) : (
          <>
            <div className={styles.userInfo}>
              <p>Signed in as: {accounts[0].username}</p>
              <button onClick={handleLogout} className={styles.buttonSecondary}>
                Sign Out
              </button>
            </div>

            <div className={styles.chatContainer}>
              <div className={styles.messages}>
                {messages.length === 0 ? (
                  <p className={styles.emptyState}>
                    Send a message to start chatting with the Foundry Agent
                  </p>
                ) : (
                  messages.map((msg, idx) => (
                    <div
                      key={idx}
                      className={
                        msg.role === 'user' ? styles.userMessage : styles.assistantMessage
                      }
                    >
                      <div className={styles.messageHeader}>
                        <strong>{msg.role === 'user' ? 'You' : 'Agent'}</strong>
                        <span className={styles.timestamp}>
                          {msg.timestamp.toLocaleTimeString()}
                        </span>
                      </div>
                      <div className={styles.messageContent}>{msg.content}</div>
                    </div>
                  ))
                )}
                {loading && (
                  <div className={styles.assistantMessage}>
                    <div className={styles.messageHeader}>
                      <strong>Agent</strong>
                    </div>
                    <div className={styles.messageContent}>Thinking...</div>
                  </div>
                )}
              </div>

              <div className={styles.inputContainer}>
                <input
                  type="text"
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && sendMessage()}
                  placeholder="Type your message..."
                  className={styles.input}
                  disabled={loading}
                />
                <button
                  onClick={sendMessage}
                  disabled={loading || !input.trim()}
                  className={styles.button}
                >
                  Send
                </button>
              </div>
            </div>
          </>
        )}
      </div>
    </main>
  );
}
