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
        fprintf('Attempting to call %s API (%d/%d calls used)...\n', apiConfig.provider, apiCallCount+1, MAX_API_CALLS);
        
        % Update the last call time
        lastCallTime = datetime('now');
        
        % Increment API call counter
        apiCallCount = apiCallCount + 1;
        
        if strcmpi(apiConfig.provider, 'openai')
            % Call OpenAI API
            response = callOpenAI(prompt, apiConfig);
        elseif strcmpi(apiConfig.provider, 'local')
            % Call local Llama API
            response = callLocalLLM(prompt, apiConfig);
        elseif strcmpi(apiConfig.provider, 'gemini')
            % Call Gemini API
            fprintf('Calling Gemini API...\n');
            
            % Prepare request endpoint with API key
            endpoint = [apiConfig.endpoint, '?key=', apiConfig.apiKey];
            
            % Redact API key in logs for security
            endpointDisplay = regexprep(endpoint, '(key=)([^&]+)', '$1[REDACTED]');
            fprintf('Full Gemini endpoint: %s\n', endpointDisplay);
            
            % Create web options with increased timeout only
            options = weboptions('ContentType', 'json', ...
                               'Timeout', 60);  % Increased timeout to 60 seconds
            
            response = callGemini(prompt, endpoint, options);
        else
            error('Unknown LLM provider: %s', apiConfig.provider);
        end
        
        fprintf('API call successful! (%d/%d calls used)\n', apiCallCount, MAX_API_CALLS);
        
        % % Show a preview of the response
        % if length(response) > 100
        %     responsePreview = [response(1:100), '...'];
        % else
        %     responsePreview = response;
        % end
        responsePreview = response; % Show the full response
        %fprintf('Response preview: %s\n', responsePreview);
        fprintf('Response in full: %s\n', responsePreview);
        
    catch ME
        % Handle connection errors with detailed debugging
        fprintf('ERROR calling LLM: %s\n', ME.message);
        
        if ~isempty(ME.stack)
            % Show the first few stack frames
            fprintf('Stack trace:\n');
            for i = 1:min(3, length(ME.stack))
                fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
            end
        end
        
        % Increment API call count anyway to avoid excessive retries in case of persistent failures
        apiCallCount = apiCallCount + 1;
        
        % Check if this is a timeout or connection error
        if contains(lower(ME.message), 'timeout') || contains(lower(ME.message), 'connection')
            fprintf('Network issue detected. You may want to check your internet connection.\n');
            fprintf('Consider the following troubleshooting steps:\n');
            fprintf('1. Check if your internet connection is stable\n');
            fprintf('2. Verify if the API endpoint is accessible from your network\n');
            fprintf('3. Try increasing the timeout value further in callGPT.m\n');
            fprintf('4. Check if a proxy server is required for your network\n');
        end
        
        fprintf('Switching to offline debug mode for this session.\n');
        debugMode = true;  % Switch to debug mode for subsequent calls
        
        % Get the user's request from the prompt to customize the debug response
        userQuery = extractUserQuery(prompt);
        
        % Provide appropriate debug responses based on the request
        if contains(userQuery, 'hello world') || contains(userQuery, 'print hello')
            fprintf('Returning debug fallback response for "hello world"...\n');
            response = '{"tool": "run_code", "args": {"codeStr": "disp(''Hello World!''); disp(''Counting from 1 to 10:''); for i = 1:10, disp(i); end"}}';
        elseif contains(userQuery, 'script') || contains(userQuery, 'create') || contains(userQuery, 'write')
            fprintf('Returning debug fallback response for "create script"...\n');
            scriptContent = sprintf('%%HELLO_WORLD - A simple script that prints hello world and counts\n\ndisp(''Hello World!'');\ndisp(''Counting from 1 to 10:'');\n\n%% Count from 1 to 10\nfor i = 1:10\n    disp(i);\nend');
            response = sprintf('{"tool": "open_editor", "args": {"fileName": "hello_world.m", "content": "%s"}}', regexprep(scriptContent, '(["\])', '\\$1'));
        else
            fprintf('Returning general debug fallback response...\n');
            response = '{\"tool\": \"run_code\", \"args\": {\"codeStr\": \"disp(''Hello World!''); for i = 1:10, disp(i); end\"}}';
        end
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

function response = callGemini(prompt, endpoint, options)
    % Call Google Gemini API with the given prompt
    
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
            % Check if the current message is a struct and has the content field
            if isstruct(messages{i}) && isfield(messages{i}, 'content')
                % Display role for debugging
                if isfield(messages{i}, 'role')
                    fprintf('Message %d role: %s\n', i, messages{i}.role);
                end
                % Add this message's content as a part
                allParts{end+1} = struct('text', messages{i}.content);
            end
        end
        
        % Create the contents structure with the collected parts
        contents = struct('parts', {allParts});
        
        % Create the final request body
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
        
        % Create a simple request with just one part
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
        % Get the first candidate - careful with indexing, it could be a struct array
        if isstruct(responseData.candidates) && length(responseData.candidates) >= 1
            candidate = responseData.candidates(1);  % Use parentheses for struct arrays
        else
            candidate = responseData.candidates{1};  % Use braces for cell arrays
        end
        
        candidateFields = fieldnames(candidate);
        fprintf('Candidate fields: %s\n', strjoin(candidateFields, ', '));
        
        if isfield(candidate, 'content')
            if isfield(candidate.content, 'parts') 
                % Check if parts is a cell array or struct array
                if iscell(candidate.content.parts) && ~isempty(candidate.content.parts)
                    part = candidate.content.parts{1};  % Use braces for cell arrays
                    fprintf('Found response part (cell)\n');
                elseif isstruct(candidate.content.parts) && length(candidate.content.parts) >= 1
                    part = candidate.content.parts(1);  % Use parentheses for struct arrays
                    fprintf('Found response part (struct)\n');
                else
                    error('Unexpected parts format in Gemini response');
                end
                
                if isfield(part, 'text')
                    rawText = part.text;
                    
                    % Clean up the response - remove markdown code formatting
                    % Check for markdown code blocks (```json ... ```)
                    response = cleanMarkdownCodeBlocks(rawText);
                    
                    fprintf('Successfully extracted text from response\n');
                else
                    if isstruct(part)
                        partFields = fieldnames(part);
                        fprintf('Part fields: %s\n', strjoin(partFields, ', '));
                    else
                        fprintf('Part is not a struct: %s\n', class(part));
                    end
                    error('Text field not found in Gemini response part');
                end
            else
                error('No parts field found in Gemini response content');
            end
        else
            error('No content field found in Gemini response candidate');
        end
    else
        if isfield(responseData, 'error')
            fprintf('Gemini API error: %s\n', responseData.error.message);
            error('Gemini API error: %s', responseData.error.message);
        else
            fprintf('Response data: %s\n', jsonencode(responseData));
            error('No candidates returned from Gemini API');
        end
    end
end

function userQuery = extractUserQuery(prompt)
    % Helper function to extract the user query from various prompt formats
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
    elseif ischar(prompt) || isstring(prompt)
        % If it's just a string, use the whole thing
        userQuery = lower(char(prompt));
    end
end

function cleanedText = cleanMarkdownCodeBlocks(text)
    % Helper function to extract content from markdown code blocks
    
    % First, check if the text contains a markdown code block
    if contains(text, '```')
        % Find positions of code block markers
        startPos = strfind(text, '```');
        
        if length(startPos) >= 2
            % Extract content between the first pair of ``` markers
            firstMarker = startPos(1);
            secondMarker = startPos(2);
            
            % Find the end of the first line containing ```
            lineEndPos = strfind(text(firstMarker:min(firstMarker+20, length(text))), newline);
            if ~isempty(lineEndPos)
                contentStart = firstMarker + lineEndPos(1);
            else
                % If no newline found, assume it's ```json followed by content
                contentStart = firstMarker + 6; % Length of ```xxx is roughly 6 chars
            end
            
            % Extract the content between markers
            if contentStart < secondMarker
                jsonContent = text(contentStart:secondMarker-1);
                
                % Trim whitespace
                jsonContent = strtrim(jsonContent);
                
                % If valid JSON, return it
                try
                    % Test if it's valid JSON by attempting to decode it
                    jsondecode(jsonContent);
                    cleanedText = jsonContent;
                    fprintf('Successfully extracted JSON from markdown code block\n');
                    return;
                catch
                    fprintf('Extracted content is not valid JSON, using fallback\n');
                end
            end
        end
    end
    
    % If no valid JSON found in markdown blocks, try to find JSON directly
    try
        % Look for { which typically indicates the start of a JSON object
        jsonStartPos = strfind(text, '{');
        if ~isempty(jsonStartPos)
            % Try to extract JSON starting from the first { character
            possibleJson = text(jsonStartPos(1):end);
            jsondecode(possibleJson); % Test if valid
            cleanedText = possibleJson;
            fprintf('Found JSON starting with { character\n');
            return;
        end
    catch
        % Not valid JSON
    end
    
    % Fallback: remove markdown formatting but keep the content
    % Replace ```xxx\n with nothing and ``` with nothing
    cleanedText = regexprep(text, '```[^\n]*\n', '');
    cleanedText = regexprep(cleanedText, '```', '');
    
    fprintf('Using plain text fallback (not valid JSON)\n');
end
