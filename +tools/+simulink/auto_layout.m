function result = auto_layout(modelName, systemPath)
    % AUTO_LAYOUT Automatically arrange blocks in a model or subsystem
    % 
    % Inputs:
    %   modelName - (Optional) Name of the model to arrange, defaults to current model
    %   systemPath - (Optional) Path to specific subsystem to arrange
    %
    % Output:
    %   result - Structure containing operation status
    
    try
        % Validate input
        if nargin < 1 || isempty(modelName)
            modelName = bdroot;
            if isempty(modelName)
                error('No model is currently open');
            end
        end
        
        % Check if model is loaded
        if ~bdIsLoaded(modelName)
            error('Model %s is not loaded', modelName);
        end
        
        % Determine system to arrange
        if nargin < 2 || isempty(systemPath)
            systemPath = modelName;
        else
            % If systemPath doesn't contain modelName prefix, add it
            if ~contains(systemPath, [modelName, '/'])
                systemPath = [modelName, '/', systemPath];
            end
            
            % Verify that the system exists
            if ~exist(systemPath, 'block')
                error('System %s does not exist', systemPath);
            end
        end
        
        fprintf('Arranging blocks in %s...\n', systemPath);
        
        % Get snapshot before layout
        try
            pngDataBefore = Simulink.BlockDiagram.createSnapshot(modelName);
        catch
            pngDataBefore = [];
        end
        
        % Perform automatic layout
        Simulink.BlockDiagram.arrangeSystem(systemPath);
        
        fprintf('Blocks arranged successfully\n');
        
        % Get snapshot after layout
        try
            pngDataAfter = Simulink.BlockDiagram.createSnapshot(modelName);
            pngBeforeBase64 = base64encode(pngDataBefore);
            pngAfterBase64 = base64encode(pngDataAfter);
        catch
            pngBeforeBase64 = '';
            pngAfterBase64 = '';
        end
        
        % Return result
        result = struct('status', 'success', ...
                       'summary', sprintf('Auto-arranged model layout for %s.', modelName), ...
                       'modelName', modelName, ...
                       'systemPath', systemPath, ...
                       'snapshotBefore', pngBeforeBase64, ...
                       'snapshotAfter', pngAfterBase64);
        
    catch ME
        % Handle any errors
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', ...
                       'summary', sprintf('Failed to auto-arrange model: %s', errorMsg), ...
                       'error', errorMsg);
        
        fprintf('Error arranging blocks: %s\n', errorMsg);
    end
end

function encoded = base64encode(data)
    % Simple base64 encoding
    import org.apache.commons.codec.binary.Base64;
    encoded = char(Base64.encodeBase64(data));
end