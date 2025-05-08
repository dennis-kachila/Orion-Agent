function secondsElapsed = safeTimeCalculation(startTime, endTime)
    % SAFETIMECALCULATION Safely calculate time difference in seconds between two datetime objects
    % Works with both older MATLAB (returning double) and newer MATLAB (returning duration)
    %
    % Usage:
    %   secondsElapsed = utils.safeTimeCalculation(startTime, endTime)
    %
    % Input:
    %   startTime - A datetime object representing the start time
    %   endTime   - A datetime object representing the end time
    %
    % Output:
    %   secondsElapsed - Time difference in seconds as a numeric value
    
    fprintf('\n*** ENTRY: safeTimeCalculation.m ***\n');
    fprintf('*** TIMESTAMP: %s ***\n', datetime("now", "Format", "yyyy-MM-dd HH:mm:ss.SSS"));
    localDebugInfo = struct('entryTime', datetime("now"), 'steps', {{}});
    localDebugInfo.steps{end+1} = 'Method entry';
    
    try
        % First try with seconds() function (newer MATLAB)
        localDebugInfo.steps{end+1} = 'Attempting to calculate using seconds() function';
        secondsElapsed = seconds(endTime - startTime);
        localDebugInfo.steps{end+1} = 'Successfully calculated time using seconds() function';
    catch
        % Fallback for older MATLAB versions
        localDebugInfo.steps{end+1} = 'seconds() function failed, using fallback method';
        try
            % Convert to seconds by multiplying by 86400 (seconds in a day)
            secondsElapsed = (endTime - startTime) * 86400;
            localDebugInfo.steps{end+1} = 'Successfully calculated time using multiplication method';
        catch
            % Last resort fallback
            secondsElapsed = 0;
            localDebugInfo.steps{end+1} = 'All calculation methods failed, returning 0';
            warning('Unable to calculate time difference between datetime objects');
        end
    end
    
    % At the end of the method
    exitTime = datetime("now");
    executionTime = (exitTime - localDebugInfo.entryTime) * 86400; % Convert to seconds
    
    fprintf('*** EXIT: safeTimeCalculation ***\n');
    fprintf('*** EXECUTION TIME: %.6f seconds ***\n', executionTime);
    fprintf('*** EXECUTION PATH (%d steps): ***\n', length(localDebugInfo.steps));
    for i = 1:length(localDebugInfo.steps)
        fprintf('***   Step %d: %s ***\n', i, localDebugInfo.steps{i});
    end
    fprintf('*** END OF FUNCTION EXECUTION ***\n');
end
