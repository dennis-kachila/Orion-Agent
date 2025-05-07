function result = run_code_file(fileName)
    % RUN_CODE_FILE Execute a named .m file
    % 
    % Inputs:
    %   fileName - Path to .m file
    %
    % Output:
    %   result - Structure containing execution output and status
    
    try
        % Check if file exists
        if ~exist(fileName, 'file')
            error('File does not exist: %s', fileName);
        end
        
        % Input is a file path
        fprintf('Running MATLAB file: %s\n', fileName);
        
        % Capture output from file execution
        commandStr = sprintf('run(''%s'')', fileName);
        output = evalc(commandStr);
        
        % Return result
        result = struct('status', 'success', ...
                       'source', 'file', ...
                       'fileName', fileName, ...
                       'output', output);
        
        fprintf('File execution completed successfully\n');
        
    catch ME
        % Handle any errors - use the local redactErrorsLocal function directly
        errorMsg = redactErrorsLocal(ME);
        
        result = struct('status', 'error', ...
                       'source', 'file', ...
                       'fileName', fileName, ...
                       'error', errorMsg);
    end
end

% Local fallback implementation of error redaction
function errorMsg = redactErrorsLocal(ME)
    % Simple error redaction function as a fallback
    msg = ME.message;
    % Remove absolute Windows paths
    msg = regexprep(msg, '[A-Za-z]:\\[^\s\n]*', '[REDACTED_PATH]');
    % Remove OneDrive or user directory references
    msg = regexprep(msg, 'OneDrive[^\s\n]*', '[REDACTED_ONEDRIVE]');
    msg = regexprep(msg, 'Users\\[^\s\n]*', '[REDACTED_USER]');
    % Remove email addresses
    msg = regexprep(msg, '[\w\.-]+@[\w\.-]+', '[REDACTED_EMAIL]');
    % Remove IP addresses
    msg = regexprep(msg, '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}', '[REDACTED_IP]');
    % Remove API keys (common patterns)
    msg = regexprep(msg, '(key-[a-zA-Z0-9]{32,})', '[REDACTED_API_KEY]');
    msg = regexprep(msg, '(sk-[a-zA-Z0-9]{32,})', '[REDACTED_API_KEY]');
    msg = regexprep(msg, 'AIza[a-zA-Z0-9_\-]{35}', '[REDACTED_API_KEY]');
    
    errorMsg = sprintf('Error: %s', msg);
    
    % Add a simplified stack trace
    if ~isempty(ME.stack)
        stackStr = '\nStack trace (simplified):\n';
        maxFrames = min(3, length(ME.stack));
        
        for i = 1:maxFrames
            frame = ME.stack(i);
            funcName = regexprep(frame.name, '[A-Za-z]:\\[^\s\n]*', '[REDACTED]');
            % Remove package paths but keep function name
            funcName = regexprep(funcName, '.*\.([^.]+)$', '$1');
            stackStr = [stackStr, sprintf('  - Function: %s, Line: %d\n', funcName, frame.line)];
        end
        
        errorMsg = [errorMsg, stackStr];
    end
end
