function result = connect_block_ports(srcPortHandle, dstPortHandle)
    % CONNECT_BLOCK_PORTS Draw a signal line srcPort → dstPort
    % 
    % Inputs:
    %   srcPortHandle - Source port handle or block/port path
    %   dstPortHandle - Destination port handle or block/port path
    %
    % Output:
    %   result - Structure containing line handle and status
    
    try
        % Validate inputs
        if nargin < 2
            error('Source and destination port handles/paths must be specified');
        end
        
        % Convert port paths to handles if needed
        if ischar(srcPortHandle) || isstring(srcPortHandle)
            srcPortHandle = get_param(char(srcPortHandle), 'PortHandles');
            
            % If it's a block path, find its output port
            if ~isnumeric(srcPortHandle) && isfield(srcPortHandle, 'Outport')
                if numel(srcPortHandle.Outport) >= 1
                    srcPortHandle = srcPortHandle.Outport(1);
                else
                    error('Source block does not have output ports');
                end
            end
        end
        
        if ischar(dstPortHandle) || isstring(dstPortHandle)
            dstPortHandle = get_param(char(dstPortHandle), 'PortHandles');
            
            % If it's a block path, find its input port
            if ~isnumeric(dstPortHandle) && isfield(dstPortHandle, 'Inport')
                if numel(dstPortHandle.Inport) >= 1
                    dstPortHandle = dstPortHandle.Inport(1);
                else
                    error('Destination block does not have input ports');
                end
            end
        end
        
        % Ensure we have valid port handles
        if ~isnumeric(srcPortHandle) || ~isnumeric(dstPortHandle)
            error('Could not resolve port handles');
        end
        
        % Get the parent blocks for logging
        srcBlockHandle = get_param(srcPortHandle, 'Parent');
        dstBlockHandle = get_param(dstPortHandle, 'Parent');
        
        srcBlockName = getfullname(srcBlockHandle);
        dstBlockName = getfullname(dstBlockHandle);
        
        fprintf('Connecting from %s to %s\n', srcBlockName, dstBlockName);
        
        % Create the line
        lineHandle = add_line(get_param(srcBlockHandle, 'Parent'), srcPortHandle, dstPortHandle, 'autorouting', 'on');
        
        fprintf('Connection created successfully\n');
        
        % Get the model name
        modelName = bdroot(srcBlockHandle);
        
        % Get snapshot of the model
        try
            pngData = Simulink.BlockDiagram.createSnapshot(modelName);
            pngBase64 = base64encode(pngData);
        catch
            pngBase64 = '';
        end
        
        % Return result
        result = struct('status', 'success', ...
                       'lineHandle', lineHandle, ...
                       'sourceBlock', srcBlockName, ...
                       'destinationBlock', dstBlockName, ...
                       'modelName', modelName, ...
                       'snapshot', pngBase64);
        
    catch ME
        % Handle errors
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', 'error', errorMsg);
    end
end

function encoded = base64encode(data)
    % Simple base64 encoding for snapshot data
    import org.apache.commons.codec.binary.Base64;
    encoded = char(Base64.encodeBase64(data));
end