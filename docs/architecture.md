# Architecture

## Core Components and Their Roles

```mermaid
classDiagram
    class AgentAppChat {
        +UIFigure
        +Agent
        +IsProcessing
        +TaskTimer
        +send_user_input_to_llm()
        +processAgentRequest()
        +processAgentResponse()
        +updateChatHistory()
        +updateWorkflowLog()
    }
    
    class Agent {
        +ToolBox
        +chatHistory
        +llmInterface
        +toolLog
        +modifiedFiles
        +processUserInput()
        +redactErrorsLocal()
    }
    
    class ToolBox {
        -tools
        -toolDescriptions
        +register()
        +dispatchTool()
        +getToolDescriptions()
    }
    
    class LLMInterface {
        +callGPT()
        +getAPIConfig()
    }
    
    class Tools {
        +open_or_create_file()
        +run_code_or_file()
        +create_new_model()
        +simulate_model()
    }
    
    AgentAppChat --> Agent : owns
    Agent --> ToolBox : uses
    Agent --> LLMInterface : calls
    ToolBox --> Tools : dispatches to
```

## Runtime Flow inside Agent.m

```mermaid
graph TD
    U(User Prompt) --> P[PromptBuilder]
    P -->|System and History| L[callGPT]
    L -->|JSON: tool, args| D[Dispatcher]
    D -->|function handle| T[+tools/*]
    T --> R[Result string, struct, PNG]
    R --> H[history update]
    H --> P
    R --> UI[AgentChat pane]
```

- **PromptBuilder** (in promptTemplates.m) merges user text, truncated history, and the tool list.
- **Dispatcher** verifies the requested tool exists in ToolBox; if not, returns an error object for the LLM to reconsider (ReAct pattern).
- **History** keeps alternating Thought → Action → Observation triples, enabling multi-step planning.

## Debug Mode vs. Production Mode

```mermaid
flowchart LR
    Start[Agent Call] --> Check{API calls exceeded?}
    Check -->|Yes| Debug[Debug Mode:\nPredefined responses]
    Check -->|No| Production[Production Mode:\nReal LLM API call]
    Debug --> Response[Return JSON tool call]
    Production --> Response
```

In debug mode (default after 3 API calls), the system uses pattern matching on the user query to return appropriate predefined responses, allowing development and testing without API costs.