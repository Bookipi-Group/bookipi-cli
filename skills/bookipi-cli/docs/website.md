# Website — the company's AI-built site

Triggers: *"how's my website?"*, *"is my website live/published?"*, *"what's my
domain status?"*, *"what does my website say?"*, *"show me my website"*,
*"update my website"*, *"create a website"*.

## Commands

```bash
bookipi website status          # published state (cross-checked against real page/section count), domain + status, business info
bookipi website content         # FULL site content — every page & section, readable
bookipi website content --json  # the raw structured draft (sections, SEO, images)
bookipi website analytics       # visits, device split, inquiries + their messages
bookipi website analytics --days 90   # custom window (--json for raw series)
bookipi website open            # authenticated builder link (edit the site)
bookipi website create          # set up a website record + return the builder link
bookipi website generate --name "Aurora Studio" --description "wedding & portrait photography"
                                # AI-build the WHOLE site end-to-end, then return a rendered preview + builder link
bookipi website pages           # list the site's pages (name, slug, section count)
bookipi website preview         # render the current draft to a self-contained HTML file (ALL pages for a multi-page site; show it as an Artifact)
bookipi website preview --page About   # render just one page; --full writes a standalone browsable doc
bookipi website update --find "old text" --replace "new text"   # edit page copy (deterministic), save to builder, re-render preview
bookipi website ask "make the hero headline punchier"            # freeform AI edit (reword/restructure/tone) via the builder's chat AI
bookipi website page -o home.html      # dump a page's raw HTML to edit, then update --html-file home.html
bookipi website publish                # 🔴 make the site PUBLIC (confirm first); --url <slug> to choose the address
```

## Publishing — *"publish my website"*, *"make it live"*

`website publish` puts the current draft on the public internet at
`<builder>/v4/pages/<slug>` and prints the live URL.

- **🔴 Always confirm before running it.** Publishing is outward-facing: it
  makes the site visible to anyone with the link. State what will go live
  (business name + page list from `website pages`) and get a clear yes.
- The slug defaults to the business name (*"Acme Cafe"* → `acme-cafe`); pass
  `--url <slug>` for anything else. **Re-publishing keeps the same URL** and
  updates the live site — so after any `update` / `ask` / `add-page`, offer to
  re-publish so the change reaches visitors. Edits do NOT go live on their own.
- Only for **AI-built (v4)** sites; classic sites publish from the builder
  (`website open`).
- A custom domain is a builder/DNS setup step, not a CLI one — `website status`
  reports the domain and its status.

## Building a website with AI — *"build me a website"*, *"make me a website for X"*

`website generate` runs the full AI builder pipeline end-to-end (infer the
business profile → pick the best template → create a draft → generate the
content) and returns a **builder link** to review/tweak/publish. Use it when the
user wants a site *made for them*, not just the empty builder.

```bash
bookipi website generate --name "Aurora Studio" --description "boutique wedding & portrait photography"
bookipi website generate --name "Acme Cafe" --from-url "https://old-acme-site.com"   # pull the profile from an existing site
bookipi website generate --name "Acme" --no-wait     # return immediately without waiting for generation
```

How to drive it (gather the business identity first — don't invent it; the generated copy becomes the user's real, publishable site):
- **Business name** — free text; default to the active company's name if that's clearly the business, otherwise ask.
- **Profile source** — this is a path-branch, so ask with `AskUserQuestion` (per `common.md` § Confirmation Style), NOT free-text. Choices:
  - *"I'll describe it"* → then ask for the **one-line description as free text** and pass `--description`.
  - *"Pull from my existing site"* → ask for the URL and pass `--from-url` (enrich instead of infer).
  - *"You decide"* → omit `--description` and let the builder infer from the name alone.
- **Never fabricate the description.** The source is a finite choice (use `AskUserQuestion`); the description text itself is open-ended (free text — don't force it into choices).
- It **auto-picks the best-matching template** and generates the content. Template choice is visual — after it's done, offer *"open the builder if you'd like a different look."*
- It **waits for the generation job (~1–2 min)** and narrates progress. When done it writes a **rendered preview file** (`previewFile` in `--json`) of the generated home page — **render that file as an Artifact** so the user SEES the site, then hand over the **builder link** to tweak/publish.
- Requires the **AI Website Builder Pro** subscription; if the account isn't subscribed the builder returns a paywall error — relay that plainly, don't retry.
- `website create` just makes the record + hands over the empty builder; `website generate` is the "AI builds it for me" flow. Pick `generate` for *"make/build me a website"*.

## Adding a page — *"add an About page"*, *"create a gallery"*, *"add an FAQ"*

`website add-page "<description>"` AI-generates a **new page** on the current
AI-built (v4) site. The builder writes it in the site's existing style (same
header/footer/theme) and links it into the navigation automatically. The
command polls the generation job (~1 min) and, when done, re-renders a preview
of the new page.

```bash
bookipi website add-page "An FAQ page answering common client questions: timelines, quoting, permits, warranties, how to get started. Friendly but professional, with a contact call-to-action."
bookipi website add-page "A gallery page showcasing recent projects in a responsive image grid" --no-wait   # return the jobId immediately
```

How to drive it:

- Write the **description like a brief**: page purpose, key content, tone, and any layout hints. Don't ask the user for all of that — infer a solid brief from what they said and the site's existing content, and confirm only if genuinely ambiguous.
- It **waits ~1 min** and narrates progress (see `common.md` § Progress Narration). When done it prints the new page's name/slug and a **rendered preview file** — **render that file as an Artifact** so the user sees the page, then offer the builder link for tweaks.
- Works only on **AI-built (v4)** sites; with no site it points to `website generate` first.
- To then reword something on the new page, use `website update`; to see the whole site with the new page in the nav, `website preview --all`.

## Freeform edits — *"make the hero punchier"*, *"change the colors"*, *"reorder the About sections"*

`website ask "<instruction>"` sends one instruction to the builder's
conversational AI (the same AI behind the builder's chat panel) and handles
whatever comes back. Three outcomes:

- **It applies a change** — the AI proposes an edit, the command applies it,
  polls the job (~1 min), and re-renders the preview. **Show the returned
  `previewFile` as an Artifact.**
- **It asks a clarifying question** — the command prints the question +
  suggested options (in `--json`: `{clarify: {question, options}}`) and stops.
  If the user's original request already answers it, **re-run immediately with
  the answer folded into the instruction**; otherwise relay the question
  (finite options → `AskUserQuestion`).
- **It answers in prose** — pure questions end here; relay the answer. (Prefer
  `website content` for content questions — it's one deterministic read.)

```bash
bookipi website ask "Make the hero headline punchier"
bookipi website ask "Reorder the About sections so the team bio comes first" --page about
bookipi website ask "Give the whole site a warmer, earthier color scheme"
```

- `--page <slug>` targets the page the instruction is about (default: home) —
  page-scoped wording like "the hero" resolves against it.
- Works only on **AI-built (v4)** sites; classic sites → builder link.
- One instruction per run, one edit at a time. Batch requests ("fix A, B and C")
  work best as separate `ask` runs.
- The builder rate-limits AI chat (~10/min) and AI generation per account — on a
  rate-limit error, relay "try again in a bit", don't retry in a loop.

## Showing the site — *"show me my website"*, *"what does it look like?"*

`website preview` renders the current draft to a **self-contained HTML file** (a fragment ready to render as an Artifact) so the user can SEE the site, not just read it. It reuses the AI-built draft — the home page by default, `--page <name>` for another (e.g. About). Remote images are inlined; hero videos/fonts degrade to the layout's fallbacks.

**How to display the preview file — pick by what your client offers, and 🔴
NEVER `Read` the preview file into your context** (it can be megabytes of
base64 images; reading it burns the session's budget for one render):

- **Path-based Artifact/file-render tool available** (Claude Code's `Artifact`
  takes a `file_path`) → pass the file path straight to it. Zero context cost.
- **Cowork / no path-based renderer** → render INTO the mounted project folder
  so the file lands on the user's real machine, then link it:
  `bookipi website preview --full -o <project-folder>/website-preview.html` —
  tell the user to open that file (it's in their project folder; `--full` keeps
  images/fonts remote so a real browser renders it perfectly and the file stays
  small). Only for a genuinely small fragment (< ~1 MB on disk — check with
  `ls -l` first) may you fall back to reading it and rendering via a widget.
- **CLI running on the user's own machine** (local terminal) → offer
  `bookipi website preview --open` — it opens the rendered site directly in
  their default browser (implies `--full`).

- Use `website preview` for *"show/preview my site"*, *"what does it look like?"*; use `website content` for *"what does it say?"* (readable text digest, not a render).
- **Multi-page sites:** `website pages` lists the pages; `website preview --page <slug>` renders one; **`website preview --all`** renders the whole site into one navigable file (inter-page links become in-file anchors) — reach for `--all` when the user says *"show me the whole site"* or the site has more than one page.
- **🔴 Don't reuse a mutation command's own `previewFile` once the site has 2+ pages.** `website generate` / `add-page` / `ask` / `update` each hand back a single-page `previewFile` in their JSON — that page's nav still links to sibling pages by real path (e.g. `/gallery`), which 404s inside a static Artifact (there's no server to route it). Once `website pages` shows more than one page, re-run `bookipi website preview --all` yourself and publish *that* file as the Artifact instead of the mutation's `previewFile` — same rule as any other multi-page preview request.
- `--full` writes a standalone browsable document (keeps fonts/media) instead of the Artifact fragment — use it only if the user wants a file to open in a real browser.
- Only **AI-built (v4)** sites can be rendered as a page. For a **classic** (section-based) site, `preview` says so and points to `website content` (to read it) + the builder link (to view/edit) — relay those rather than reporting an error. If there's no website at all, it points to `website generate`/`create`.

## Answering questions

**Metadata questions** ("is it live?", "what's my domain?", "when was it last
updated?") → `website status` answers directly. If there's no website, say so
and offer `website create` — don't create one unprompted.

**"Do I have a website?" — trust `status`, and read the whole line.** `status`
cross-checks the published flag against the actual page/section count, so it
distinguishes the three real states, and you should relay whichever one it
reports:

| `status` says | What it means | What to tell the user |
|---|---|---|
| 🟢 published + a non-zero content count | A real, live site | Yes — it's live |
| 🟡 draft | Content exists, not published yet | You have a site, it isn't live |
| ⚠️ published, but the site has no content | **A deleted site.** Deleting in the builder clears the pages but leaves the record flagged published | There's nothing there — the record is a leftover shell |

The ⚠️ case is the one that used to read as a live site. Don't paper over it
with the record's flag: an empty published record is not a website, and saying
"yes, it's live" there is wrong. `--json` carries the same verdict as
`content.isEmpty` alongside `content.pages` / `content.sections`.

**Content questions** ("what does my website say?", "what pages do I have?",
"does my site mention pricing?") — run `bookipi website content` ONCE and
answer everything from it. It loads the complete draft from the builder
service — every page, every section's headings/copy, services, FAQs,
testimonials, per-page SEO — like loading a meeting's transcript. Works for
draft AND published sites, no browser needed. Reuse the loaded content for
follow-up questions in the same session; don't re-fetch per question.
`--json` gives the raw structured draft when you need image URLs, button
links, or design settings.

Once loaded, answer content questions directly from what you read — quotes,
page lists, missing-info checks ("your site has no pricing section"), copy
critiques, SEO-ish observations. Same rules as everywhere: facts from the
actual content, never invented.

**Never declare a site empty on thin evidence — but do distinguish the two
ways "empty" happens.** If the digest shows a ⚠️ about sections that exist
without readable content, that's a data/format gap on our side: say you
couldn't read the content and hand over the builder link, rather than telling
the user their site has nothing on it. If there are genuinely **no pages or
sections at all** (`website status` reports ⚠️ published-but-no-content, or
`content.isEmpty` is true), that's not a format gap — the site really is
empty, usually because it was deleted in the builder. Say so plainly.

**Traffic/inquiry questions** ("how many visitors did my site get?", "any new
inquiries?", "did anyone contact me through the site?") → `website analytics`.
It reports total visits with device split, days with activity, and every
contact-form inquiry including the message text — read inquiries to the user
verbatim, flag unread ones. Unpublished sites legitimately show zeros; say
the site needs to be published for traffic to start, don't treat it as an
error.

**Edit requests** — for **AI-built (v4) sites**, edit content in place and
re-show the preview (the invoice-style loop):

- **Exact text swap** (the user supplies the new wording: "change the headline
  to X") → `bookipi website update --page <slug> --find "<exact old text>"
  --replace "<new text>"`. Deterministic: it edits the page, **saves to the
  builder** (the change shows there too), and re-renders the preview — show the
  returned `previewFile` as an Artifact. The `--find` text must match exactly;
  run `bookipi website content` (or `bookipi website page`) first if you're
  unsure of the wording.
- **Freeform reword / restructure / style** (the user describes the *intent*:
  "make it punchier", "reorder the sections", "warmer colors", "add a
  testimonials section") → `bookipi website ask "<instruction>"` (see § Freeform
  edits). Route by who's writing the words: user supplies exact text → `update`;
  user describes a direction → `ask`.
- **Bigger hand-edit of a section** (you're rewriting the copy yourself) →
  `bookipi website page --page <slug> -o <file>` to get the raw HTML, edit the
  copy in that file, then `bookipi website update --page <slug> --html-file
  <file>`. Only touch the copy — don't restructure the markup or change
  classes/styles; structure belongs to `ask`/the builder.
- **A new page** → `website add-page`; a **whole-site redesign** (new template/
  look) → hand over the builder link (`website open`). Never hand-author new
  section markup — `ask` generates it in the site's own style.
- **Classic sites** can't be edited this way — hand over `website open`.

Never edit the site through the browser pane; drive edits only through
`website update` / `website ask`.

## Presentation

- Refer to the site by its business name; show the domain as a clickable
  link when published.
- The builder link carries a short-lived token — present it as a tidy
  markdown link (*"[Open your website builder](…)"*), never raw.

## Known limits (v1)

- Orders/e-commerce data isn't exposed — say it isn't connected rather than
  guessing. Content, structure, SEO, and design settings come from
  `website content`; traffic and inquiries from `website analytics`.
- `website status` reads the main API's website record; the builder editor
  may have newer unsaved/unpublished changes than the published domain shows.
- The record's `isPublished` flag survives a site deletion, so `status` also
  reads the content to count pages/sections before calling a site live. That
  read is best-effort: if the builder can't be reached, status appends
  "content not verified" and reports the record's flag unverified — never
  treat an unverified check as an empty site.
- `status` doesn't fetch the live URL, so it can't tell you what a visitor
  actually sees on a published-but-empty site (blank page vs. 404 vs. a stale
  published snapshot). Open the builder to confirm.
