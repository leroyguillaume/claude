---
name: ollama-conventions
description: >-
  Picking a model for Ollama or local inference.
  TRIGGER when: setting up Ollama; code or compose files that pull or run an
  Ollama model (`ollama pull`/`run`, `/api/chat`, `/api/generate`,
  `/api/embed`, `OLLAMA_*`, a `Modelfile`); choosing a local model tag; user
  asks which model to use with Ollama or self-hosted LLMs.
  SKIP when: a hosted provider only, or the user already chose the model.
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

1. **Search the web** for current benchmarks and the latest releases, and
   cross-check several sources when the choice is high-stakes. Cover at least:
   - The **task** the user actually has — code, chat, reasoning, RAG/retrieval,
     embeddings, vision, tool/function calling, long context, non-English.
     A model that tops a chat leaderboard can be mediocre at code.
   - **Recent leaderboards and evals**: LMArena, Artificial Analysis,
     LiveBench, task-specific evals (HumanEval / MBPP / LiveCodeBench / SWE-bench
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
   "as of <month/year>" — in the reply, so it's clear the data has a shelf
   life.
4. **Pin an exact tag.** Recommend and hard-code a concrete, reproducible tag
   (e.g. `qwen2.5-coder:7b-instruct-q4_K_M`), never a floating `:latest`.

If web access is unavailable, **say so** and flag that the suggestion is from
possibly-stale memory — don't present a remembered model as a current best.

## Plumbing conventions

- **Configuration via env vars.** Always honour `OLLAMA_HOST` and the
  standard `OLLAMA_*` names as they are — they are upstream's, not yours to
  rename or prefix. Name your own surrounding config by who owns the
  environment: bare (`DATABASE_URL`, `LOG_LEVEL`) for a service that owns it,
  prefixed with the tool's name (`MYTOOL_LOG_LEVEL`) for a CLI that shares a
  shell with everything else — and read only that one name.
- **Don't pin `:latest`.** Always use an explicit, reproducible model tag in
  code, compose files, Modelfiles, and docs.
- **Document the choice.** When you commit a model tag, leave a one-line note
  (in `README.md` or a comment) of *why* in terms of the task it serves. The
  benchmark snapshot and its date go in the commit message or PR description,
  never in the file — a dated ranking in a doc is stale the week it lands.
- **Embeddings go through `/api/embed`**, which takes a batch `input`;
  `/api/embeddings` is superseded upstream.
