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
    
    % API call counter for rate limiting
    persistent apiCallCount;
    if isempty(apiCallCount)
        apiCallCount = 0;
    end
    
    % Max API calls allowed per session (strict limit)
    MAX_API_CALLS = 3;
    
    % Debug mode - set to false to make actual API calls
    debugMode = false;
    
    % Keep track of API call times for rate limiting
    persistent lastCallTime;
    if isempty(lastCallTime)
        lastCallTime = datetime('now') - hours(1); % Initialize with past time
    end
    
    % Rate limiting constants - ensure at least this many seconds between calls
    MIN_DELAY_SECONDS = 30; % Minimum delay between API calls to avoid rate limits
    
    % Check if we've exceeded our API call limit
    if apiCallCount >= MAX_API_CALLS && ~debugMode
        fprintf('API CALL LIMIT REACHED (%d/%d): Switching to debug mode to avoid excess charges\n', apiCallCount, MAX_API_CALLS);
        debugMode = true;
    end
    
    if debugMode
        fprintf('DEBUG MODE: Returning predefined response for development\n');
        
        % Get the user's request from the prompt to customize the response
        userQuery = extractUserQuery(prompt);
        
        % Provide appropriate debug responses based on the request
        if contains(userQuery, 'hello world') || contains(userQuery, 'print hello')
            % For hello world requests, use run_code_or_file for immediate output
            response = '{"tool": "run_code_or_file", "args": {"codeStr": "disp(''Hello World!''); disp(''Counting from 1 to 10:''); for i = 1:10, disp(i); end"}}';
        elseif contains(userQuery, 'script') || contains(userQuery, 'create') || contains(userQuery, 'write')
            % For script creation, use open_or_create_file with file content
            scriptContent = sprintf('%%HELLO_WORLD - A simple script that prints hello world and counts\n\ndisp(''Hello World!'');\ndisp(''Counting from 1 to 10:'');\n\n%% Count from 1 to 10\nfor i = 1:10\n    disp(i);\nend');
            response = sprintf('{"tool": "open_or_create_file", "args": {"fileName": "hello_world.m", "content": "%s"}}', regexprep(scriptContent, '(["\\])', '\\$1'));
        elseif contains(userQuery, 'simulink') || contains(userQuery, 'model')
            response = '{"tool": "create_new_model", "args": {"modelName": "example_model"}}';
        else
            % Default fallback response
            response = '{"tool": "respond", "args": {"message": "I understand your request. How can I assist you with MATLAB or Simulink today?"}}';
        end
        return;
    end
    
    % Continue with real API calls when not in debug mode
    fprintf('Making actual API call to LLM service...\n');
    
    % Check time since last API call for rate limiting
    timeSinceLastCall = seconds(datetime('now') - lastCallTime);
    
    if timeSinceLastCall < MIN_DELAY_SECONDS
        % Wait to avoid hitting rate limits
        pauseTime = MIN_DELAY_SECONDS - timeSinceLastCall;
        fprintf('Rate limiting: Waiting %.1f seconds before next API call\n', pauseTime);
        pause(pauseTime);
    end
    
    % Update call counter and time
    apiCallCount = apiCallCount + 1;
    lastCallTime = datetime('now');
    
    % Handle different API providers
    switch lower(apiConfig.provider)
        case 'openai'
            response = callOpenAI(prompt, apiConfig);
        case 'gemini'
            response = callGemini(prompt, apiConfig);
        case 'local'
            response = callLocalLLM(prompt, apiConfig);
        otherwise
            error('Unknown API provider: %s', apiConfig.provider);
    end
    
    fprintf('API call completed successfully\n');
end

function apiConfig = getAPIConfig()
    % GETAPICONFIG Retrieves API configuration from environment variables
    % This version prioritizes environment variables and doesn't rely on settings files
    
    persistent config;
    
    if isempty(config)
        % Initialize default config
        config = struct('provider', '', 'model', '', 'endpoint', '', 'apiKey', '');
        
        % Check for OpenAI API key
        openaiKey = getenv('OPENAI_API_KEY');
        if ~isempty(openaiKey)
            fprintf('Using OpenAI API key from environment variable\n');
            config.provider = 'openai';
            config.model = 'gpt-4';
            config.endpoint = 'https://api.openai.com/v1/chat/completions';
            config.apiKey = openaiKey;
        else
            % Check for Gemini API key
            geminiKey = getenv('GEMINI_API_KEY');
            if ~isempty(geminiKey)
                fprintf('Using Gemini API key from environment variable\n');
                config.provider = 'gemini';
                config.model = 'gemini-1.5-pro';
                config.endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent';
                config.apiKey = geminiKey;
            else
                % No valid API keys found, default to debug mode
                fprintf('No API keys found in environment variables\n');
                config.provider = 'openai'; % Still need a default provider for debug mode
                config.model = 'gpt-4';
                config.endpoint = 'https://api.openai.com/v1/chat/completions';
                config.apiKey = '';
            end
        end
    end
    
    apiConfig = config;
end

function userQuery = extractUserQuery(prompt)
    % EXTRACTUSERQUERY Extract the user's query from the prompt
    userQuery = '';
    
    try
        if ischar(prompt) || isstring(prompt)
            userQuery = char(prompt);
        elseif isstruct(prompt)
            % Look for user messages in the prompt
            if isfield(prompt, 'messages')
                messages = prompt.messages;
                for i = 1:length(messages)
                    if isfield(messages{i}, 'role') && strcmp(messages{i}.role, 'user')
                        if isfield(messages{i}, 'content')
                            userQuery = messages{i}.content;
                            break;
                        end
                    end
                end
            elseif isfield(prompt, 'content')
                userQuery = prompt.content;
            end
        end
    catch
        userQuery = '';
    end
    
    % If still empty, return placeholder
    if isempty(userQuery)
        userQuery = 'general assistance';
    end
end

function response = callOpenAI(prompt, config)
    % CALLOPENAI Call OpenAI API
    try
        % Prepare API request
        options = weboptions('HeaderFields', {'Content-Type', 'application/json', ...
                                             'Authorization', ['Bearer ', config.apiKey]}, ...
                            'Timeout', 60);
        
        % Build request body based on prompt type
        if ischar(prompt) || isstring(prompt)
            % Simple string prompt
            requestBody = struct('model', config.model, ...
                               'messages', {{{struct('role', 'user', 'content', char(prompt))}}}, ...
                               'temperature', 0.7);
        elseif isstruct(prompt) && isfield(prompt, 'messages')
            % Full message array
            requestBody = struct('model', config.model, ...
                               'messages', {prompt.messages}, ...
                               'temperature', 0.7);
        else
            error('Unsupported prompt format');
        end
        
        % Convert request to JSON
        requestJSON = jsonencode(requestBody);
        
        % Make API call
        fprintf('Calling OpenAI API endpoint: %s\n', config.endpoint);
        responseData = webwrite(config.endpoint, requestJSON, options);
        
        % Extract response content
        if isfield(responseData, 'choices') && ~isempty(responseData.choices)
            if isfield(responseData.choices{1}, 'message') && ...
               isfield(responseData.choices{1}.message, 'content')
                response = responseData.choices{1}.message.content;
            else
                error('Unexpected response format from OpenAI API');
            end
        else
            error('Empty response from OpenAI API');
        end
    catch ME
        % Handle API errors
        error('OpenAI API error: %s', ME.message);
    end
end

function response = callGemini(prompt, config)
    % CALLGEMINI Call Google Gemini API
    try
        % Prepare API request
        options = weboptions('HeaderFields', {'Content-Type', 'application/json', ...
                                             'x-goog-api-key', config.apiKey}, ...
                            'Timeout', 60);
        
        % Build request body for Gemini
        if ischar(prompt) || isstring(prompt)
            % Format for Gemini text-only prompt
            requestBody = struct('contents', struct('parts', struct('text', char(prompt))));
        elseif isstruct(prompt) && isfield(prompt, 'messages')
            % Convert message array format to Gemini format
            geminiContents = [];
            for i = 1:length(prompt.messages)
                msg = prompt.messages{i};
                if isfield(msg, 'role') && isfield(msg, 'content')
                    % Add formatted message
                    geminiContents(end+1) = struct('role', translateRole(msg.role), ...
                                                 'parts', struct('text', msg.content));
                end
            end
            requestBody = struct('contents', {geminiContents});
        else
            error('Unsupported prompt format');
        end
        
        % Convert request to JSON
        requestJSON = jsonencode(requestBody);
        
        % Make API call
        fprintf('Calling Gemini API endpoint: %s\n', config.endpoint);
        responseData = webwrite(config.endpoint, requestJSON, options);
        
        % Extract response content
        if isfield(responseData, 'candidates') && ~isempty(responseData.candidates)
            if isfield(responseData.candidates{1}, 'content') && ...
               isfield(responseData.candidates{1}.content, 'parts') && ...
               ~isempty(responseData.candidates{1}.content.parts) && ...
               isfield(responseData.candidates{1}.content.parts{1}, 'text')
                response = responseData.candidates{1}.content.parts{1}.text;
            else
                error('Unexpected response format from Gemini API');
            end
        else
            error('Empty response from Gemini API');
        end
    catch ME
        % Handle API errors
        error('Gemini API error: %s', ME.message);
    end
    
    function translatedRole = translateRole(role)
        % Translate roles from OpenAI format to Gemini format
        switch lower(role)
            case 'user'
                translatedRole = 'user';
            case 'assistant'
                translatedRole = 'model';
            case 'system'
                translatedRole = 'system';
            otherwise
                translatedRole = 'user';
        end
    end
end

function response = callLocalLLM(prompt, config)
    % CALLLLOCALLLM Call local LLM API (Ollama, LM Studio, etc)
    try
        % Prepare API request
        options = weboptions('HeaderFields', {'Content-Type', 'application/json'}, ...
                            'Timeout', 120); % Local LLMs might be slower
        
        % Build request body based on prompt type
        if ischar(prompt) || isstring(prompt)
            % Simple string prompt
            requestBody = struct('model', config.model, ...
                               'prompt', char(prompt), ...
                               'stream', false);
        elseif isstruct(prompt) && isfield(prompt, 'messages')
            % Full message array - convert to string
            promptStr = '';
            for i = 1:length(prompt.messages)
                msg = prompt.messages{i};
                if isfield(msg, 'role') && isfield(msg, 'content')
                    % Format message
                    promptStr = [promptStr, sprintf('<%s>\n%s\n</%s>\n\n', ...
                                                  msg.role, msg.content, msg.role)];
                end
            end
            requestBody = struct('model', config.model, ...
                               'prompt', promptStr, ...
                               'stream', false);
        else
            error('Unsupported prompt format');
        end
        
        % Convert request to JSON
        requestJSON = jsonencode(requestBody);
        
        % Make API call
        fprintf('Calling Local LLM API endpoint: %s\n', config.endpoint);
        responseData = webwrite(config.endpoint, requestJSON, options);
        
        % Extract response content
        if isfield(responseData, 'response')
            response = responseData.response;
        elseif isfield(responseData, 'text')
            response = responseData.text;
        elseif isfield(responseData, 'output')
            response = responseData.output;
        else
            error('Unexpected response format from Local LLM API');
        end
    catch ME
        % Handle API errors
        error('Local LLM API error: %s', ME.message);
    end
end
