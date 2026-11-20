---
name: council
description: >-
  Five-perspective council and a chairman's verdict on a high-stakes decision.
  TRIGGER when: the user explicitly asks for it ("council this", "run the
  council", "debate this", `/council`).
  SKIP when: any other phrasing, including "should I X or Y" (offer the council
  in one line instead); a technical choice a benchmark, doc or test can settle;
  load or stress testing; incident response; factual questions.
---

# Council

A decision with real stakes and real uncertainty goes to five advisors who
answer independently, then to a chairman who weighs them blind and gives a
verdict. Six sub-agents per run: it is slow and expensive on purpose, and only
worth it when being wrong costs more than that.

## When not to run it

Even on an explicit ask, push back in one line and stop when:

- **The answer is checkable.** A benchmark, the documentation or a test
  settles it — go and check instead.
- **There is no tradeoff.** A yes/no with an obvious answer, a factual lookup,
  or a request to *make* something rather than decide something.
- **It is urgent.** An incident needs one person acting, not a debate.

When a real decision comes up without an explicit ask, offer the council in
one line and wait for a yes. Never start it unprompted.

## 1. Frame the question

The advisors see only what you give them, so the framing decides the quality
of the run.

- Gather the context the decision depends on: the project's `CLAUDE.md`,
  `ARCHITECTURE.md`, `docs/adr/`, the relevant code, and what the user said.
- Write a **neutral** brief: the decision, the options on the table, the
  constraints (budget, team, deadlines, existing commitments), and what
  success looks like. No leaning — do not reveal which option the user or you
  prefer.
- Show the brief to the user in one block, then proceed. If the decision
  itself is unclear, ask first: a council on the wrong question is six agents
  wasted.

## 2. Convene the advisors

Launch the five in parallel, each a sub-agent on the strongest model
available — this is judgement work. Each gets the brief, its role, and the
same instruction: 150–300 words, a clear position, the single strongest
argument for it, and what would change its mind.

| Advisor | Gets | Asks |
| --- | --- | --- |
| **Contrarian** | the brief | Where does this fail? What is the most likely way it goes wrong, and how bad is that? |
| **First principles** | the brief | Is this the right problem? Strip the assumptions — what is actually needed? |
| **Expansionist** | the brief | What is the upside nobody is pricing in? What bigger option is being missed? |
| **Outsider** | the decision and options only, no project context | What would a smart person with no stake and no jargon find odd here? |
| **Executor** | the brief | What can actually be done with what exists? What is the first concrete step, and what blocks it? |

The Outsider's missing context is the point: it catches what familiarity
hides. Do not hand it the brief's background.

If the client cannot run sub-agents, say so before starting: answering all
five roles in one context loses the independence that makes the council worth
its cost.

## 3. Chairman

One more sub-agent, on the strongest model, receives the five responses
**anonymised and shuffled** (Advisor A–E, no role names) plus the brief. It
must not know which persona wrote what, so it judges arguments rather than
roles. It returns:

- **Agreement** — where the advisors converge, and whether that convergence is
  earned or just a shared assumption.
- **Clashes** — the real disagreements, and which side has the better
  argument.
- **Blind spots** — what none of them addressed.
- **Verdict** — a recommendation, with the confidence and the condition that
  would reverse it.
- **First step** — one concrete action, doable now.

All advisors run on the same model with different prompts, so their errors
are correlated: unanimous agreement is weaker evidence than it looks. The
chairman says so when it happens.

## 4. Report

- In the conversation: the chairman's output, as is, and nothing else.
- In a local Markdown file, in the session's scratchpad or temporary
  directory: the brief, the five responses with their roles, the anonymisation
  mapping and the chairman's output. Give the user its full path. Never commit
  it to the project.
