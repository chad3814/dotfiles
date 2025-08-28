Draft a detailed, step-by-step blueprint for building this project or feature. The spec describing the project or feature is in the file called spec.md for the current dev session.

Once you have a solid plan, break it down into small, iterative chunks that build on each other. Look at these chunks and then go another round to break it into small steps. review the results and make sure that the steps are small enough to be implemented safely, but big enough to move the project forward. Iterate until you feel that the steps are right sized for this project.

From here you should have the foundation to provide a series of prompts for a code-generation LLM that will implement each step. Prioritize best practices, and incremental progress, ensuring no big jumps in complexity at any stage. Make sure that each prompt builds on the previous prompts, and ends with wiring things together. There should be no hanging or orphaned code that isn't integrated into a previous step.

Make sure and separate each prompt section. Use markdown. The goal is to output prompts, but context, etc is important as well.

Store the plan in plan.md.

Then, update todo.md with a succinct checklist of phased steps to implement the plan.
