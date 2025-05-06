# Orion Agent Documentation

## Overview

Orion Agent is an in-process AI companion that converts natural–language requests into MATLAB® scripts and Simulink® models, executes them, inspects results, and iterates—without any GUI-level mouse automation.

It achieves this by exposing a curated set of programmatic "tools" (functions) to a Large-Language Model (LLM). A lightweight ReAct loop stored in memory decides which tool to call next, receives structured feedback (block handles, simulation outputs, error objects), and plans subsequent actions until the user's goal is met.

This documentation provides comprehensive guidance on how Orion Agent works, its architecture, and how to use and extend it.

## Getting Started

To begin using Orion Agent:

1. Clone the repo into a regular MATLAB project (so paths auto-load)
2. Run `setup_paths.m` to ensure all directories are on the MATLAB path
3. Configure the LLM by running `set_api_key.bat` or manually setting your API key
4. Verify everything works by running unit tests: `runtests('tests')`
5. Start the agent by running `launch_agent.m`
6. Interact using the AgentChat interface with requests like "Create a model with a Sine Wave feeding a Scope and simulate for 1 s."

For more details, see the [Build Plan](./build-plan.md) section.