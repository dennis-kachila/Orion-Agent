    % CALLGPT Communicates with OpenAI API or local Llama endpoint
    % Handles HTTP requests to LLM services and returns response
    %
    % Input:
    %   prompt - String or struct containing the prompt to send to LLM
    %
    % Output:
    %   response - String containing the LLM response
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
    persistent apiCallHistory;
    persistent sessionStartTime;
    persistent rateLimit429Count;
    
    % Initialize persistent variables if empty
    if isempty(apiCallCount)
        apiCallCount = 0;
        apiCallHistory = [];
        sessionStartTime = datetime('now');
        rateLimit429Count = 0;
    end
    
    % Max API calls allowed per session (strict limit)
    MAX_API_CALLS = 30;  % Increased from 3
    
    % Max API calls per minute (Gemini usually allows 60 QPM for paid tier, but we're conservative)
    MAX_QPM = 3;  % Reduced from 5
    
    % Calculate recent call frequency
    currentTime = datetime('now');
    recentCalls = 0;
    
    if ~isempty(apiCallHistory)
        % Count calls in the last 60 seconds
        recentCalls = sum(seconds(currentTime - apiCallHistory) <= 60);
        fprintf('API call stats: %d total calls this session, %d calls in last 60 seconds\n', ...
                apiCallCount, recentCalls);
        
        % Display timestamp of each recent call
        fprintf('Recent API call times:\n');
        for i = max(1, length(apiCallHistory)-5):length(apiCallHistory)
            fprintf('  %s (%.1f seconds ago)\n', ...
                    string(apiCallHistory(i)), seconds(currentTime - apiCallHistory(i)));
        end
        
        % Show rate limit error count if any
        if rateLimit429Count > 0
            fprintf('Rate limit errors encountered: %d\n', rateLimit429Count);
        end
    else
        fprintf('API call stats: No previous calls in this session\n');
    end
    
    % Get debug mode setting from centralized Config
    debugMode = agent.Config.useDebugAPIResponse();
    
    if debugMode
        fprintf('Debug mode is active: Using hardcoded response instead of making API calls\n');
        
        % Generate a properly formatted JSON response that the agent can use
        fprintf('DEBUG MODE: Generating a hardcoded test response instead of calling the API\n');
        
        % Extract user query for context (simplified, doesn't need to work perfectly in debug mode)
        userQuery = "Hardcoded test query - no actual API calls made";
        fprintf('Testing with hardcoded response for query: %s\n', userQuery);
        
        % Use a hardcoded response for testing tool chaining
        % String concatenation with proper syntax (no trailing semicolon)
        response = [
            '{',...
            '"reasoning": "I need to create a MATLAB script to plot a sine wave and its derivative. I will first create the file using open_or_create_file and include code that generates a figure with both plots. After creating the file, I will execute it using run_code_file to generate the visualization.",',...
            '"summary": "Created a MATLAB script to plot a sine wave and its derivative, and then executed it.",',...
            '"tool": "open_or_create_file",',...
            '"args": {',...
            '  "fileName": "plot_sine_and_derivative.m",',...
            '  "content": "t = 0:0.1:10;\\ny = sin(t);\\ndy = cos(t);\\n\\nfigure;\\nplot(t, y);\\nhold on;\\nplot(t, dy);\\nhold off;\\n\\ntitle(''Sine Wave and its Derivative'');\\nxlabel(''Time'');\\nylabel(''Amplitude'');\\nlegend(''sin(t)'', ''cos(t)'');\\ngrid on;"',...
            '},',...
            '"files": [',...
            '  "plot_sine_and_derivative.m"',...
            '],',...
            '"log": [',...
            '  {"tool": "open_or_create_file", "args": {"fileName": "plot_sine_and_derivative.m"}},',...
            '  {"tool": "run_code_file", "args": {"fileName": "plot_sine_and_derivative.m"}}',...
            ']',...
            '}'
        ];
        
        fprintf('Hardcoded response ready for testing tool chaining\n');
        return;
    end
    
    % Continue with real API calls (this code will never execute in test mode)
    fprintf('Making actual API call to LLM service...\n');
    
    % Check time since last API call for rate limiting with inline safe calculation
    timeSinceLastCall = utils.safeTimeCalculation(currentTime, lastCallTime);
    
    fprintf('Time since last API call: %.2f seconds\n', timeSinceLastCall);
    
    if timeSinceLastCall < MIN_DELAY_SECONDS
        % Wait to avoid hitting rate limits
        pauseTime = MIN_DELAY_SECONDS - timeSinceLastCall;
        fprintf('Rate limiting: Waiting %.1f seconds before next API call\n', pauseTime);
        pause(pauseTime);
    end
    
    % Update call counter and time
    apiCallCount = apiCallCount + 1;
    apiCallHistory = [apiCallHistory; currentTime];
    lastCallTime = currentTime;
    
    % Handle different API providers
    try
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
        
        % Clean up markdown code blocks if present to ensure proper JSON parsing later
        response = cleanMarkdownCodeBlocks(response);
        
    catch ME
        % If we hit a rate limit error, remember this for future calls
        if contains(ME.message, 'Too Many Requests') || contains(ME.message, '429')
            fprintf('RATE LIMIT ERROR DETECTED: Forcing longer delay for future calls\n');
            
            % Update rate limit counter
            rateLimit429Count = rateLimit429Count + 1;
            
            % Double the minimum delay for future calls
            MIN_DELAY_SECONDS = MIN_DELAY_SECONDS * 1.5;
            
            % If using Gemini, create a properly formatted tool response instead of an error
            % This allows the agent to continue functioning instead of breaking
            if strcmpi(apiConfig.provider, 'gemini')
                fprintf('Creating fallback tool response for Gemini rate limit\n');
                response = sprintf('{"tool": "run_code", "args": {"codeStr": "disp(''API rate limit reached (HTTP 429)'');\\ndisp(''Please wait at least %d seconds before trying again'');"}}', round(MIN_DELAY_SECONDS));
                return;
            else
                % For other providers, return an error in standard format
                errorMsg = sprintf('API rate limit reached (HTTP 429). Please wait at least %d seconds before trying again.', round(MIN_DELAY_SECONDS));
                response = sprintf('{"error": "%s"}', errorMsg);
                return;
            end
        end
        
        % Re-throw the error
        rethrow(ME);
    end
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
                config.model = 'gemini-1.5-flash'; % Changed from gemini-1.5-pro to gemini-1.5-flash
                config.endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
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
    % CALLGEMINI Call Google Gemini API with improved response handling
    try
        % Prepare API request
        options = weboptions('HeaderFields', {'Content-Type', 'application/json'; ...
                                             'x-goog-api-key', config.apiKey}, ...
                            'Timeout', 120);
        
        requestBody = struct(); % Initialize requestBody
        system_prompt_text = '';

        if isstruct(prompt) && isfield(prompt, 'messages')
            % Extract system prompt first, if any
            tempMessages = prompt.messages;
            isSystemMsg = cellfun(@(m) isfield(m, 'role') && strcmpi(m.role, 'system'), tempMessages);
            systemMsgIndices = find(isSystemMsg);
            
            if ~isempty(systemMsgIndices)
                % Use the content of the first system message found
                system_prompt_text = tempMessages{systemMsgIndices(1)}.content;
                % Remove system messages from tempMessages so they aren't added to 'contents'
                tempMessages(systemMsgIndices) = []; 
            end
            
            % Convert remaining message array format to Gemini format for 'contents'
            num_messages = length(tempMessages);
            if num_messages == 0 && isempty(system_prompt_text) && ~(ischar(prompt) || isstring(prompt))
                 error('OrionAgent:callGemini:NoMessagesAfterSystemFilter', 'No user/assistant messages left after filtering system prompt and prompt is not a simple string.');
            end

            geminiContents = cell(1, num_messages); 
            valid_msg_idx = 0; 

            for i = 1:num_messages
                msg = tempMessages{i};
                if isfield(msg, 'role') && isfield(msg, 'content') && ~isempty(strtrim(char(msg.content)))
                    translated_role_val = translateRole(msg.role, 'Gemini');
                    
                    if isempty(translated_role_val) % This handles skipping roles not meant for 'contents'
                        % This case should ideally not be hit if system roles are pre-filtered
                        warning('OrionAgent:callGemini:SkippingMessageInContents', 'Skipping message with role ''%s'' from ''contents'' array as it is not translatable to a Gemini content role (e.g. system role handled separately).', msg.role);
                        continue; 
                    end
                    
                    valid_msg_idx = valid_msg_idx + 1;
                    current_part = struct('text', char(msg.content));
                    geminiContents{valid_msg_idx} = struct('role', translated_role_val, ...
                                                           'parts', {{current_part}}); 
                else
                    warning('OrionAgent:callGemini:SkippingMalformedMessage', 'Skipping malformed or empty message at index %d.', i);
                end
            end
            
            if valid_msg_idx > 0
                geminiContents = geminiContents(1:valid_msg_idx); 
                requestBody.contents = geminiContents; 
            elseif isempty(system_prompt_text) && ~(ischar(prompt) || isstring(prompt))
                 % Only error if there are no contents AND no system prompt AND not a simple string prompt
                 error('OrionAgent:callGemini:NoValidContents', 'No valid messages to form ''contents'' and no system prompt or simple string prompt provided.');
            end

        elseif ischar(prompt) || isstring(prompt)
            % Single user message (no explicit system prompt from this input type alone)
            part = struct('text', char(prompt));
            content_item = struct('role', 'user', 'parts', {{part}}); 
            requestBody.contents = {{content_item}};
        else
            error('OrionAgent:callGemini:UnsupportedPrompt', 'Unsupported prompt format for Gemini');
        end

        % Add systemInstruction if a system prompt was found and extracted
        if ~isempty(system_prompt_text)
            system_part = struct('text', char(system_prompt_text));
            requestBody.systemInstruction = struct('parts', {{system_part}}); % Changed to systemInstruction (camelCase)
        end
        
        % Ensure there's something to send
        if ~isfield(requestBody, 'contents') && ~isfield(requestBody, 'systemInstruction') % Changed to systemInstruction
            error('OrionAgent:callGemini:EmptyRequestBody', 'Cannot send an empty request to Gemini. No contents or system instruction generated.');
        end

        % Convert request to JSON
        requestJSON = jsonencode(requestBody);
        fprintf('Gemini Request JSON: %s\n', requestJSON); % DEBUG LINE
        
        % Make API call
        fprintf('Calling Gemini API endpoint: %s\n', config.endpoint);
        responseData = webwrite(config.endpoint, requestJSON, options);
        
        % Extract response content with improved handling for Gemini structure
        if isfield(responseData, 'candidates') && ~isempty(responseData.candidates)
            candidate = responseData.candidates;
            % Handle both cell array and direct structure formats
            if iscell(candidate)
                candidate = candidate{1};
            end
            
            if isfield(candidate, 'content') && ...
               isfield(candidate.content, 'parts') && ...
               ~isempty(candidate.content.parts)
                
                parts = candidate.content.parts;
                % Handle both cell array and direct structure formats for parts
                if iscell(parts)
                    parts = parts{1};
                end
                
                if isfield(parts, 'text')
                    response = parts.text;
                    % Clean any markdown code blocks at this stage
                    response = cleanMarkdownCodeBlocks(response);
                else
                    error('Missing text field in Gemini response parts structure');
                end
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
    
    function translatedRole = translateRole(role, targetApi)
        % TRANSLATEROLE Translates roles between OpenAI and other API formats (e.g., Gemini)
        % targetApi can be 'Gemini' or other identifiers if more are added.
        
        translatedRole = ''; % Default to empty, indicating not translatable if not explicitly set
        
        if nargin < 2
            targetApi = 'openai'; % Default to openai if not specified
        end

        switch lower(targetApi)
            case 'gemini'
                switch lower(role)
                    case 'user'
                        translatedRole = 'user';
                    case 'assistant'
                        translatedRole = 'model';
                    case 'system'
                        % This role is handled by extracting to system_instruction
                        % Return empty so it's not added to 'contents' by the caller
                        translatedRole = ''; 
                    otherwise
                        warning('OrionAgent:translateRole:UnknownRoleForGemini', 'Gemini: Unknown role ''%s'' encountered. Treating as ''user''.', role);
                        translatedRole = 'user'; % Fallback for unknown roles
                end
            otherwise % Includes 'openai' or any other unspecified target
                translatedRole = lower(role); % No translation needed or simple lowercase
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

function cleanedResponse = cleanMarkdownCodeBlocks(response)
    % CLEANMARKDOWNCODEBLOCKS Remove markdown code block formatting from responses
    % This helps ensure JSON can be properly parsed later
    
    % First check if we need processing (performance optimization)
    if ~contains(response, '```')
        cleanedResponse = response;
        return;
    end
    
    % Extract content from code blocks if present
    try
        % Match for markdown code blocks with optional language specifier
        % Example: ```json ... ``` or just ``` ... ```
        pattern = '```(?:json|javascript|js)?\s*([\s\S]*?)\s*```';
        
        % Find if there are code blocks
        [matches, ~] = regexp(response, pattern, 'tokens', 'match');
        
        % If we found code blocks, extract the content
        if ~isempty(matches) && ~isempty(matches{1})
            % Use the content of the first code block (usually the JSON payload)
            cleanedResponse = matches{1}{1};
            fprintf('Extracted content from markdown code block\n');
        else
            % No code blocks found, return original
            cleanedResponse = response;
        end
    catch
        % If any error in parsing, return original to be safe
        cleanedResponse = response;
    end
end
