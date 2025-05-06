# APIs and Capabilities

## MATLAB and Simulink APIs

Orion Agent uses documented MATLAB and Simulink APIs to perform operations programmatically. These stable APIs ensure compatibility across MATLAB versions.

| Capability | MATLAB/Simulink call | Description |
|------------|----------------------|-------------|
| Insert block programmatically | `add_block(source,dest)` | Adds blocks to Simulink models |
| Connect ports | `add_line(model,src,dst)` | Creates connections between blocks |
| Clean diagram layout | `Simulink.BlockDiagram.arrangeSystem(model)` | Automatically arranges blocks for better readability |
| Query / set parameters | `get_param`, `set_param` | Reads and modifies block parameters |
| Add annotations / notes | `add_block('built-in/Note', …)` | Creates text annotations in models |
| Discover library paths | `find_system('SearchDepth',0,'Name',query)` | Searches for blocks in Simulink libraries |
| Build and run simulation | `sim(model,'ReturnWorkspaceOutputs','on')` | Executes simulations and returns results |
| Evaluate free-form code | `evalc(codeStr)` | Executes arbitrary MATLAB code with captured output |

## Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| LLM | GPT-4o (OpenAI REST) or local Llama 3 served over HTTP | Reasoning + code generation |
| MATLAB engine | Direct API calls from within MATLAB | Invokes MATLAB commands, opens/edits models |
| Simulink programmatic API | `add_block`, `add_line`, etc. | Create & mutate diagrams |
| Desktop Editor API | `matlab.desktop.editor` functions | Open/modify .m, .mlx files programmatically |
| HTTP client | `webwrite`, `webread` | Talk to the LLM endpoint |
| UI | App Designer (`AgentAppChat.m`) | Enhanced chat pane + workflow visualization |
| Tests | `matlab.unittest` | Regression and acceptance criteria |
| Version control | Git | Track code and generated models |

## Extensibility Hooks

- **Add a new tool**: Drop my_tool.m in the appropriate +tools/ subfolder, add its handle in ToolBox.register().
- **Swap LLM**: Edit llm/callGPT.m. Response must stay JSON-parseable.
- **CI regression**: Integrate tests/ into GitHub Actions using the MathWorks-hosted runner.
- **Vision upgrade**: Inside tools/simulink/auto_layout.m, call createSnapshot and send the PNG to GPT-4o-Vision for spatial feedback.

## Safety Guidelines

- Wrap every tool call in try/catch; pipe the MException through utils/redactErrors to avoid leaking file paths.
- Hard-limit model size: e.g., raise a warning if numel(find_system(mdl,'Type','block')) > 1000.
- Use Simulink.BlockDiagram.validate after structural edits to guarantee the diagram compiles before simulation.