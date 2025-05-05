function errorMsg = safeRedactErrors(ME)
    % SAFEREDACTERRORS Redacts error messages and stack traces for user display
    % This function provides a robust, self-contained error redaction utility.
    %
    % Input:
    %   ME - MException object from a try/catch block
    %
    % Output:
    %   errorMsg - Cleaned string representation of the error
    
    % Remove file paths and sensitive info from the error message
    msg = ME.message;
    % Remove absolute Windows paths (e.g., C:\Users\...)
    msg = regexprep(msg, '[A-Za-z]:\\[^\s\n]*', '[REDACTED_PATH]');
    % Remove OneDrive or user folder references
    msg = regexprep(msg, 'OneDrive[^\s\n]*', '[REDACTED_ONEDRIVE]');
    % Remove any remaining user directory patterns
    msg = regexprep(msg, 'Users\\[^\s\n]*', '[REDACTED_USER]');
    errorMsg = sprintf('Error: %s', msg);
    
    % Add a simplified stack trace if available
    if ~isempty(ME.stack)
        stackStr = '\nStack trace (simplified):\n';
        maxFrames = min(3, length(ME.stack));
        
        for i = 1:maxFrames
            frame = ME.stack(i);
            % Redact file paths in stack trace
            funcName = regexprep(frame.name, '[A-Za-z]:\\[^\s\n]*', '[REDACTED_PATH]');
            stackStr = [stackStr, sprintf('  - Function: %s, Line: %d\n', funcName, frame.line)];
        end
        
        errorMsg = [errorMsg, stackStr];
    end
end
