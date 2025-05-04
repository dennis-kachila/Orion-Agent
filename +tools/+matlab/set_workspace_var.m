function result = set_workspace_var(varName, varValue)
    % SET_WORKSPACE_VAR Assign a variable in the base workspace
    % 
    % Inputs:
    %   varName - Name of the variable to set
    %   varValue - Value to assign to the variable
    %
    % Output:
    %   result - Structure containing status and variable info
    
    try
        % Check inputs
        if ~ischar(varName) && ~isstring(varName)
            error('Variable name must be a string');
        end
        
        % Convert string to char if needed
        if isstring(varName)
            varName = char(varName);
        end
        
        % Validate variable name
        if ~isvarname(varName)
            error('Invalid variable name: %s', varName);
        end
        
        fprintf('Setting workspace variable: %s\n', varName);
        
        % Assign to base workspace
        assignin('base', varName, varValue);
        
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
                       'description', varDesc);
        
    catch ME
        % Handle any errors
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', ...
                       'variableName', varName, ...
                       'error', errorMsg);
    end
end