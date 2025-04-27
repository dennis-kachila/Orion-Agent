% LLM_SETTINGS Create or update LLM settings
% Run this script to save LLM settings

% Prompt for the API key instead of hardcoding it
apiKey = input('Enter your Gemini API key (input will be hidden): ', 's');
if isempty(apiKey)
    error('API key is required');
end

% Configure settings for the LLM provider
settings = struct();
settings.provider = 'gemini';  % Options: 'openai', 'gemini', 'local'
settings.apiKey = apiKey;  % Never hardcode API keys in source code
settings.model = 'gemini-pro';  % Model name 
settings.endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

% Save settings to MAT file
save('llm_settings.mat', 'settings');

fprintf('LLM settings saved successfully.\n');
fprintf('Provider: %s\n', settings.provider);
fprintf('Model: %s\n', settings.model);

% Clear the API key from workspace for security
clear apiKey settings
