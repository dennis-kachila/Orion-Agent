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
        % Calculate time difference
        timeDiff = endTime - startTime;
        
        % Check if result is a duration object
        if isduration(timeDiff)
            localDebugInfo.steps{end+1} = 'Converting duration to seconds';
            secondsElapsed = seconds(timeDiff);
        else
            % For older MATLAB versions or if not a duration
            localDebugInfo.steps{end+1} = 'Using traditional calculation method';
            secondsElapsed = timeDiff * 86400; % Convert days to seconds
        end
        localDebugInfo.steps{end+1} = 'Time calculation successful';
    catch ME
        % Handle any errors gracefully
        warning('TimeCalcError:Failed', '%s', ME.message);
        secondsElapsed = 0;
        localDebugInfo.steps{end+1} = sprintf('Error in calculation: %s', ME.message);
    end
    
    % For the function's own execution time reporting, use the traditional method
    exitTime = datetime("now");
    try
        executionTime = double(seconds(exitTime - localDebugInfo.entryTime));
    catch
        executionTime = double((exitTime - localDebugInfo.entryTime) * 86400);
    end
    
    fprintf('*** EXIT: safeTimeCalculation.m ***\n');
    fprintf('*** EXECUTION TIME: %.6f seconds ***\n', executionTime);
    fprintf('*** EXECUTION PATH (%d steps): ***\n', length(localDebugInfo.steps));
    for i = 1:length(localDebugInfo.steps)
        fprintf('***   Step %d: %s ***\n', i, localDebugInfo.steps{i});
    end
    fprintf('*** END OF FUNCTION EXECUTION ***\n');
end
