function result = run_code(codeStr)
    % RUN_CODE Wrapper for evalc to execute arbitrary MATLAB code
    % Captures console output and returns it as a string
    %
    % Input:
    %   codeStr - String containing MATLAB code to execute
    %
    % Output:
    %   result - Structure containing output and status
    
    try
        % Execute the code and capture output
        output = evalc(codeStr);
        
        % Return successful result
        result = struct('status', 'success', 'output', output);
    catch ME
        % Handle execution errors
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', 'error', errorMsg);
    end
end
