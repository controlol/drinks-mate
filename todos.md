- S9: After tapping an item simply extend the drawer to the top so all properties are immediately visible
- S6: When does a party session end? A session started at 20:57 with one drink and is 12h5m after this still not stopped
- Opening the app the next morning did not reload the today view, the values from yesterday were still visible. When do the values refresh? Solved after closing and opening the app
- S1: Scrolling up the quicklog items should either: 1. scroll the whole page 2. Leave other cards in-place but scroll over them. Section header should be sticky at the top of the page.
- S1: "Log a drink" - Rename to "Quick Log", fix left alignment
- S7: BAC Line chart should be rendered even if no drink is logged - reduce layout shift
- S7: Tapping the overview card should also open the "Party Session Log" list

- S1 state does not always update when opening the app (from recents) - e.g. opening the next day but it still shows the previous day progress
- S7 session summary - tapping the party session should extend it's view with more details: 1. start and end time (after duration) 2. total consumed alcohol (after peak) 3. BAC line chart (at the bottom of the card)
- S7 session summary - meals should also be shown
- Logged drink toast (after logging a drink) does not disappear after set amount of time, stays there indefinetely
- Notifications are not working
- S7 tapping the BAC line chart should render a vertical line where you tapped and tell you the BAC value at that time
- S7 Allow deletion of party session, drinks remain logged but session must be detached
- S7 ending a session with 0 drinks attached should not save the session - interview for the user flow
- S7 Allow naming a party session, name is shown in the "past sessions" list before the date, on the same line - interview for user flow
- S7 Add quick log similar to S1, just two items no scrolling. Always sorted with most recently used alcoholic drinks. And reordering of items - New quick log directly below the line chartcard, "Log Alcohol" button sticky to bottom of the page like in S1.

---

- S1: no full screen scroll yet
- S7: remove the delete button in the history list
- S7: renaming the session should also change the text in the S9 header card -> "Party session" stays default, otherwise replace with custom name
- S9: missing the BAC chart + tapping the header card does not expand it
- Still no notifications. Requires deeper investigation - do not create gh issue

---

I want to know performance insights about the recent feature implementations since issue #94:

Per issue:

- Issue number & related PR
- Short description of the task (or issue title)
- How long did it take the dispatch agent to implement of the issue
- What was the complexity score of the issue: 1-5
- How often is compact used
- How many subagents were started
- Number of rolls
- Which skills were used
- How often did it have to wait for the API because it was overloaded or other network issues (HTTP 429 etc)

Per PR:

- Duration of the review steps
- Number of remediation steps
- Duration of each remediation step
- Categorize issues fixed by remediation
- From the comments: what is still not correctly implemented
