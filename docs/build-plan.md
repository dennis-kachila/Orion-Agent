# Build Plan (Step-by-Step)

Follow these steps to set up and use Orion Agent:

| Step | Action | Outcome |
|------|--------|---------|
| 1 | Clone the repo into a regular MATLAB project (so paths auto-load). | Orion-Agent added to MATLAB path. |
| 2 | Run `setup_paths.m` to ensure all directories are on the MATLAB path. | Required paths are set. |
| 3 | Configure the LLM: run `set_api_key.bat` or manually set your API key. | External reasoning engine reachable. |
| 4 | Unit-test tools: `runtests('tests')`. | Confirms that every wrapper works on your MATLAB version. |
| 5 | Start the agent: run `launch_agent.m`. | Agent instance is created and ready to use. |
| 6 | Interact: use the AgentChat interface to send a request like "Create a model with a Sine Wave feeding a Scope and simulate for 1 s." | Orion Agent executes the necessary tools and provides results. |

## Running the Agent

After completion of the build process:

1. The agent interface will appear with a chat panel on the left and a workflow panel on the right
2. Enter your request in the text area at the bottom of the chat panel
3. Click "Send" to process your request
4. The agent's thought process and actions will be displayed in the workflow log
5. Results, including any created files or model snapshots, will be shown in the appropriate areas
6. You can click "Stop" at any time to cancel an ongoing operation