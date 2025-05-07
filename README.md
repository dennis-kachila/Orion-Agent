# Orion Agent

Orion Agent is an in-process AI companion that converts natural-language requests into MATLAB® scripts and Simulink® models, executes them, inspects results, and iterates—without any GUI-level mouse automation.

## Overview

Orion Agent uses a curated set of programmatic "tools" (functions) exposed to a Large-Language Model (LLM). A lightweight ReAct loop stored in memory decides which tool to call next, receives structured feedback (block handles, simulation outputs, error objects), and plans subsequent actions until the user's goal is met.

The agent manipulates models through documented MATLAB/Simulink APIs such as `add_block`, `add_line`, `set_param`, `sim`, the MATLAB Desktop Editor API, and other stable interfaces, rather than driving the GUI with mouse clicks.

Here is how the UI looks:
![Orion Agent UI](Layout/app.png)
> **Note**: The original App Designer file (.mlapp) has been converted to a standard MATLAB file (.m) for better compatibility. The keyboard shortcuts for sending messages have been removed to address compatibility issues with some MATLAB versions. Use the Send button to submit your requests.
>
> **Note**: The app is designed to be run in a MATLAB session with a licensed version of Simulink.
>
>Below is a screenshot of the app designed in App Designer:
![Orion Agent UI App Designer](Layout/app_ui.png)

## Setup and Configuration

1.  **Clone the Repository**: Clone the repo into a regular MATLAB project (so paths auto-load).
2.  **Setup Paths**: Run `setup_paths.m` from the MATLAB command window to ensure all required directories are added to MATLAB's path.
    ```matlab
    setup_paths
    ```
3.  **Configure API Key**: Set up your API key for the LLM. Orion Agent primarily uses Gemini or OpenAI.
    *   **Environment Variable (Recommended)**: Set `GEMINI_API_KEY` or `OPENAI_API_KEY`.
        *   On Windows, you can use `set_api_key.bat` (edit it first with your key) or set it manually in System Environment Variables.
        *   On macOS/Linux: `export GEMINI_API_KEY=your_api_key_here`
    > **⚠️ SECURITY WARNING**: Never hardcode API keys directly in source code files. Always use environment variables.

4.  **Verify (Optional but Recommended)**: Run the basic tests to ensure tool functionality.
    ```matlab
    runtests('tests/t_basic.m')
    ```
5.  **Start the Application**:
    *   Run `launch_agent.m` from the MATLAB command window to start the Orion Agent UI.
    ```matlab
    launch_agent
    ```
    *   Alternatively, you can open and run `app/AgentAppChat.m` in MATLAB.

## Special Commands

Orion Agent supports special commands that control its behavior:

1.  **@agent Continue**: Continues the previous conversation or task.
    *   Usage: `@agent Continue` - Continues with default continuation prompt.
    *   Usage: `@agent Continue: <custom prompt>` - Continues with a custom prompt.
    Example: `@agent Continue: Now try to optimize the gain parameter.`

## Project Management (To-Do List)
(Status last reviewed: May 7, 2023. Based on project structure and Agent.m analysis.)
- ✅ HIGH PRIORITY: Separate the MATLAB and Simulink tools (done - tools are organized into `+tools/+matlab` and `+tools/+simulink`)
- ✅ HIGH PRIORITY: Capture errors and warnings in the log and give back to the LLM (done - `Agent.m` includes error capturing, redaction, and feedback to LLM)
- ✅ Add more relevant tools to the toolbox (done for core MATLAB/Simulink workflows as seen in `+tools/`; system is extensible for more tools)
- ⬜ HIGH PRIORITY: Add more examples - currently there's no dedicated examples folder, consider creating an `examples/` directory with sample workflows (pending)
- ⬜ Add how people can contribute to the project (pending - "Extensibility" section provides developer guidance, but a formal "Contributing.md" or dedicated section with guidelines is pending)
- ⬜ HIGH PRIORITY: Enhance the documentation search tool (`+tools/+general/doc_search.m`) since it is key for agents to find relevant information quickly (pending - current implementation provides basic search functionality but needs to be expanded)
- ⬜ Add more robust and diverse few-shot examples for LLM prompt engineering (pending - `Agent.m` constructor includes basic examples; more diverse and robust examples are pending)
- ⬜ Add more unit and integration tests for new and edge-case tool behaviors (pending - `tests/t_basic.m` provides basic tests; comprehensive coverage for new tools and edge cases is pending)
- ⬜ Improve UI accessibility and add visual cues for errors/success (pending - "Recent Improvements" note UI redesign and some visual feedback; however, a full review against accessibility standards and implementation of comprehensive, distinct visual cues for various error/success states is pending)
- ⬜ Add support for user-configurable tool/plugin registration (pending - current tool registration requires code modification in `+agent/ToolBox.m`)
- ⬜ Add support for multi-turn, multi-user chat history (pending - multi-turn history for a single user is implemented in `Agent.m`; multi-user support is pending)
- ⬜ Add more advanced error recovery and self-healing strategies for the agent (pending - `Agent.m` feeds errors to LLM for recovery; more advanced, autonomous self-healing strategies are pending)
- ⬜ Add CI/CD pipeline for automated testing and linting (pending - "Extensibility" section mentions this as a future step)
- ⬜ Add internationalization/localization support (pending - no evidence of I18N/L10N features)
- ⬜ Add more detailed developer and user documentation (pending - `docs/` folder and main README provide good documentation; continuous improvement for more in-depth guides, API references, and developer-specific documentation is pending)
- ⬜ Add performance benchmarks and profiling (pending - "Recent Improvements" mention optimizations, but formal benchmarks and profiling tools are pending)
- ⬜ Add telemetry/analytics (opt-in) for usage and error tracking (pending - no evidence of telemetry features)
- ⬜ Add support for additional LLM providers and model selection (pending - `Agent.m` and `set_api_key.bat` suggest support for Gemini/OpenAI; dynamic, user-configurable model selection from a broader range of providers is pending)
- ⬜ Add advanced Simulink model validation and reporting (pending - "Safety Guidelines" mention `Simulink.BlockDiagram.validate`; more advanced, automated validation routines and comprehensive reporting features are pending)
- ⬜ Add more granular user permissions and security controls (pending - no evidence of granular permission system beyond MATLAB user permissions)

## API Key Security

For secure handling of API keys, follow these best practices:

1.  **Environment Variables (Most Secure)**:
    *   Windows: `set GEMINI_API_KEY=your_api_key_here` (or use System Properties)
    *   macOS/Linux: `export GEMINI_API_KEY=your_api_key_here`
2.  **Never Commit API Keys**: Ensure `.gitignore` includes any local configuration files.
3.  **Rotate Compromised Keys**: If a key is accidentally exposed, revoke it immediately and generate a new one. Clean your Git history if necessary.

## Running Tests

Run the included tests to confirm all tools work with your MATLAB configuration:
```matlab
runtests('tests'); % Runs all tests in the 'tests' folder
% or for a specific test file:
% runtests('tests/t_basic.m');
```

## Usage Example

In the AgentChat UI, you can type natural language requests like:

**For MATLAB:**
> "Create a MATLAB script that says hello world and prints numbers from 1 to 10."

**For Simulink:**
> "Create a model with a Sine Wave feeding a Scope and simulate for 5 s."

Orion Agent will then execute the appropriate sequence of actions, such as:
1. Create a new model or script.
2. Add blocks (for Simulink) or write code.
3. Connect blocks or define variables.
4. Arrange layout (for Simulink).
5. Run a simulation or execute the script.
6. Show the results and model/script preview.

To continue working on the same task, use the `@agent Continue` command:
> "@agent Continue: Now add a Gain block between Sine Wave and Scope and set its value to 5."

## Response Format

Orion Agent typically returns responses in a structured JSON format (internally, and for logging), which includes:
```json
{
  "summary": "Brief description of what was accomplished",
  "files": ["file1.m", "model1.slx", ...],
  "snapshot": "data:image/png;base64,...", // For Simulink models
  "log": ["tool-call-1", "tool-call-2", ...]
}
```
The UI then presents this information in a user-friendly way.

## Troubleshooting

If you encounter issues:
1.  **App Cannot Be Found**: Ensure you are using `app/AgentAppChat.m`.
2.  **Keyboard Shortcuts**: Use the "Send" button. KeyPressFcn was removed for compatibility.
3.  **API Key Issues**:
    *   Follow API Key Security guidelines.
    *   Verify environment variables.
    *   Check MATLAB console for warnings.
4.  **Missing Dependencies**: Ensure required toolboxes (e.g., Simulink) are installed.
5.  **`@agent Continue` Not Working**: Ensure there's a previous conversation.
6.  **UI Display Issues**: Try resizing; ensure MATLAB display scaling matches system.
7.  **Error Messages**: Review error messages for context; they are designed to help the LLM recover.

## Runtime Flow (ReAct Loop)

Orion Agent employs a ReAct (Reasoning-Acting) loop:

```mermaid
graph TD
    U(User Prompt) --> PB(PromptBuilder: User Prompt + History + Tool List)
    PB --> LLM(callGPT: LLM Decides Action)
    LLM -->|JSON: tool, args| DP(Dispatcher: Validate & Get Tool)
    DP -->|Error| LLM % Tool not found, LLM reconsiders
    DP --> TOOL(Execute Tool: e.g., +tools/simulink/create_new_model)
    TOOL --> RESULT(Result: String, Struct, PNG, Error)
    RESULT --> HIST(Update History: Thought → Action → Observation)
    HIST --> DEC{Task Complete?}
    DEC -->|No| PB
    DEC -->|Yes| RESP(Format Final Response for UI)
    RESP --> UI(Update AgentChat UI)
```

1.  **Prompt Building**: User input, chat history, and available tool descriptions are compiled into a prompt for the LLM.
2.  **LLM Decision**: The LLM (`llm.callGPT`) processes the prompt and returns a JSON object specifying the tool to use and its arguments.
3.  **Dispatch**: The `ToolBox` validates the tool and arguments.
4.  **Tool Execution**: The selected tool function is called. Tools interact with MATLAB, Simulink, or the file system.
5.  **Observation**: The result (or error) from the tool is recorded.
6.  **Iteration**: If the task isn't complete, the process repeats from step 1 with the new observation added to the history.
7.  **Response**: Once the task is complete, a final summary is sent to the UI.

## Recent Improvements

- **Enhanced UI Design**: The interface has been redesigned for better usability with the conversion from MATLAB App Designer (.mlapp) to standard MATLAB (.m) files, improving compatibility across different MATLAB versions.
- **Improved Error Handling**: Errors are now captured with context and provided to the LLM for more intelligent recovery, implemented through error redaction in Agent.m and ToolBox.m.
- **Better Tool Organization**: Tools are now properly categorized into general, MATLAB, and Simulink domains as seen in the +tools directory structure.
- **Multi-Provider LLM Support**: The system supports both OpenAI and Gemini API providers through the environment variable configuration.
- **ReAct Loop Implementation**: A robust implementation of the Reasoning-Acting-Observing loop enables iterative task completion.
- **Special Commands**: Support for special commands like @agent Continue has been implemented to enhance the user experience.
- **Workspace Folder Management**: Automatic creation and management of an orion_workspace folder for storing agent-generated files.
- **Visual Feedback**: Added snapshot capability for Simulink models to provide visual feedback of model states.

## Extensibility

-   **Add a New Tool**:
    1.  Create your `.m` function in the appropriate `+tools/` sub-package (e.g., `+tools/+matlab/my_new_tool.m`).
    2.  Register it in `+agent/ToolBox.m` by adding its function handle and a description to the `registerCoreTools` method (or a new registration method if appropriate).
-   **Swap LLM**: Modify `+llm/callGPT.m`. The function must continue to parse requests and return JSON-parseable responses as expected by the `Agent.m`.
-   **Vision Upgrade**: For vision-capable LLMs, tools like `+tools/+simulink/auto_layout.m` (or a new tool) can use `createSnapshot` (if it exists, or implement screen capture) to send PNGs of models/plots for spatial feedback or analysis.
-   **CI Regression**: Integrate `tests/` into a CI/CD pipeline (e.g., GitHub Actions with MathWorks-hosted runners).

## Safety Guidelines

-   **Error Handling**: All tool calls are wrapped in `try/catch`. Errors are processed by `utils/redactErrors.m` or `utils/safeRedactErrors.m` to strip sensitive information (like full file paths) before being shown to the LLM or user.
-   **Model Size Limits**: Consider implementing checks within tools or the agent to warn or prevent operations on excessively large models to avoid performance issues (e.g., `if numel(find_system(mdl,'Type','block')) > 1000`).
-   **Model Validation**: Use `Simulink.BlockDiagram.validate` after structural edits to ensure model integrity before simulation.
-   **API Key Security**: Never hardcode API keys. Use environment variables.
-   **File System Access**: Be mindful that tools can read/write files. The `orion_workspace/` is the designated area for agent-generated content.
