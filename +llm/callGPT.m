function response = callGPT(prompt)
    % CALLGPT Communicates with OpenAI API or local Llama endpoint
    % Handles HTTP requests to LLM services and returns response
    %
    % Input:
    %   prompt - String or struct containing the prompt to send to LLM
    %
    % Output:
    %   response - String containing the LLM response
    
    % Add debug output
    fprintf('=== LLM API Call Debug ===\n');
    
    % Configuration settings
    apiConfig = getAPIConfig();
    fprintf('Provider: %s\n', apiConfig.provider);
    fprintf('Model: %s\n', apiConfig.model);
    fprintf('Endpoint: %s\n', apiConfig.endpoint);
    
    % Use proper if-else instead of ternary operator
    if ~isempty(apiConfig.apiKey)
        fprintf('Has API Key: %s\n', 'Yes');
    else
        fprintf('Has API Key: %s\n', 'No');
    end
    
    % Debug mode - bypass actual API call and return a working response
    % Set to true to avoid API charges and rate limits
    debugMode = true;
    
    % Keep track of API call times for rate limiting
    persistent lastCallTime;
    if isempty(lastCallTime)
        lastCallTime = datetime('now') - hours(1); % Initialize with past time
    end
    
    % Rate limiting constants
    MIN_DELAY_SECONDS = 10; % Minimum delay between API calls to avoid rate limits
    
    if debugMode
        fprintf('DEBUG MODE: Returning predefined response for development\n');
        
        % Get the user's request from the prompt to customize the response
        userQuery = '';
        if isstruct(prompt) && isfield(prompt, 'messages')
            % Look for the latest user message
            for i = numel(prompt.messages):-1:1
                if isfield(prompt.messages{i}, 'role') && ...
                   strcmp(prompt.messages{i}.role, 'user') && ...
                   isfield(prompt.messages{i}, 'content')
                    userQuery = lower(prompt.messages{i}.content);
                    break;
                end
            end
        end
        
        % Provide appropriate debug responses based on the request
        if contains(userQuery, 'hello world') || contains(userQuery, 'print hello')
            % For hello world requests, use run_code for immediate output
            response = '{"tool": "run_code", "args": {"codeStr": "disp(''Hello World!''); disp(''Counting from 1 to 10:''); for i = 1:10, disp(i); end"}}';
        elseif contains(userQuery, 'script') || contains(userQuery, 'create') || contains(userQuery, 'write')
            % For script creation, use open_editor with file content
            scriptContent = sprintf('%%HELLO_WORLD - A simple script that prints hello world and counts\n\ndisp(''Hello World!'');\ndisp(''Counting from 1 to 10:'');\n\n%% Count from 1 to 10\nfor i = 1:10\n    disp(i);\nend');
            response = sprintf('{"tool": "open_editor", "args": {"fileName": "hello_world.m", "content": "%s"}}', regexprep(scriptContent, '(["\])', '\\$1'));
        elseif contains(userQuery, 'simulink') || contains(userQuery, 'model')
            response = '{"tool": "new_model", "args": {"modelName": "example_model"}}';
        else
            % Default fallback response
            response = '{"tool": "run_code", "args": {"codeStr": "disp(''I am processing your request: ' + regexprep(userQuery, '''', '''''') + ''');"}}';
        end
        
        fprintf('Response: %s\n', response);
        fprintf('========================\n');
        return;
    end
    
    % Check if enough time has passed since the last call
    timeSinceLastCall = seconds(datetime('now') - lastCallTime);
    if timeSinceLastCall < MIN_DELAY_SECONDS
        % Need to wait before making another call
        waitTime = MIN_DELAY_SECONDS - timeSinceLastCall;
        fprintf('Rate limiting: Waiting %.1f seconds before next API call...\n', waitTime);
        pause(waitTime);
    end
    
    try
        fprintf('Attempting to call %s API...\n', apiConfig.provider);
        
        % Update the last call time
        lastCallTime = datetime('now');
        
        if strcmpi(apiConfig.provider, 'openai')
            % Call OpenAI API
            response = callOpenAI(prompt, apiConfig);
        elseif strcmpi(apiConfig.provider, 'local')
            % Call local Llama API
            response = callLocalLLM(prompt, apiConfig);
        elseif strcmpi(apiConfig.provider, 'gemini')
            % Call Google Gemini API
            response = callGemini(prompt, apiConfig);
        else
            error('Unknown LLM provider: %s', apiConfig.provider);
        end
        
        fprintf('API call successful!\n');
        
        % Show a preview of the response
        if length(response) > 100
            responsePreview = [response(1:100), '...'];
        else
            responsePreview = response;
        end
        fprintf('Response preview: %s\n', responsePreview);
        
    catch ME
        % Handle connection errors with detailed debugging
        fprintf('ERROR calling LLM: %s\n', ME.message);
        
        if length(ME.stack) > 0
            fprintf('Error occurred in: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
        end
        
        % If we hit rate limits, wait longer next time
        if contains(ME.message, 'Too Many Requests') || contains(ME.message, '429')
            fprintf('Rate limit exceeded. Increasing delay for next request.\n');
            MIN_DELAY_SECONDS = MIN_DELAY_SECONDS * 2; % Double the delay
            lastCallTime = datetime('now'); % Reset timer
        end
        
        % Create a default dummy response for development/debug
        fprintf('Returning debug fallback response...\n');
        response = '{"tool": "run_code", "args": {"codeStr": "disp(''Hello World!''); for i = 1:10, disp(i); end"}}';
    end
    
    fprintf('========================\n');
end

function apiConfig = getAPIConfig()
    % Get API configuration - either from environment or from settings file
    
    % Default to Gemini but with empty API key
    apiConfig = struct('provider', 'gemini', ...
                      'apiKey', '', ...
                      'model', 'gemini-1.5-pro', ...
                      'endpoint', 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent');
    
    % Look for API environment variables
    apiKey = getenv('OPENAI_API_KEY');
    if ~isempty(apiKey)
        apiConfig.provider = 'openai';
        apiConfig.apiKey = apiKey;
        apiConfig.model = 'gpt-4o';
        apiConfig.endpoint = 'https://api.openai.com/v1/chat/completions';
        return;
    end
    
    geminiKey = getenv('GEMINI_API_KEY');
    if ~isempty(geminiKey)
        apiConfig.provider = 'gemini';
        apiConfig.apiKey = geminiKey;
        apiConfig.model = 'gemini-1.5-pro';  % Updated to latest model name
        apiConfig.endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent';
        return;
    end
    
    % Check for settings file
    try
        if exist('llm_settings.mat', 'file')
            fprintf('Loading LLM settings from file...\n');
            load('llm_settings.mat', 'settings');
            
            % Use settings from file
            if isfield(settings, 'provider')
                apiConfig.provider = settings.provider;
                fprintf('Provider from settings: %s\n', settings.provider);
            end
            
            if isfield(settings, 'apiKey')
                apiConfig.apiKey = settings.apiKey;
                if ~isempty(settings.apiKey)
                    fprintf('API key from settings: Present (not shown)\n');
                else
                    fprintf('API key from settings: Empty\n');
                end
            end
            
            if isfield(settings, 'model')
                apiConfig.model = settings.model;
                fprintf('Model from settings: %s\n', settings.model);
                
                % Update endpoint if model is specified
                if strcmpi(settings.provider, 'gemini')
                    apiConfig.endpoint = ['https://generativelanguage.googleapis.com/v1beta/models/', settings.model, ':generateContent'];
                    fprintf('Updated endpoint: %s\n', apiConfig.endpoint);
                end
            end
            
            if isfield(settings, 'endpoint')
                apiConfig.endpoint = settings.endpoint;
                fprintf('Endpoint from settings: %s\n', settings.endpoint);
            end
        end
    catch ME
        warning('Failed to load LLM settings file: %s', '%s', ME.message);
    end
    
    % Validate config
    if strcmpi(apiConfig.provider, 'openai') && isempty(apiConfig.apiKey)
        warning(['OpenAI API key not found. Set the OPENAI_API_KEY environment variable ', ...
                'or configure it in the settings file.']);
    elseif strcmpi(apiConfig.provider, 'gemini') && isempty(apiConfig.apiKey)
        warning(['Gemini API key not found. Set the GEMINI_API_KEY environment variable ', ...
                'or run the llm_settings.m script to configure it.']);
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

function response = callGemini(prompt, apiConfig)
    % Call Google Gemini API with the given prompt
    
    % Add API key to the endpoint URL
    endpoint = [apiConfig.endpoint, '?key=', apiConfig.apiKey];
    fprintf('Full Gemini endpoint: %s\n', endpoint);
    
    % Prepare request options
    options = weboptions('ContentType', 'json');
    
    % Debug request structure
    fprintf('Preparing Gemini request...\n');
    
    % Prepare request body
    if isstruct(prompt) && isfield(prompt, 'messages')
        % Convert OpenAI-style messages to Gemini format
        messages = prompt.messages;
        fprintf('Converting %d messages to Gemini format\n', numel(messages));
        
        % Collect all the parts
        allParts = {};
        
        % Process each message
        for i = 1:numel(messages)
            if isfield(messages{i}, 'content')
                fprintf('Message %d role: %s\n', i, messages{i}.role);
                allParts{end+1} = struct('text', messages{i}.content);
            end
        end
        
        contents = struct('parts', {allParts});
        
        requestBody = struct('contents', contents, ...
                           'generationConfig', struct('temperature', 0.7, ...
                                                   'maxOutputTokens', 2048));
    else
        % Create a simple text request
        if ischar(prompt) || isstring(prompt)
            promptText = char(prompt);
        else
            promptText = 'Please assist with this MATLAB/Simulink task';
        end
        
        fprintf('Using simple text prompt: %s\n', promptText(1:min(30, length(promptText))));
        
        requestBody = struct('contents', struct('parts', {{struct('text', promptText)}}), ...
                          'generationConfig', struct('temperature', 0.7, ...
                                                  'maxOutputTokens', 2048));
    end
    
    % Show request body preview
    requestJson = jsonencode(requestBody);
    fprintf('Request JSON preview: %s...\n', requestJson(1:min(100, length(requestJson))));
    
    % Make the API call
    fprintf('Sending request to Gemini API...\n');
    responseData = webwrite(endpoint, requestBody, options);
    
    % Output response data structure for debugging
    responseFields = fieldnames(responseData);
    fprintf('Response fields: %s\n', strjoin(responseFields, ', '));
    
    % Extract the response text
    if isfield(responseData, 'candidates') && ~isempty(responseData.candidates)
        candidate = responseData.candidates{1};
        candidateFields = fieldnames(candidate);
        fprintf('Candidate fields: %s\n', strjoin(candidateFields, ', '));
        
        if isfield(candidate, 'content') && isfield(candidate.content, 'parts') && ~isempty(candidate.content.parts)
            part = candidate.content.parts{1};
            fprintf('Found response part\n');
            
            if isfield(part, 'text')
                response = part.text;
                fprintf('Successfully extracted text from response\n');
            else
                partFields = fieldnames(part);
                fprintf('Part fields: %s\n', strjoin(partFields, ', '));
                error('Text field not found in Gemini response part');
            end
        else
            error('No content or parts found in Gemini response');
        end
    else
        if isfield(responseData, 'error')
            fprintf('Gemini API error: %s\n', responseData.error.message);
            error('Gemini API error: %s', responseData.error.message);
        else
            error('No candidates returned from Gemini API');
        end
    end
end
