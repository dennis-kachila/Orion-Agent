% LAUNCH_AGENT A simple launcher for the Orion Agent application
% Run this script from the main project directory to start the application

% Display debugging information
fprintf('=== Orion Agent Launcher (Debug Mode) ===\n');
fprintf('Current directory: %s\n', pwd);

% First, set up the paths
fprintf('Setting up paths...\n');
setup_paths;

% Test LLM availability
fprintf('Testing LLM configuration...\n');
try
    % Check if we have API keys configured
    hasOpenAI = ~isempty(getenv('OPENAI_API_KEY'));
    hasGemini = ~isempty(getenv('GEMINI_API_KEY'));
    hasSettings = exist('llm_settings.mat', 'file') == 2;
    
    if hasOpenAI
        fprintf('✓ OpenAI API key found in environment\n');
    elseif hasGemini
        fprintf('✓ Gemini API key found in environment\n');
    elseif hasSettings
        fprintf('✓ LLM settings file found\n');
        % Check contents of settings file
        try
            s = load('llm_settings.mat');
            if isfield(s, 'settings') && isfield(s.settings, 'provider')
                fprintf('  Provider: %s\n', s.settings.provider);
                if isfield(s.settings, 'apiKey') && ~isempty(s.settings.apiKey)
                    fprintf('  API key is configured\n');
                else
                    fprintf('  WARNING: API key is empty or missing\n');
                end
            end
        catch ME
            fprintf('  ERROR loading settings: %s\n', ME.message);
        end
    else
        fprintf('✗ No API keys found. Please set up your API key:\n');
        fprintf('  1. Run llm_settings.m or\n');
        fprintf('  2. Set OPENAI_API_KEY or GEMINI_API_KEY environment variable\n');
    end
catch ME
    fprintf('Error testing LLM configuration: %s\n', ME.message);
end

% Change to the app directory
fprintf('Changing to app directory...\n');
cd app;

% Launch the AgentChat application
fprintf('Launching AgentChat...\n');
AgentChat;

% Return to the original directory when done
cd ..;

fprintf('Application closed.\n');
