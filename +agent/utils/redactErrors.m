function redactedError = redactErrors(ME)
    % REDACTERRORS Strips stack traces before they're sent to the LLM
    % Removes sensitive information like file paths from error messages
    %
    % Input:
    %   ME - MException object from a try/catch block
    %
    % Output:
    %   redactedError - Cleaned string representation of the error
    
    % Get the error message
    errorMsg = ME.message;
    
    % Remove file paths
    redactedError = regexprep(errorMsg, 'File: [^\n]*', 'File: [REDACTED]');
    
    % Remove any absolute paths that might be in the message
    redactedError = regexprep(redactedError, '([A-Za-z]:\\[^:"\s\n\r]+)', '[REDACTED_PATH]');
    redactedError = regexprep(redactedError, '(/[^:"\s\n\r]+)', '[REDACTED_PATH]');
    
    % Limit stack trace
    if ~isempty(ME.stack)
        % Include only the function name and line number for the first few stack frames
        stackStr = 'Stack trace (limited):\n';
        
        maxStackFrames = min(3, length(ME.stack));
        for i = 1:maxStackFrames
            frame = ME.stack(i);
            % Only include function name and line, not full file path
            stackStr = [stackStr, sprintf('  - Function: %s, Line: %d\n', ...
                frame.name, frame.line)];
        end
        
        redactedError = [redactedError, '\n', stackStr];
    end
end
