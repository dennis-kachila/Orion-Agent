# Project Layout

The Orion Agent project has the following structure:

```
Orion-Agent/
│
├── +agent/                  % core decision loop
│   ├── Agent.m              % ReAct controller; owns chat history
│   ├── ToolBox.m            % registers callable tools
│
├── +llm/
│   ├── callGPT.m            % webwrite → OpenAI, Gemini, or local Llama
│   └── promptTemplates.m    % System & few-shot templates
│
├── +tools/                  % thin wrappers around MATLAB/Simulink APIs
│   ├── +general/
│   │   └── doc_search.m     % find_system / web search of MathWorks help
│   ├── +matlab/
│   │   ├── check_code_lint.m     % checks code for errors and style issues
│   │   ├── commit_git_repo.m     % commits changes to git repository
│   │   ├── get_workspace_var.m   % retrieves value of workspace variable
│   │   ├── open_or_create_file.m % creates or opens a file in editor
│   │   ├── read_file_content.m   % reads contents of a file
│   │   ├── run_code_file.m       % evalc wrapper that runs a MATLAB .m file
│   │   ├── run_unit_tests.m      % executes unit tests
│   │   ├── set_workspace_var.m   % sets value of workspace variable
│   │   └── write_file_contents.m % writes content to a file
│   └── +simulink/
│       ├── auto_layout.m          % Simulink.BlockDiagram.arrangeSystem
│       ├── close_current_model.m  % closes the active Simulink model
│       ├── connect_block_ports.m  % add_line to connect model elements
│       ├── create_new_model.m     % new_system + open_system
│       ├── disconnect_block_ports.m % removes connections between blocks
│       ├── get_block_params.m     % retrieves parameters of blocks
│       ├── insert_library_block.m % add_block wrapper (makes name unique)
│       ├── open_existing_model.m  % opens an existing Simulink model
│       ├── remove_block.m         % removes blocks from model
│       ├── save_current_model.m   % saves the current model
│       ├── set_block_params.m     % sets parameters on blocks
│       └── simulate_model.m       % out = sim(mdl,'ReturnWorkspaceOutputs','on')
│
├── app/
│   ├── AgentApp.mlapp       % App Designer source for the agent UI
│   ├── AgentAppChat.m       % Enhanced Chat interface for interacting with the agent
│   ├── (image files like 2.png, broom.png etc.)
│
├── docs/                    % Detailed documentation
│   ├── README.md
│   ├── api-capabilities.md
│   ├── architecture.md
│   ├── build-plan.md
│   ├── project-layout.md    % This file
│   ├── SUMMARY.md
│   ├── ui-implementation.md
│   └── workflow.md
│
├── Layout/                  % UI screenshots
│   ├── app_ui.png
│   └── app.png
│
├── orion_workspace/         % Working directory for agent-generated files
│
├── tests/
│   └── t_basic.m            % ensures each tool works on clean MATLAB
│
├── Instructions.md          % General instructions
├── launch_agent.m           % script to start the Orion Agent
├── README.md                % Project overview and documentation (main)
├── set_api_key.bat          % Windows batch file to set API key environment variable
└── setup_paths.m            % adds necessary directories to MATLAB path
```

This structure organizes code into MATLAB package folders (those with `+` prefix) with specialized domains.