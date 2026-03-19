---
description: Create a structured ticket from provided context
---
Based on the information provided in this conversation (links, pasted content, discussion, requirements, etc.), create a work ticket using the structure below.

Guidelines:
- The **What** section describes the problem being solved and, if not self-evident, why we are solving it. This is a high-level description — not implementation steps.
- **Acceptance Criteria** are testable, observable outcomes that confirm the work is complete.
- **Definition of Done** is a checklist of technical completion signals (tests passing, deployed, etc.). Do NOT include obvious process steps like "changes reviewed and merged" — these are implied.
- Keep bullet points concise. Avoid detailing exact implementation steps unless the provided context explicitly describes them.
- Use judgment on code references — include only if they meaningfully orient the implementer.
- Always use `-` for bullet points, never `- [ ]` checkboxes.

Output steps:
1. Suggest a short ticket title (1 line, easy to copy).
2. Show the proposed ticket markdown (do not copy yet).
3. Ask: "Shall I copy this to your clipboard, or would you like any changes first?"
4. Once approved, copy the markdown to clipboard using: pbcopy

Ticket format:
### What
- ...

### Acceptance Criteria
- ...

### Definition of Done
- ...
