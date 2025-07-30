I want to start or resume a dev session. 

There should be a directory of markdown documents and artifacts for the current dev session. The name of the directory should be called `docs/dev-sessions/$(date +"%Y-%m-%d-%H%M")-{slug}` where `$(date +"%Y-%m-%d-%H%M")` is a bash command and `{slug}` is a short description of the session. If possible, derive the slug from the name of the current git branch, otherwise ask me to provide a short description.

Check if the directory exists. If it does, read the documents in the directory for context.

If the directory doesn't exist, create it. Then, create the following empty files in the directory:

- `spec.md` - the spec for the session
- `plan.md` - the plan for the session
- `todo.md` - the todo list for the session
- `notes.md` - the notes for the session, including a final summary of the session before committing to git

Remember that this is the current dev session until we start another one or finish this one.
