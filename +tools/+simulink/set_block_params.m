function result = set_block_params(blockPath, params)
    % SET_BLOCK_PARAMS Set block parameters
    % 
    % Inputs:
    %   blockPath - Path to the block
    %   params - Structure of parameter name/value pairs 
    %
    % Output:
    %   result - Structure containing operation status and block info
    
    try
        % Validate inputs
        if nargin < 1 || isempty(blockPath)
            error('Block path must be specified');
        end
        
        if nargin < 2 || isempty(params) || ~isstruct(params)
            error('Parameters must be provided as a structure');
        end
        
        % Extract model name from block path
        parts = strsplit(blockPath, '/');
        if length(parts) < 2
            error('Invalid block path format: %s', blockPath);
        end
        
        modelName = parts{1};
        
        % Ensure the model is open
        if ~bdIsLoaded(modelName)
            error('Model %s is not loaded.', modelName);
        end
        
        % Check if block exists
        if ~exist(blockPath, 'block')
            error('Block does not exist: %s', blockPath);
        end
        
        % Get original block parameters for reference
        originalParams = struct();
        paramFields = fieldnames(params);
        for i = 1:length(paramFields)
            try
                originalParams.(paramFields{i}) = get_param(blockPath, paramFields{i});
            catch
                % Parameter might not exist yet, that's ok
                originalParams.(paramFields{i}) = '(not set)';
            end
        end
        
        % Set each parameter
        fprintf('Setting parameters for block: %s\n', blockPath);
        
        % Get parameter fields
        for i = 1:length(paramFields)
            paramName = paramFields{i};
            paramValue = params.(paramName);
            
            % Handle special cases for certain parameter types
            if isnumeric(paramValue)
                % Convert numeric to string if needed
                if isscalar(paramValue)
                    paramValue = num2str(paramValue);
                else
                    % For vector/matrix parameters
                    paramValue = mat2str(paramValue);
                end
            elseif islogical(paramValue)
                % Convert boolean to 'on'/'off' strings
                if paramValue
                    paramValue = 'on';
                else
                    paramValue = 'off';
                end
            elseif isstring(paramValue)
                % Convert MATLAB string to char
                paramValue = char(paramValue);
            end
            
            fprintf('  Setting %s = %s\n', paramName, paramValue);
            
            % Set the parameter
            set_param(blockPath, paramName, paramValue);
        end
        
        fprintf('Block parameters updated successfully\n');
        
        % Get a snapshot of the model
        try
            pngData = Simulink.BlockDiagram.createSnapshot(modelName);
            pngBase64 = base64encode(pngData);
        catch
            pngBase64 = '';
        end
        
        % Return result
        result = struct('status', 'success', ...
                       'summary', sprintf('Set parameters for block: %s', blockPath), ...
                       'blockPath', blockPath, ...
                       'modelName', modelName, ...
                       'updatedParams', params, ...
                       'originalParams', originalParams, ...
                       'snapshot', pngBase64);
        
    catch ME
        errorMsg = agent.utils.safeRedactErrors(ME);
        errorMsg = sprintf('An error occurred: %s\nIf this persists, please check your input or contact support.', errorMsg);
        result = struct('status', 'error', 'error', errorMsg, ...
                       'summary', sprintf('Failed to set block parameters: %s', errorMsg));
    end
end

function encoded = base64encode(data)
    % Simple base64 encoding for snapshot data
    import org.apache.commons.codec.binary.Base64;
    encoded = char(Base64.encodeBase64(data));
end