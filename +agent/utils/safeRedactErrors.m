function errorMsg = safeRedactErrors(ME)
    % SAFEREDACTERRORS Safely calls redactErrors with a fallback
    % This function attempts to call agent.utils.redactErrors and falls back
    % to a simple error message if that function is not available
    %
    % Input:
    %   ME - MException object from a try/catch block
    %
    % Output:
    %   errorMsg - Cleaned string representation of the error
    
    try
        % Try to use the full redactErrors function
        errorMsg = agent.utils.redactErrors(ME);
    catch
        % Simple fallback if redactErrors can't be found
        errorMsg = sprintf('Error: %s', ME.message);
        
        % Add a simplified stack trace if available
        if ~isempty(ME.stack)
            stackStr = '\nStack trace (simplified):\n';
            maxFrames = min(3, length(ME.stack));
            
            for i = 1:maxFrames
                frame = ME.stack(i);
                stackStr = [stackStr, sprintf('  - Function: %s, Line: %d\n', ...
                    frame.name, frame.line)];
            end
            
            errorMsg = [errorMsg, stackStr];
        end
    end
end
