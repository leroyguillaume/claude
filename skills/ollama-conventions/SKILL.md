---
name: ollama-conventions
description: Ollama model-selection conventions (never recommend a model from
  memory — research current benchmarks on the web first, then justify the pick).
  TRIGGER when: setting up or configuring Ollama; writing code, compose files,
  or scripts that pull/run an Ollama model (`ollama pull`, `ollama run`, the
  `/api/generate`, `/api/chat`, or `/api/embeddings` endpoints, an `OLLAMA_*`
  env var, a `Modelfile`); choosing or hard-coding a model tag for local
  inference; user asks "which model should I use" / "what's the best model
  for X" with Ollama (or local/self-hosted LLMs) in scope.
  SKIP when: the work targets a hosted provider (Anthropic/OpenAI/Gemini/
  Mistral/Cohere) with no local model involved, or you are only wiring plumbing
  around an already-chosen, user-specified model and no recommendation is asked.
---

# Ollama conventions

## Never recommend a model from memory

Local-model leaderboards move every few weeks: new releases, new quantizations,
new fine-tunes. Whatever you "remember" as the best 7B/13B/70B is almost
certainly stale. **Before you name a model, do the homework.**

When the user asks you to pick, suggest, or hard-code an Ollama model — or when
you would otherwise reach for a default tag — run a fresh benchmark study
first. This is non-negotiable for any *recommendation*; it does not apply when
the user already told you exactly which model to use.

### The study (do this before recommending)

1. **Search the web** for current benchmarks and the latest releases. Use
   `WebSearch` / `WebFetch` (or the `deep-research` skill for a thorough,
   multi-source, fact-checked report when the choice is high-stakes). Cover at
   least:
   - The **task** the user actually has — code, chat, reasoning, RAG/retrieval,
     embeddings, vision, tool/function calling, long context, non-English.
     A model that tops a chat leaderboard can be mediocre at code.
   - **Recent leaderboards and evals**: LMArena / Chatbot Arena, the Open LLM
     Leaderboard, task-specific evals (HumanEval / MBPP / LiveCodeBench / SWE-bench
     for code, MMLU / GPQA / MATH for reasoning, MTEB for embeddings, etc.).
   - **What's new on Ollama**: check the Ollama model library
     (`https://ollama.com/library`) and recent model announcements — the tag
     has to actually exist and be pullable.
2. **Match the model to the hardware.** A benchmark winner the user can't run
   is useless. Account for parameter count, the **quantization** that fits
   their VRAM/RAM (`q4_K_M`, `q5_K_M`, `q8_0`, …), and context-window needs.
   Ask for or infer the available memory if it isn't obvious.
3. **Cite what you found.** When you give the recommendation, briefly say
   *which benchmarks* and *how recent* they are, and name a runner-up. The user
   should see the evidence, not just the verdict. Note the benchmark date —
   "as of <month/year>" — so it's clear the data has a shelf life.
4. **Pin an exact tag.** Recommend and hard-code a concrete, reproducible tag
   (e.g. `qwen2.5-coder:7b-instruct-q4_K_M`), never a floating `:latest`.

If web access is unavailable, **say so** and flag that the suggestion is from
possibly-stale memory — don't present a remembered model as a current best.

## Plumbing conventions

- **Configuration via bare env vars**, no project prefix (per global rules):
  honour `OLLAMA_HOST` and the standard `OLLAMA_*` names; use `DATABASE_URL`,
  `LOG_LEVEL`, etc. for surrounding config.
- **Don't pin `:latest`.** Always use an explicit, reproducible model tag in
  code, compose files, Modelfiles, and docs.
- **Document the choice.** When you commit a model tag, leave a one-line note
  (in `README.md` or a comment) of *why* — the task and the benchmark snapshot
  it was chosen from — so the next person knows when to revisit it.
