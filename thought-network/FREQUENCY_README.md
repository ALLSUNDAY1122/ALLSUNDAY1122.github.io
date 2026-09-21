# Cross-Chat Frequency Analysis v0.1

- Method: retrieval-based lower bound
- Counts are minimum confirmed distinct chats, not exact all-history totals.
- Theme Weight = 0.50 × normalized confirmed-chat count + 0.25 × normalized duration + 0.25 × recency.
- Exact analysis requires full ChatGPT conversation export and conversation-ID deduplication.
