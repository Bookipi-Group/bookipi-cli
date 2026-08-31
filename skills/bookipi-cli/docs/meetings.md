# Meetings & Transcripts

Read this for any request about **meetings, transcripts, AI summaries, or "what was said / decided / actioned"** in a meeting. For scheduling/calendar status questions, the pre-check in `SKILL.md` (rule #8) is enough.

## Pre-flight — do NOT gate meetings on Google Calendar

**Recorded meetings, transcripts, and AI summaries come from Bookipi's meeting
recorder and exist independently of Google Calendar.** A user with
`isGoogleCalendarConnected: false` can still have (and you can still list) their
meetings — verified: on such an account `bookipi meeting list` returns the full
recorded set. So for any meetings/transcript/notes request, **go straight to
`bookipi meeting list`** (see windowing below). Do **not** run `calendar status`
as a gate, and never say "no meetings / can't pull notes because your calendar
isn't connected" — that's a false negative that shipped and confused a tester.

Only run `bookipi calendar status --json` for **scheduling / upcoming
calendar-event** questions ("what's on my calendar today", "is my calendar
connected"); if `isGoogleCalendarConnected` is `false` there, share the
`setupUrl`. If `meeting list` genuinely returns nothing, say so — and you *may*
note that connecting Google Calendar could surface more — but only after
actually listing.

## What counts as "a transcript"

A meeting has a **real, retrievable transcript** only when ALL of these hold on the meeting object:

- `hasAiSummary === true`, AND
- `transcription.meetingSummary.status === "completed"`, AND
- `transcription.meetingSummary.text` is a non-empty string.

Do **NOT** count these as transcripts (mention them only as context if relevant):

| State | Meaning |
|---|---|
| `enableTranscription: true`, `status: "pending"` | Toggle on, not processed yet |
| `enableTranscription: true`, `status: "failed"` | Bot ran but transcription failed — no text |
| `enableTranscription: false` / `transcription: null` | Capture was never on |

`enableTranscription` is just the toggle — it is **not** evidence a transcript exists.

## Retrieving meetings WITH transcripts ("show meetings with transcripts", "get all meeting transcripts")

The intent is "give me meetings that actually have transcripts," **not** "dump every calendar event." Search recent-first, keep only completed transcripts, and stop once you have enough.

### The gotcha (why the naive query fails) — READ THIS

- `meeting list` with no window defaults to **today only** → usually returns nothing transcribed.
- `meeting list --from <old> --to <future>` returns results **oldest-first** and **caps at 200 items per page**. Recent completed transcripts sit on the **last** pages, so a single page (even of a narrow window) silently misses the newest ones. Accounts with lots of test/automation meetings blow past 200 in just a few weeks — the 200-cap bites *inside a 30-day window*. (This is the exact bug that hid yesterday's transcript: a 30-day query returned "newest = 11 days ago" because page 1 ended before reaching the recent events, and a 365-day query returned **zero** because page 1 was entirely old, untranscribed meetings.)
- **Therefore: you MUST page through ALL `totalPages` of a window, not just page 1.** Then filter + sort client-side. Do not trust a single page to contain the newest items.

### Algorithm — collect up to N (default **5**), newest-first

1. **Pick a recent window** and **page through every page** (`page=1..totalPages`, `--limit 200`), accumulating all items. Start with the **last 30 days**; if that yields fewer than N transcripts, widen to **90** then **365 days** (each time paging through all pages).
2. **Filter** accumulated items to the "has a transcript" definition above.
3. **Sort** matches by `start` **descending** (newest first).
4. **Take the first N.** If `len(matches) > N` — or you stopped before widening to 365 days — there are **more**: tell the user and offer to pull the rest.
5. If **zero** completed transcripts exist, say so plainly, and surface any `pending`/`failed` ones as the reason (don't pretend they're transcripts).

Use the user's timezone (from the meeting `customer.timezone`, e.g. `Asia/Jakarta`) for all displayed times.

### Reference script (page through all pages → filter → sort → slice)

Set `FROM`/`TO` per window. This pages through every page, keeps only completed transcripts, sorts newest-first, and reports whether more than N exist.

```bash
python3 - <<'PY'
import subprocess, json
FROM="<ISO_start>"; TO="<ISO_now>"; N=5
def fetch(page):
    out=subprocess.run(["bookipi","meeting","list","--from",FROM,"--to",TO,
                        "--limit","200","--page",str(page),"--json"],
                       capture_output=True,text=True).stdout
    return json.loads(out)["getBookings"]
first=fetch(1); items=list(first["items"])
for p in range(2, first["pagination"]["totalPages"]+1):
    items+=fetch(p)["items"]
def has_t(m):
    t=m.get("transcription")
    if not (m.get("hasAiSummary") and t): return False
    ms=t.get("meetingSummary") or {}
    return ms.get("status")=="completed" and bool((ms.get("text") or "").strip())
hits=sorted([m for m in items if has_t(m)], key=lambda m:m["start"], reverse=True)
print("MATCHES:", len(hits), "| MORE:", len(hits)>N)
for m in hits[:N]:
    ms=m["transcription"]["meetingSummary"]
    print("==="); print("NAME:", m["name"]); print("START:", m["start"])
    print("SPEAKERS:", ", ".join(ms.get("speakerNames") or []))
    print("SUMMARY:", (ms.get("text") or "").strip())
    print("ACTIONS:");  [print("  -", a) for a in (ms.get("actions") or [])]
    print("NOTES:");    [print("  -", n) for n in (ms.get("notes") or [])]
PY
```

Pull `actions` and `notes` in full here (not just `text`) — they carry the owners, decisions, and blockers the card format below is built from. Don't truncate them.

### Presentation — STRUCTURED CARDS (required format)

Do **not** dump the raw `text` paragraph. Turn each meeting into a scannable card built from `text` (→ TL;DR), `notes` (→ decisions & blockers), and `actions` (→ owners). One card per meeting:

```
### <name> · <date, user tz> · <N> people
**TL;DR —** <one sentence: the single most important outcome, from `text`>
- **🎯 Decisions:** <key decisions/agreements from `notes`, separated by · >
- **✅ Actions:** <action *(owner)* · action *(owner)* … — owners come from the `actions` strings>
- **🚧 Blockers:** <open risks/blockers from `notes`; write "None" if there are none>
```

Rules for good cards:
- **TL;DR is one sentence** — the headline outcome, not a restatement of the agenda.
- **Pull owners** out of each action string (they're embedded, e.g. "… (Ibe / Manrick)" or "— Owner: Kevin") and render as *(Ibe/Manrick)*.
- **Dedupe & trim:** show the ~3–5 most material actions/decisions per card, not all of them. Offer the rest on request.
- Keep it tight — a card should fit in a glance, not a screen.
- After the cards, if more exist beyond N: *"There are <X> more transcripts in the last 30 days. Want the next <X>?"*
- Offer to expand any one card into its **full** action items + notes.
- Never show handles or raw `bookipi …` commands (see `SKILL.md` presentation rules).

## Full verbatim transcripts & Q&A over a meeting

The AI summary (`meetingSummary`) is enough for "what was decided / actioned." For **word-for-word** questions — who said what, exact wording, anything the summary omitted — you need the **verbatim transcript**, which lives in `transcription.utterances`:

```
transcription {
  meetingSummary { text actions notes status speakerNames }
  utterances { durationMs speakerName speakerUuid speakerUserUuid timestampMs transcription }
}
```

`utterances` is **only returned when you pass `--transcript`** to `meeting list`. Without the flag the query selects `meetingSummary` only (that's why a plain list never shows verbatim text — it's not an API limitation, just an un-requested field).

```bash
bookipi meeting list --from <ISO> --to <ISO> --transcript --json
```

### It's a heavy payload — stay tiered

One meeting's transcript can be **hundreds of utterances ≈ thousands of words ≈ ~5k tokens** (vs ~700 for its summary). Do **not** pull `--transcript` across a wide window or "all meetings" — it floods context and is slow. Instead:

1. **Breadth = summaries.** Use the normal summary flow above to find/identify meetings (cards, dates, speakers, decisions).
2. **Depth = utterances on demand.** When the user names a specific meeting or asks a who-said-what / exact-quote question, fetch **just that meeting's** transcript with `--transcript` over a **narrow window** bracketing its `start` (e.g. the meeting's day). Then answer grounded in the utterances, quoting speaker + (optional) timestamp.
3. Never load every transcript "just in case." Filter first (date / `--search "<person>"`), then deepen.

Only meetings whose transcription actually completed carry utterances; the rest return `utterances: []` (or none) — same "what counts as a transcript" rule as above.

### Auth gotcha — stale meet-app token

If a `meeting list` (especially a direct API hit) ever fails with `"Either linkId, customerId, or externalCustomerId is required"`, that is **not** a missing-filter bug — it's an **expired meet-app JWT** (short-lived, ~2h). The CLI auto-refreshes it on the next call, so just re-run the command. Don't start adding id filters to "fix" it.

### Presentation for verbatim Q&A

When answering from utterances, quote sparingly and attribute: **Speaker: "exact words"** (timestamp optional). Don't paste the whole transcript back — answer the question, cite the 1–3 relevant lines, and offer the full transcript if they want it. Same handle/command-hiding rules apply.

## Listing meetings generally (no transcript filter)

For "what's on today / my schedule / my meetings", use the default `meeting list` (today window) or `--days N` / `--from` / `--to`. To find a specific person's meetings across past+future, use `--search "<name-or-email>"` (auto-widens to past 365d + next 30d). There is no `meeting get` — filter the list output instead.
