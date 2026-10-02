# Debugging a React Frontend: Browser and VS Code

Oct 2, 2026 · @Youness

## Before you start

You need three things in place, otherwise breakpoints will not map to your source files.

1. **Run the dev server, not a production build.** `npm run dev` or `npm start` serves unminified code with source maps. A production bundle shows you one unreadable file.
2. **Note the URL and port.** Usually `http://localhost:3000` (Create React App, Next.js) or `http://localhost:5173` (Vite). You need it for the VS Code config.
3. **Install the React Developer Tools extension** in Chrome or Edge. It adds the Components and Profiler tabs to DevTools.

Shortcuts below are for Windows and Linux. On macOS, replace Ctrl with Cmd.

## Browser: the basic debugging loop

Chrome DevTools gives you the same loop as PyCharm: set a breakpoint, trigger the code, step, inspect.

1. Open DevTools with F12 and go to the **Sources** tab.
2. Press Ctrl+P and type the file name, for example `QuoteForm.tsx`. Pick the entry that shows your original source path, not a bundled chunk.
3. Click a line number to set a breakpoint. A blue marker appears.
4. Do the action in the app. Execution pauses and the line is highlighted.
5. Step with the controls at the top of the right panel: resume (F8), step over (F10), step into (F11), step out (Shift+F11).
6. Inspect state in the right panel:
   - **Scope** shows local variables, closure variables and `this`.
   - **Call Stack** shows how you got here. Click a frame to jump to it and see its variables.
   - **Watch** lets you pin expressions that are re-evaluated at each step.
7. Press Esc to open the Console drawer. It runs in the paused frame, so you can type any variable name or call any function in scope.

Hovering over a variable in the code while paused shows its current value.

## Browser: finding the code behind a UI action

When you do not know which file handles a button, let the browser tell you. Pick the technique by what you already know.

| You know | Use | How |
| --- | --- | --- |
| The request it sends | Network tab, Initiator column | Hover the request to see the call stack that fired it. Click a frame to open that line in Sources. |
| Part of the API URL | XHR/fetch Breakpoints | In Sources, right panel, add a URL fragment like `/api/price`. Execution pauses when a matching request is sent. |
| Only the element on screen | React DevTools, Components tab | Click the picker icon, click the element. You get the component name, props, state and a link to its source. |
| Nothing at all | Event Listener Breakpoints | In Sources, right panel, tick Mouse > click. The next click pauses in its handler. |

Two notes on these:

- With Event Listener Breakpoints you often land inside React internals first. Step out a few times, or walk the Call Stack until you see a file from your own `src`.
- If a request does not show an initiator from your code, it was likely fired by a data library such as React Query or Redux middleware. Search the URL path with Ctrl+Shift+F to find where it is declared.

Once paused on a request, right click it in the Network tab and choose Copy as cURL. You can replay it against the backend without touching the UI.

## Breakpoint types worth knowing

A plain breakpoint is rarely enough in React, because the same code runs many times. These work the same in the browser and in VS Code: right click the line number to pick one.

| Type | What it does | When to use it |
| --- | --- | --- |
| Conditional breakpoint | Pauses only when an expression is true, for example `row.id === 42` | Code inside a loop, a list render, or a handler shared by many rows |
| Logpoint | Prints a message to the console without pausing. Chrome takes console.log arguments, 'price is', price. VS Code takes text with braces, `price is {price}` | Following a value across re-renders without stopping each time. Replaces temporary `console.log` calls. |
| `debugger;` statement | Pauses at that line when DevTools is open | When you are already editing the file and cannot find it in Sources. Remove it before committing. |
| Pause on exceptions | Pauses where an error is thrown | An error appears in the console and you want the state at the moment it happened. Tick "caught" too if the app swallows it. |

## VS Code: one-time setup

VS Code debugs React by driving a Chrome or Edge window, so the only setup is a `launch.json` that tells it the URL and where the source lives. The JavaScript debugger is built in. No extension is needed.

1. Open the Run and Debug panel with Ctrl+Shift+D.
2. Click "create a launch.json file" and choose Web App (Chrome) or Web App (Edge).
3. Replace the generated content with this, then adjust `url` and `webRoot`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Launch Chrome on dev server",
      "type": "chrome",
      "request": "launch",
      "url": "http://localhost:3000",
      "webRoot": "${workspaceFolder}/frontend",
      "skipFiles": ["<node_internals>/**", "**/node_modules/**"]
    },
    {
      "name": "Attach to running Chrome",
      "type": "chrome",
      "request": "attach",
      "port": 9222,
      "webRoot": "${workspaceFolder}/frontend",
      "skipFiles": ["<node_internals>/**", "**/node_modules/**"]
    }
  ]
}
```

What each field does:

- `url` is the dev server address from the first section.
- `webRoot` is the folder that contains the frontend `package.json`. In a monorepo this is a subfolder, not the workspace root. A wrong `webRoot` is the most common reason breakpoints do not bind.
- `skipFiles` stops the debugger from stepping into React internals and other libraries.
- Use `"type": "msedge"` if you use Edge.

**Launch or attach?** Launch opens a fresh browser profile: no extensions, no saved login. If the app needs SSO or you want React DevTools, use attach. Start Chrome yourself with a debugging port, log in, then run the attach config:

```bash
chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug
```

The `--user-data-dir` flag is required. Recent Chrome versions ignore the debugging port on your default profile.

## VS Code: running a debug session

Once the config exists, a session is: start the dev server, press F5, click in the app.

1. Start the dev server in a terminal. VS Code does not start it for you.
2. Open the component file and click in the gutter left of a line number, or press F9. A red dot appears.
3. Pick your config in the Run and Debug dropdown and press F5.
4. Do the action in the browser window. VS Code comes to the front, paused on your line.
5. Step with F10 (over), F11 (into), Shift+F11 (out), F5 (continue).

The left panel maps directly to what you know from PyCharm:

| VS Code panel | PyCharm equivalent | Use |
| --- | --- | --- |
| Variables | Variables | Local, closure and global scope for the selected frame |
| Watch | Watches | Expressions re-evaluated at each step |
| Call Stack | Frames | Click a frame to inspect it. Async frames are shown too. |
| Breakpoints | Breakpoints view | Enable, disable, and toggle caught or uncaught exceptions |
| Debug Console (Ctrl+Shift+Y) | Evaluate Expression | Type any expression in the paused frame |

The red dot must stay solid red after the session starts. A hollow grey dot means the breakpoint is unbound: see Troubleshooting.

When to prefer each tool: VS Code is better for stepping through logic, because you are in your editor with go-to-definition. The browser is better for anything involving the network, the DOM, or React component state.

## Tracing one click across frontend and backend

Run both debuggers at once and a single click walks you from the button to the database call.

1. Start the backend in debug mode in PyCharm, as you already do.
2. Start the frontend dev server and attach a frontend debugger (browser or VS Code).
3. Set a frontend breakpoint in the click handler, and a backend breakpoint in the FastAPI route you expect it to hit.
4. Click the button. The frontend pauses first. Read the handler's arguments and the component state.
5. Step until the line that sends the request. Note the URL, method and payload.
6. Resume. The backend breakpoint hits. Compare the received payload with what the frontend sent.
7. Step through the backend, then resume. The response arrives in the browser.
8. Set a breakpoint on the line after the `await`, or in the `.then` callback, to see how the response is turned into state.

If the backend breakpoint never hits, check the request in the Network tab. It may go to a different endpoint, another service, or fail before leaving the browser.

After each trace, write the path in one line: component, handler, endpoint, route function, service function, collection. That line is your mapping entry.

## React behaviours that confuse the debugger

React does not run top to bottom like a Python request handler. These five behaviours explain most "why did that happen" moments.

- **Component bodies run on every render.** A breakpoint in the component body fires many times. Put breakpoints inside handlers (`onClick`, `onSubmit`) or inside `useEffect` callbacks instead.
- **StrictMode runs things twice in development.** Component bodies and effects are invoked twice on purpose to surface bugs. A double hit on mount is normal and does not happen in production.
- **State updates are not immediate.** After `setPrice(10)`, the `price` variable still holds the old value for the rest of that handler. The new value appears on the next render. Check it there, or in React DevTools.
- **Handlers see the values of the render that created them.** If a variable looks stale inside a callback or effect, the function was created in an earlier render. Check the dependency array of the `useEffect` or `useCallback`.
- **`await` splits execution.** Step over on an `await` line may return control to the browser. Put a breakpoint on the next line and resume instead of stepping.

For state questions, React DevTools is faster than breakpoints. Select a component in the Components tab to see its props and hooks live, and edit them to test a scenario. Hooks are listed in declaration order. The wand icon parses their variable names.

## Troubleshooting

Almost every problem is a source map or path mismatch between the code running in the browser and the files on disk.

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| VS Code breakpoint is hollow grey ("Unbound breakpoint") | `webRoot` points to the wrong folder | Set it to the folder holding the frontend `package.json`. Run "Debug: Diagnose Breakpoint Problems" from the command palette to see what paths the debugger expects. |
| Sources only shows minified or bundled code | Production build, or source maps turned off | Run the dev server. In DevTools settings, check that JavaScript source maps are enabled. |
| Breakpoint pauses on the wrong line | Browser is running a stale bundle | Open the Network tab, tick Disable cache, and hard reload with Ctrl+Shift+R. |
| Breakpoint never hits | That code path did not run, or you opened a different file with the same name | Add a `debugger;` statement in the file, or confirm the path with the Network Initiator. |
| Stepping keeps entering React or library code | Third party code is not ignored | In Chrome, right click the file in the Call Stack and add it to the ignore list. In VS Code, check `skipFiles`. |
| VS Code browser window asks you to log in again | Launch mode uses a fresh profile | Use the attach config, or add a fixed `userDataDir` to the launch config so the profile persists. |
| Attach fails with a connection error | Chrome was not started with the debugging port, or another Chrome was already running | Close all Chrome windows, then start it with the command from the setup section. |
| No Components tab in DevTools | React DevTools not installed, or blocked by browser policy | Install it. On a managed machine, check which extensions are allowed. |

## Shortcut reference

The stepping keys are the same in both tools. Only resume differs.

| Action | Chrome DevTools | VS Code |
| --- | --- | --- |
| Open the tool | F12 | Ctrl+Shift+D |
| Start or resume | F8 | F5 |
| Step over | F10 | F10 |
| Step into | F11 | F11 |
| Step out | Shift+F11 | Shift+F11 |
| Toggle breakpoint on current line | Ctrl+B | F9 |
| Stop the session | Close DevTools | Shift+F5 |
| Open a file by name | Ctrl+P | Ctrl+P |
| Search text in all files | Ctrl+Shift+F | Ctrl+Shift+F |
| Console in the paused frame | Esc | Ctrl+Shift+Y |
| Pick an element on the page | Ctrl+Shift+C | Not available |

## Routine for tracing one workflow

Follow these steps each time you learn a new user path. Ten to twenty minutes per path is normal at first.

1. Run the path once as a user, with the Network tab open and Preserve log ticked.
2. List the requests it fired, in order. Ignore static assets.
3. For the main request, open its Initiator and jump to the frontend line that sent it.
4. Walk up the Call Stack to the event handler. Note the component and file.
5. Set a breakpoint in that handler and one in the matching backend route.
6. Run the path again. Step through the frontend, then the backend, then the response handling.
7. In React DevTools, check which component state changed after the response.
8. Close everything and write the flow from memory. Then check it against what you saw.
9. Remove any `debugger;` statements before you commit.
