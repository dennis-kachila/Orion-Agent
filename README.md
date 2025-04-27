# Orion Agent

Orion Agent is an in-process AI companion that converts natural-language requests into MATLAB® scripts and Simulink® models, executes them, inspects results, and iterates—without any GUI-level mouse automation.

## Overview

Orion Agent uses a curated set of programmatic "tools" (functions) exposed to a Large-Language Model (LLM). A lightweight ReAct loop stored in memory decides which tool to call next, receives structured feedback (block handles, simulation outputs, error objects), and plans subsequent actions until the user's goal is met.

The agent manipulates models through documented MATLAB/Simulink APIs such as `add_block`, `add_line`, `set_param`, `sim`, the MATLAB Desktop Editor API, and other stable interfaces, rather than driving the GUI with mouse clicks.

## Project Structure

```
orion-ai-agent-mab/
│
├── +agent/                  % core decision loop
│   ├── Agent.m              % ReAct controller; owns chat history
│   ├── ToolBox.m            % registers callable tools
│   └── utils/
│       └── redactErrors.m   % strips stack traces before LLM sees them
│
├── +tools/                  % thin wrappers around MATLAB/Simulink APIs
│   ├── run_code.m           % evalc wrapper for arbitrary MATLAB code
│   ├── new_model.m          % new_system + open_system
│   ├── add_block_safe.m     % add_block wrapper (makes name unique)
│   ├── connect.m            % add_line; path syntax described in API docs
│   ├── arrange.m            % Simulink.BlockDiagram.arrangeSystem
│   ├── sim_model.m          % out = sim(mdl,'ReturnWorkspaceOutputs','on');
│   ├── open_editor.m        % matlab.desktop.editor.openDocument
│   └── doc_search.m         % find_system / web search of MathWorks help
│
├── +llm/
│   ├── callGPT.m            % webwrite → OpenAI or local Llama or Gemini
│   └── promptTemplates.m    % System & few-shot templates
│
├── app/
│   └── AgentChat.mlapp      % App Designer UI: chat pane + live model PNG
│
└── tests/
    └── t_basic.m            % ensures each tool works on clean MATLAB
```

## Setup and Configuration

1. Clone the repo into a regular MATLAB project (so paths auto-load).
2. By default, the agent is configured to use Google Gemini API with the provided key.
3. (Optional) Configure a different LLM provider:
   - For OpenAI: Set the OPENAI_API_KEY environment variable
   - For Google Gemini: Set the GEMINI_API_KEY environment variable, or use the default key
   - For a local LLM: Modify llm/callGPT.m to use your local endpoint
4. (Optional) Run `llm_settings.m` to save your LLM configuration settings.
5. Open `app/AgentChat.mlapp` and press Run in MATLAB. The UI creates an agent.Agent instance internally.

## Running Tests

Run the included tests to confirm all tools work with your MATLAB configuration:

```matlab
runtests('tests');
```

## Usage Example

In the AgentChat UI, you can type natural language requests like:

> "Create a model with a Sine Wave feeding a Scope and simulate for 1 s."

Orion Agent will execute the appropriate sequence of actions:
1. Create a new model
2. Add Sine Wave and Scope blocks
3. Connect them
4. Arrange the layout
5. Run a simulation
6. Show the results and model preview

## Response Format

Orion Agent returns responses in a structured JSON format:

```json
{
  "summary": "Brief description of what was accomplished",
  "files": ["file1.m", "model1.slx", ...],
  "snapshot": "data:image/png;base64,...",
  "log": ["tool-call-1", "tool-call-2", ...]
}
```

This format includes:
- A summary of the completed task
- List of files that were created or modified
- A base64-encoded PNG snapshot of any Simulink model
- A log of the tool calls that were executed

## Runtime Flow

The ReAct loop in Agent.m follows this pattern:
1. PromptBuilder merges user text, truncated history, and tool list
2. LLM generates a tool call with arguments in JSON format
3. Dispatcher verifies the tool exists in ToolBox
4. The tool is executed and returns a result (string, struct, PNG)
5. Results are added to history and the loop continues until the task is complete

## Extensibility

- Add a new tool: drop a new .m file in +tools/ and add its handle in ToolBox.register()
- Swap LLM: edit llm/callGPT.m (response must stay JSON-parseable)
- Vision upgrade: Use createSnapshot to send PNG to vision-capable LLMs for spatial feedback

## Safety Guidelines

- All tool calls are wrapped in try/catch with error redaction
- Model size limits can be enforced to prevent resource issues
- Simulink.BlockDiagram.validate ensures model integrity before simulation
