function result = doc_search(query)
    % DOC_SEARCH Searches documentation or finds blocks in libraries
    % Combines find_system for blocks and web search for documentation
    %
    % Input:
    %   query - Search query string
    %
    % Output:
    %   result - Structure containing search results
    
    try
        % First try to find matching blocks in libraries
        try
            blocks = find_system('SearchDepth', 0, 'Name', query);
            blockResults = cell(numel(blocks), 1);
            
            for i = 1:numel(blocks)
                blockPath = char(blocks(i));
                blockResults{i} = struct('path', blockPath, 'type', 'block');
            end
        catch
            blockResults = {};
        end
        
        % Try to search documentation
        try
            % This will open documentation in browser
            docLink = ['matlab:doc ', query];
            docResults = struct('link', docLink, 'type', 'documentation');
        catch
            docResults = struct('link', '', 'type', 'documentation', 'error', 'Documentation search failed');
        end
        
        % Return combined results
        result = struct('status', 'success', ...
                       'query', query, ...
                       'blockResults', {blockResults}, ...
                       'docResults', docResults);
    catch ME
        % Handle errors
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', 'error', errorMsg);
    end
end
