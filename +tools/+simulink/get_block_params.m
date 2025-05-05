function result = get_block_params(blockPath, paramNames)
    % GET_BLOCK_PARAMS Get block parameters
    % 
    % Inputs:
    %   blockPath - Path to the block
    %   paramNames - (Optional) Cell array of parameter names to get
    %                If empty, returns common parameters
    %
    % Output:
    %   result - Structure containing block parameters and status
    
    try
        % Validate inputs
        if nargin < 1 || isempty(blockPath)
            error('Block path must be specified');
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
        
        fprintf('Getting parameters for block: %s\n', blockPath);
        
        % Get block type
        blockType = get_param(blockPath, 'BlockType');
        
        % Determine parameters to retrieve
        if nargin < 2 || isempty(paramNames)
            % Default parameters to retrieve (common ones first)
            defaultParams = {'Name', 'BlockType', 'Position', 'Tag', 'Description'};
            
            % Add block-type specific parameters
            switch blockType
                case 'Inport'
                    typeParams = {'Port', 'OutDataTypeStr'};
                case 'Outport'
                    typeParams = {'Port', 'IconDisplay', 'OutDataTypeStr'};
                case 'SubSystem'
                    typeParams = {'MaskType', 'ShowPortLabels'};
                case 'Gain'
                    typeParams = {'Gain', 'Multiplication'};
                case 'Constant'
                    typeParams = {'Value', 'OutDataTypeStr'};
                case 'Delay'
                    typeParams = {'DelayLength', 'InitialCondition'};
                case 'DiscreteTransferFcn'
                    typeParams = {'Numerator', 'Denominator', 'SampleTime'};
                case 'Scope'
                    typeParams = {'NumInputPorts', 'TimeSpan'};
                case 'Mux'
                    typeParams = {'Inputs', 'DisplayOption'};
                case 'Sin'
                    typeParams = {'Amplitude', 'Frequency', 'Phase'};
                case 'Product'
                    typeParams = {'Inputs', 'Multiplication'};
                case 'Sum'
                    typeParams = {'Inputs', 'IconShape'};
                case 'Integrator'
                    typeParams = {'InitialCondition', 'ExternalReset'};
                otherwise
                    typeParams = {};
            end
            
            % Combine default and type-specific parameters
            paramNames = [defaultParams, typeParams];
        elseif ischar(paramNames) || isstring(paramNames)
            % Convert single parameter name to cell array
            paramNames = {char(paramNames)};
        end
        
        % Get the parameters
        params = struct();
        notFoundParams = {};
        
        for i = 1:length(paramNames)
            paramName = paramNames{i};
            try
                paramValue = get_param(blockPath, paramName);
                
                % Store in result structure
                params.(paramName) = paramValue;
            catch ME
                % Parameter not found
                notFoundParams{end+1} = paramName;
                fprintf('  Warning: Parameter %s not available for this block\n', paramName);
            end
        end
        
        % Get block handle
        blockHandle = get_param(blockPath, 'Handle');
        
        % Get a snapshot of the model if possible
        try
            pngData = Simulink.BlockDiagram.createSnapshot(modelName);
            pngBase64 = base64encode(pngData);
        catch
            pngBase64 = '';
        end
        
        % Return result
        result = struct('status', 'success', ...
                       'summary', sprintf('Retrieved parameters for block: %s', blockPath), ...
                       'blockPath', blockPath, ...
                       'blockType', blockType, ...
                       'blockHandle', blockHandle, ...
                       'modelName', modelName, ...
                       'parameters', params);
        
        % Add unavailable parameters if there were any
        if ~isempty(notFoundParams)
            result.unavailableParams = notFoundParams;
        end
        
        % Add model snapshot if available
        if ~isempty(pngBase64)
            result.snapshot = pngBase64;
        end
        
    catch ME
        % Handle errors
        errorMsg = ME.message; % (No longer used, replaced by safeRedactErrors)
        result = struct('status', 'error', 'error', errorMsg, ...
                       'summary', sprintf('Failed to get block parameters: %s', errorMsg));
    end
end

function encoded = base64encode(data)
    % Simple base64 encoding for snapshot data
    import org.apache.commons.codec.binary.Base64;
    encoded = char(Base64.encodeBase64(data));
end