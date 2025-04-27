function response = callGPT(prompt)
    % CALLGPT Communicates with OpenAI API or local Llama endpoint
    % Handles HTTP requests to LLM services and returns response
    %
    % Input:
    %   prompt - String or struct containing the prompt to send to LLM
    %
    % Output:
    %   response - String containing the LLM response
    
    % Configuration settings
    apiConfig = getAPIConfig();
    
    try
        if strcmpi(apiConfig.provider, 'openai')
            % Call OpenAI API
            response = callOpenAI(prompt, apiConfig);
        elseif strcmpi(apiConfig.provider, 'local')
            % Call local Llama API
            response = callLocalLLM(prompt, apiConfig);
        else
            error('Unknown LLM provider: %s', apiConfig.provider);
        end
    catch ME
        % Handle connection errors
        error('Error connecting to LLM: %s', ME.message);
    end
end

function apiConfig = getAPIConfig()
    % Get API configuration - either from environment or from settings file
    
    % Default to OpenAI
    apiConfig = struct('provider', 'openai', ...
                      'apiKey', '', ...
                      'model', 'gpt-4o', ...
                      'endpoint', 'https://api.openai.com/v1/chat/completions');
    
    % Look for OPENAI_API_KEY environment variable
    apiKey = getenv('OPENAI_API_KEY');
    if ~isempty(apiKey)
        apiConfig.apiKey = apiKey;
        return;
    end
    
    % Check for settings file
    try
        if exist('llm_settings.mat', 'file')
            load('llm_settings.mat', 'settings');
            
            % Use settings from file
            if isfield(settings, 'provider')
                apiConfig.provider = settings.provider;
            end
            
            if isfield(settings, 'apiKey')
                apiConfig.apiKey = settings.apiKey;
            end
            
            if isfield(settings, 'model')
                apiConfig.model = settings.model;
            end
            
            if isfield(settings, 'endpoint')
                apiConfig.endpoint = settings.endpoint;
            end
        end
    catch
        warning('Failed to load LLM settings file. Using defaults.');
    end
    
    % Validate config
    if strcmpi(apiConfig.provider, 'openai') && isempty(apiConfig.apiKey)
        warning(['OpenAI API key not found. Set the OPENAI_API_KEY environment variable ', ...
                'or configure it in the settings file.']);
    end
end

function response = callOpenAI(prompt, apiConfig)
    % Call OpenAI API with the given prompt
    
    % Prepare request options
    options = weboptions('ContentType', 'json', ...
                         'HeaderFields', {'Authorization', ['Bearer ', apiConfig.apiKey]});
    
    % Prepare request body
    if isstruct(prompt)
        % If prompt is already a structured request
        requestBody = prompt;
    else
        % Create a simple chat completion request
        requestBody = struct('model', apiConfig.model, ...
                           'messages', {{'role', 'system', 'content', 'You are a helpful MATLAB/Simulink assistant.'}, ...
                                       {'role', 'user', 'content', prompt}}, ...
                           'temperature', 0.7);
    end
    
    % Make the API call
    responseData = webwrite(apiConfig.endpoint, requestBody, options);
    
    % Extract the response text
    if isfield(responseData, 'choices') && ~isempty(responseData.choices)
        if isfield(responseData.choices{1}, 'message') && isfield(responseData.choices{1}.message, 'content')
            response = responseData.choices{1}.message.content;
        else
            error('Unexpected response format from OpenAI API');
        end
    else
        error('No completion choices returned from OpenAI API');
    end
end

function response = callLocalLLM(prompt, apiConfig)
    % Call local Llama API with the given prompt
    
    % Prepare request options
    options = weboptions('ContentType', 'json');
    
    % Prepare request body
    if isstruct(prompt)
        % Convert messages structure to local API format if needed
        requestBody = prompt;
    else
        % Create a simple completion request
        requestBody = struct('prompt', prompt, ...
                           'max_tokens', 1024, ...
                           'temperature', 0.7);
    end
    
    % Make the API call
    responseData = webwrite(apiConfig.endpoint, requestBody, options);
    
    % Extract the response text
    if isfield(responseData, 'content')
        response = responseData.content;
    elseif isfield(responseData, 'text')
        response = responseData.text;
    else
        error('Unexpected response format from local LLM API');
    end
end
