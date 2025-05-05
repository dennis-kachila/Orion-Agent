function result = remove_block(blockPath)
    % REMOVE_BLOCK Delete a block from the model
    % 
    % Input:
    %   blockPath - Path to the block to remove
    %
    % Output:
    %   result - Structure containing operation status
    
    try
        % Validate input
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
        
        fprintf('Removing block: %s\n', blockPath);
        
        % Get snapshot before removal for comparison
        try
            pngDataBefore = Simulink.BlockDiagram.createSnapshot(modelName);
        catch
            pngDataBefore = [];
        end
        
        % Remove the block
        delete_block(blockPath);
        
        fprintf('Block removed successfully\n');
        
        % Get snapshot after removal
        try
            pngDataAfter = Simulink.BlockDiagram.createSnapshot(modelName);
            pngBase64 = base64encode(pngDataAfter);
        catch
            pngBase64 = '';
        end
        
        % Return result
        result = struct('status', 'success', ...
                       'summary', sprintf('Removed block: %s from model %s', blockPath, modelName), ...
                       'removedBlockPath', blockPath, ...
                       'modelName', modelName, ...
                       'snapshot', pngBase64);
        
    catch ME
        % Handle errors
        errorMsg = agent.utils.safeRedactErrors(ME);
        errorMsg = sprintf('An error occurred: %s\nIf this persists, please check your input or contact support.', errorMsg);
        result = struct('status', 'error', 'error', errorMsg, ...
                       'summary', sprintf('Failed to remove block: %s', errorMsg));
    end
end

function encoded = base64encode(data)
    % Simple base64 encoding for snapshot data
    import org.apache.commons.codec.binary.Base64;
    encoded = char(Base64.encodeBase64(data));
end