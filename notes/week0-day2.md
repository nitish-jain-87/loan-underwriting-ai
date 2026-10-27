# Day 2 — Raw HTTP to LLMs: concepts and answers

Your own numbers are in `experiments/day2/responses/`. Where an answer says "your numbers", open that file and check that it matches the explanation. If it doesn't, tell me. A mismatch is more interesting than a match.

---

## The one mental model behind everything today

An LLM API call is a **stateless function**:

```
response = model(all_the_text_you_send, sampling_settings)
```

- The model reads your input as **tokens** and predicts output **one token at a time**.
- Each predicted token is **sampled** from a probability distribution. **Temperature** controls how random that sampling is.
- It can only see a fixed number of tokens at once: the **context window**.
- It remembers **nothing** between calls. "Chat" is the client re-sending the history.
- You pay, and you wait, **per token**: input tokens are cheap and fast, output tokens are expensive and slow.
- System, user and assistant "roles" are just labelled text in the same input. **They are not a permission system.**

Every question below is one consequence of this model.

---

## Q1 Tokens

**What a token is:** the unit the model actually reads and writes. It's a sub-word chunk taken from a fixed vocabulary. Rough English rule of thumb: 1 token ≈ 4 characters ≈ ¾ of a word. `"underwriting"` might be 2–3 tokens, and `" the"` is 1. Numbers and IDs tokenize badly: `25000` or `BLUE-42` can each be several tokens.

**Why Ollama (01) and OpenAI (07) counted the same prompt differently:**
1. **Different tokenizers.** Every model family has its own vocabulary: Qwen3 has ~151k entries and OpenAI's models have their own. The same sentence gets split differently, so the count differs.
2. **Different chat-template overhead.** Before the model sees your messages, they get wrapped in special role markers (Qwen uses `<|im_start|>user ... <|im_end|>`). The provider may also add hidden formatting or system tokens. You're billed for those too.

**Why it matters in the project:** cost, rate limits (OpenAI limits you in tokens per minute, not requests), context limits and latency are all measured in tokens. A token count is only valid **for one specific model**. If you switch providers, your budgets and your truncation guards have to be recalculated.

---

## Q2 Thinking

**What happened:** with `think: true`, Qwen3 generates a hidden reasoning section (`message.thinking`) before the answer. Those are real generated tokens, so they appear in `eval_count`. **Your numbers:** compare `eval_count` and `total_duration` between 01 and 02. Expect thinking to multiply the generated tokens, and therefore the time, by several times for a question that needed no reasoning at all.

**Cost:** output tokens are the slow part, since each one is a full forward pass through the model. On a paid API, reasoning tokens are **billed as output tokens** even though you never see them in the answer. OpenAI reports them under `usage.completion_tokens_details.reasoning_tokens`.

**What you lose by turning it off:** quality on multi-step problems, for example "given these 6 rules and this applicant, which rules fail and why?"

**Engineering rule:** choose per call, not globally.
- Extraction, classification, formatting: **think off**.
- A genuinely multi-step decision: **think on**, with a token cap (`num_predict` in Ollama, `max_completion_tokens` in OpenAI) and a timeout.

---

## Q3 Slow warm call (the Day 1 mystery)

Your three diagnostic numbers:

| Signal | Where | What it tells you |
|---|---|---|
| PROCESSOR | `ollama ps` | `100% GPU` = fast. `100% CPU` or a CPU/GPU split = the model doesn't fit in VRAM, so generation is 5–20x slower |
| `load_duration` | API response (ns) | Large on a *warm* call means the model was unloaded between calls (default `keep_alive` is 5 min) |
| tokens/s | `eval_count / eval_duration × 1e9` | Raw generation speed of your hardware |

**The cause:** on Day 1 you sent a tiny prompt with thinking on (Qwen3's default). The model generated a few hundred thinking tokens before saying "hi" back. `time ≈ eval_count ÷ tokens_per_sec`. For example, 300 tokens at 40 tok/s ≈ 7.5 s, which is your "8 s warm call". If your PROCESSOR showed CPU, that adds to it: fewer tok/s × more tokens.

**Look at your 01 vs 02 durations:** if 01 (think off) is fast, thinking was the main cause. If 01 is still slow, it's the hardware (CPU).

**Lesson:** latency = (input tokens × prefill speed) + (**output tokens × generation speed**). The second term almost always dominates. To make an LLM call faster, **generate fewer tokens**.

---

## Q4 Statelessness

**Where memory lives:** in **your application**, never in the model. 03b failed because the model had never seen 03a. 03c worked because *you* re-sent turn 1 inside the request. "Chat memory" is just the client appending to a list and re-sending all of it.

**Your numbers:** `prompt_eval_count` in 03c is bigger than in 03b by roughly the size of turn 1 plus its answer.

**At turn 30:** every call re-sends turns 1–29. Input size grows linearly per call, so **total conversation cost grows roughly quadratically**. Latency grows too, because the model has to process the whole prompt, and eventually you hit the context window.

**Ways to contain it:**
1. **Sliding window:** keep only the last N messages.
2. **Summarization:** replace old turns with a short summary.
3. **Structured state (the best fit for loans):** put the extracted facts (amount, income, employer) into your DB or a Java record. Send those few lines, not the whole transcript.
4. **Prompt caching:** keep the stable prefix (system prompt and policy) identical so the provider can bill it at a cached, cheaper rate.

Spring AI's `ChatMemory` (Day 4) is option 1 with a pluggable store. Now you know what it does on the wire.

---

## Q5 Temperature

**What it is:** at every step the model produces a probability for every token in its vocabulary. Temperature rescales those probabilities before sampling:
- **0:** always pick the most likely token (greedy). Near-identical output on every run.
- **~0.7:** the usual chat default, with some variety.
- **1.5:** flattens the distribution, so unlikely tokens get picked. Creative, then increasingly incoherent.

(`top_p` and `top_k` are related knobs that cut off the unlikely tail. Leave them at their defaults.)

**Your numbers:** at 0, the 5 names should be identical or nearly so. At 1.5, they should all be different.

**For loan field extraction:** **temperature 0**, or as low as the provider allows. You want the same application to produce the same extracted fields every time, so that bugs are reproducible and audits are explainable.

**Is 0 guaranteed deterministic? No.** Floating-point nondeterminism on GPUs, request batching on the provider side, and silent model updates can all change the output. Some newer OpenAI reasoning models don't accept the parameter at all. So for compliance:
- validate every output against a schema,
- **log the input, the output and the exact model version**,
- never claim "the model will always say X".

---

## Q6 Context window

**What it is:** the maximum number of tokens the model can attend to in one call, **input + output combined**. `num_ctx` is how much memory Ollama allocates for that window. Bigger = more RAM/VRAM and slower. The default depends on the Ollama version, so always set it explicitly.

**What happened at 256 (your 06a):** your prompt was ~500+ tokens. Ollama **silently truncated** it, so `prompt_eval_count` ≤ 256. Ollama keeps the end of the prompt (the question) and drops the beginning, which is where `BLUE-42` was. The model either said it didn't know or **made up a code**. There was no error and the HTTP status was 200. At 4096 (06b), the full prompt was counted and the answer was correct. (If your 06a returned an error instead, your Ollama version fails loudly. That's better, but don't count on it.)

**OpenAI behaves differently:** a prompt that's too long gets an HTTP 400 `context_length_exceeded`, which fails loudly. **Providers are inconsistent**, and that matters when you build provider fallback.

**Why silent truncation is dangerous on a 40-page loan file:** the dropped part could be the income or the liabilities section. The model still returns a confident, well-formatted decision based on partial data, and nothing in your logs shows it. That's a wrong credit decision with no trace.

**Where the guard goes:** in **your service layer, before the call**. Estimate the tokens of the assembled prompt. If it's over budget (window − reserved output tokens − safety margin), don't send it: chunk it, summarize it, retrieve only the relevant sections (RAG, Week 2), or reject it. **After the call**, assert that the provider's reported prompt tokens match your estimate. Treat context size like a DB connection pool limit: a hard constraint that you check, not something you hope for.

---

## Q7 Prompt injection

**What happened:** results vary by run and by model. Small local models obey injected instructions more often, and larger hosted models resist more. If either one ever replied `APPROVED`, you've seen the vulnerability. If neither did across 3 runs, that's not proof of safety.

**Why it works:** the system prompt and the user's text end up in **one token stream**. There's no hardware or protocol separation between "instructions" and "data", the way a SQL parameter is separated from the query. The model is just predicting likely text, and a forceful instruction in the data can win.

**Is the system prompt a security boundary? No.** It's a strong suggestion. Treat it like client-side validation: useful, never sufficient.

**Controls that don't depend on the model obeying:**
1. **The model has no authority.** An LLM never approves a loan. It extracts and summarizes. **Deterministic Java code or a rules engine makes the decision.** "APPROVED" from the model means nothing if no code path acts on it.
2. **Strict output validation:** the extraction must parse into a typed record (`LoanRequest(BigDecimal amount)`). Anything else is rejected.
3. **Least privilege for tools (Day 4):** the intake agent simply has no `approveLoan` tool.
4. Human review for high-impact actions, and input delimiting/filtering as defence in depth.

**Interview line:** *"I treat LLM output as untrusted user input and I never give the model authority over a decision."*

---

## Q8 Cost

**Formula:**
```
cost = input_tokens × input_price / 1,000,000  +  output_tokens × output_price / 1,000,000
```
Prices are per **1M tokens** and change often. Look up your exact model on OpenAI's pricing page: https://developers.openai.com/api/docs/pricing

**Call 07:** roughly 20–40 input and 20–60 output tokens, which comes to **a few hundredths of a cent**. Use your own `usage` numbers.

**10,000 applications/day × 2,000 input + 500 output tokens, for 30 days:**
- 300,000 applications per month
- Input: 300k × 2,000 = **600M tokens**. Output: 300k × 500 = **150M tokens**.

Worked example with **illustrative** prices (replace them with your model's real ones):

| Model tier (example price in / out per 1M) | Input | Output | **Monthly** |
|---|---|---|---|
| Cheap "mini" tier ($0.25 / $2.00) | $150 | $300 | **$450** |
| Frontier tier ($10 / $50) | $6,000 | $7,500 | **$13,500** |

**What dominates:** **output**, even though it's only ¼ of the tokens, because output is priced 4–8x higher than input. And **model choice** is a ~30x lever, far bigger than any prompt tweak.

**What multiplies this in real systems:** reasoning tokens (billed as output), retries, multi-agent pipelines where one application means 5–10 LLM calls, and growing chat history (Q4). An agentic underwriting flow can easily cost 10x the naive estimate.

**Controls (later weeks):** use a cheap model for extraction and an expensive one only for hard reasoning (model routing), cap output tokens, use prompt caching, set per-tenant budgets and rate limits, and log `usage` on every call so finance can see cost per application.
