# Detailed Agent Workflow

## Complete Process Flow

When a user enters a prompt like "Create a hello world script that prints 1 to 10", here's the complete workflow that occurs:

```mermaid
sequenceDiagram
    participant User
    participant UI as AgentAppChat
    participant Agent
    participant LLM as llm.callGPT
    participant Tools as ToolBox
    participant FileSystem

    User->>UI: Enter prompt & click Send
    UI->>UI: Create background timer
    UI->>Agent: processUserInput(prompt)
    Agent->>Agent: Add to chat history
    Agent->>LLM: Generate tool call
    LLM-->>Agent: Return JSON response
    Agent->>Agent: Parse JSON (jsondecode)
    Agent->>Tools: dispatchTool(toolName, args)
    Tools->>FileSystem: Create/modify files
    FileSystem-->>Tools: Return result
    Tools-->>Agent: Return result & status
    Agent->>Agent: Log result
    Agent->>UI: Return final response
    UI->>User: Display result & update UI
```

## Step-by-Step Execution Flow

1. **Entry Point**: User runs `launch_agent.m` which sets up paths, error handling, and launches the UI
2. **UI Initialization**: `AgentAppChat` creates the interface and initializes the Agent instance
3. **User Input**: User enters prompt and clicks Send button
4. **Processing Setup**: 
   - UI updates with user message
   - Status changes to "Processing"
   - Background timer starts to keep UI responsive
5. **Agent Processing**:
   - Agent adds prompt to chat history
   - Builds LLM prompt with history and available tools
   - Enters ReAct loop (limited to max 3 iterations)
6. **LLM Decision**:
   - Calls `llm.callGPT` to determine next action
   - In debug mode, returns predefined responses based on request pattern
   - In production, calls external API (OpenAI or Gemini)
7. **Tool Execution**:
   - Parses JSON response to get tool name and arguments
   - Records tool call in history and logs
   - Dispatches to appropriate tool via ToolBox
   - For file creation, ensures workspace folder exists
8. **Result Processing**:
   - Tool returns structured result
   - Agent records result in history
   - Tracks modified files
   - Determines if task is complete
9. **Response Generation**:
   - Creates final JSON response with summary, files, log
   - Returns to UI for display
10. **UI Updates**:
    - Parses response
    - Updates chat with summary
    - Shows modified files in workflow log
    - Resets status to "Ready"
    - Cleans up timer resources

## Detailed Tool Flow for File Creation

When creating a file (like our hello world script), this detailed flow occurs:

```mermaid
flowchart TD
    A[User sends request] --> B[Agent processes input]
    B --> C{Debug mode?}
    C -->|Yes| D[Return predefined response: tool: open_or_create_file, args: ...]
    C -->|No| E[Call LLM API]
    E --> F[Parse LLM response]
    D --> G[Parse JSON response]
    G --> H[Dispatch open_or_create_file tool]
    H --> I[Create workspace directory if needed]
    I --> J[Write content to file]
    J --> K[Try to open in MATLAB editor]
    K --> L[Return result to Agent]
    L --> M[Update Agent history & logs]
    M --> N[Generate final response]
    N --> O[Display in UI]
```

## ReAct Loop Implementation

The core of Orion Agent is its implementation of the Reasoning-Acting (ReAct) loop pattern:

```mermaid
flowchart TB
    Start[Start ReAct Loop] --> Think[Think: Call LLM to decide next action]
    Think --> Act[Act: Execute chosen tool]
    Act --> Observe[Observe: Record result]
    Observe --> Decision{Task complete?}
    Decision -->|No| Think
    Decision -->|Yes| End[Return final response]
```

This pattern allows the agent to:
1. Reason about the best approach to solve a problem
2. Execute appropriate actions using MATLAB/Simulink tools
3. Observe the results and determine next steps
4. Continue until the task is complete or max iterations reached