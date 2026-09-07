---
name: python-async-conventions
description: >-
  Python asyncio conventions for loops and fan-out — an `await` inside a `for`
  loop is sequential and usually a latency bug, but `asyncio.gather` is not a
  free swap: it drops short-circuiting, changes failure handling, and unbinds
  results from the items that produced them. Covers picking the axis to
  parallelise on, `gather` vs `TaskGroup`, bounding concurrency, and the tests
  that catch an over-eager fan-out.
  TRIGGER when: writing or editing an `async def` that loops; `await` appears
  inside a `for`/`while` body; calling the same coroutine once per item (per
  host, per file, per worker); introducing or reviewing `asyncio.gather`,
  `TaskGroup`, `as_completed`, `create_task` or a `Semaphore`; a fan-out or a
  batch; the user reports something slow, hanging, firing more requests than
  expected, or logging "Task exception was never retrieved".
  SKIP when: the code is synchronous, or the async code has no loop and no
  concurrency.
---

# Python async: loops and fan-out

Two mistakes, and the second is the one made while fixing the first.

## 1. `await` in a loop is sequential

```python
for host in hosts:
    results[host] = await fetch(host)      # one at a time
```

Nothing here overlaps. The wall-clock cost is the **sum** of every iteration,
and with a per-request timeout it is the sum of the timeouts when hosts are
down. That is invisible in a test against a mocked transport, where every call
returns instantly — it only shows up in production, as latency somebody else
pays.

Treat `await` inside a loop body as a finding whenever the iterations are
independent, and say what it costs in the comment or the commit message
(*"O(N) round trips where the caller pays the sum"*), not just that it is
"slow".

## 2. `gather` is not a drop-in replacement

Swapping the loop for `asyncio.gather` changes three things at once. Each has
bitten real code.

**It drops short-circuiting.** Two awaits in sequence often encode a
dependency: the second only makes sense if the first succeeded.

```python
catalog = await fetch_catalog(host)        # fails -> the host is out
rails = await fetch_guardrails(host)       # never reached, deliberately
```

Gather those two and the second call fires at a host already known to be
unreachable — a wasted request, a second timeout, and a log line about a host
nobody is going to use. **The dependency was the `await` order, and gather
erases it.**

**It changes failure handling.** Without `return_exceptions=True`, the first
exception propagates immediately while the sibling coroutines keep running,
unawaited. Their results are dropped and their exceptions surface later as
`Task exception was never retrieved`, out of context. With
`return_exceptions=True` nothing is raised at all, so every result must be
`isinstance(..., BaseException)`-checked before use — forget one and an
exception object gets treated as data.

**It unbinds results from their inputs.** `gather` returns a positional list.
Re-pairing it with the inputs by hand is where results get attributed to the
wrong item:

```python
results = await asyncio.gather(*(one(h) for h in hosts), return_exceptions=True)
for host, result in zip(hosts, results, strict=True):   # strict, always
    ...
```

`strict=True` is not optional — it is what turns a length mismatch into an
error instead of silently truncating.

## The rule: pick the axis

**Parallelise across independent units; stay sequential within a dependent
chain.** Almost every fan-out has both axes, and the fix is to name them:

```python
async def for_one_host(host: str) -> tuple[Catalog, Guardrails]:
    # Sequential on purpose: a host whose catalog is unreachable is not asked
    # for anything else -- the pass is over for it either way.
    return await fetch_catalog(host), await fetch_guardrails(host)

# Concurrent across hosts: this is where the N is.
results = await asyncio.gather(
    *(for_one_host(h) for h in hosts), return_exceptions=True
)
```

The latency goes from O(2N) to O(2), which was the whole point, and the
short-circuit survives, which the naive gather destroyed.

## `gather` or `TaskGroup`

- **`asyncio.gather(..., return_exceptions=True)`** when you want *a verdict per
  unit* and one failure must not affect the others — a fan-out that reports what
  happened on each host. This is the common case for anything user-facing.
- **`asyncio.TaskGroup`** (3.11+) when the work is all-or-nothing: a failing
  child cancels its siblings and the group raises an `ExceptionGroup`. Prefer it
  over bare `gather()` without `return_exceptions`, which leaks the siblings.
- **`as_completed`** only when results are processed as they land and their
  order genuinely does not matter. It is the easiest of the three to get wrong.

Never leave a bare `create_task` without holding a reference to it: the event
loop only keeps a weak reference, so the task can be garbage-collected
mid-flight.

## Bound the concurrency

`gather` over an unbounded list opens every connection at once — a thousand
records is a thousand simultaneous sockets, and the remote end reads it as an
attack. Bound it as soon as the input is not a short, fixed list:

```python
limit = asyncio.Semaphore(10)

async def one(item: Item) -> Result:
    async with limit:
        return await work(item)
```

Hold a lock for the smallest possible span, and never across a whole loop — a
per-item lock taken inside the coroutine keeps the fan-out concurrent, while a
lock around the `gather` makes it sequential again with extra steps.

## Never block the loop

A synchronous call inside a coroutine stops **every** task, not just this one:
`requests`, `time.sleep`, a blocking DB driver, a large `json.loads`, any
filesystem read. Use the async client (`httpx.AsyncClient`, `asyncio.sleep`) or
push the call to `asyncio.to_thread`. A fan-out built on a blocking client is
sequential no matter how it is scheduled.

## Test the requests, not just the result

An over-eager fan-out usually returns the *right answer* — it just did more work
to get there, which no assertion on the return value can see. Assert on the
calls actually made:

- a mocked transport configured to fail on unexpected requests
  (`pytest_httpx` does this by default) is what catches a gather that fired at a
  host it should have skipped;
- for a dependency chain, assert the second call did **not** happen when the
  first failed;
- for ordering guarantees, assert on the recorded request sequence.

**Never:**

- Never `await` in a loop over independent items without saying why it is
  sequential.
- Never swap a loop for `gather` without checking whether the sequence encoded a
  dependency.
- Never call `gather` without either `return_exceptions=True` and a
  `BaseException` check on every result, or a `TaskGroup`.
- Never `zip` gather results back to their inputs without `strict=True`.
- Never fan out over an unbounded collection without a semaphore.
- Never put a blocking call in a coroutine.
