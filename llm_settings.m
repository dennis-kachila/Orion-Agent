% LLM_SETTINGS Create or update LLM settings
% Run this script to save LLM settings

% Configure settings for the LLM provider
settings = struct();
settings.provider = 'gemini';  % Options: 'openai', 'gemini', 'local'
settings.apiKey = 'AIzaSyArhg4YI1-9EK-Rj2CC8Hs12d-tIFb9Wco';  % Your API key
settings.model = 'gemini-pro';  % Model name 
settings.endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

% Save settings to MAT file
save('llm_settings.mat', 'settings');

fprintf('LLM settings saved successfully.\n');
fprintf('Provider: %s\n', settings.provider);
fprintf('Model: %s\n', settings.model);
