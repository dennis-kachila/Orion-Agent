function result = get_workspace_var(varName)
    % GET_WORKSPACE_VAR Retrieve a variable from the base workspace
    % 
    % Input:
    %   varName - Name of the variable to retrieve
    %
    % Output:
    %   result - Structure containing variable data and status
    
    try
        % Check input
        if ~ischar(varName) && ~isstring(varName)
            error('Variable name must be a string');
        end
        
        % Convert string to char if needed
        if isstring(varName)
            varName = char(varName);
        end
        
        fprintf('Getting workspace variable: %s\n', varName);
        
        % Check if variable exists in base workspace
        varExists = evalin('base', sprintf('exist(''%s'', ''var'')', varName));
        
        if varExists ~= 1
            error('Variable "%s" does not exist in the base workspace', varName);
        end
        
        % Get the variable from base workspace
        varValue = evalin('base', varName);
        
        % Get variable size and type for info
        varSize = size(varValue);
        varClass = class(varValue);
        
        % Prepare description based on type
        if isnumeric(varValue) || islogical(varValue)
            if isscalar(varValue)
                varDesc = sprintf('%g (%s)', varValue, varClass);
            else
                varDesc = sprintf('%s %s array', mat2str(varSize), varClass);
            end
        elseif ischar(varValue)
            if size(varValue, 1) <= 1
                % Single line string
                if length(varValue) > 50
                    varDesc = sprintf('"%s..." (%d chars)', varValue(1:min(50, length(varValue))), length(varValue));
                else
                    varDesc = sprintf('"%s" (%d chars)', varValue, length(varValue));
                end
            else
                % Multi-line string
                varDesc = sprintf('%dx%d char array', size(varValue, 1), size(varValue, 2));
            end
        elseif isstruct(varValue)
            fields = fieldnames(varValue);
            varDesc = sprintf('struct with fields: %s', strjoin(fields, ', '));
        elseif iscell(varValue)
            varDesc = sprintf('%s cell array', mat2str(varSize));
        elseif istable(varValue)
            varDesc = sprintf('table with %d rows, %d variables', height(varValue), width(varValue));
        elseif isobject(varValue)
            varDesc = sprintf('%s object', class(varValue));
        else
            varDesc = sprintf('%s type', varClass);
        end
        
        % Return success result
        result = struct('status', 'success', ...
                       'variableName', varName, ...
                       'variableClass', varClass, ...
                       'variableSize', varSize, ...
                       'variableValue', varValue, ...
                       'description', varDesc);
        
    catch ME
        % Handle any errors
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', ...
                       'variableName', varName, ...
                       'error', errorMsg);
    end
end