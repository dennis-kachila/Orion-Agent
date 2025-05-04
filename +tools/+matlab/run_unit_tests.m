function result = run_unit_tests(testFolder, testName)
    % RUN_UNIT_TESTS Run matlab.unittest suite in current project
    % 
    % Inputs:
    %   testFolder - (Optional) Folder containing test files
    %   testName - (Optional) Specific test or pattern to run
    %
    % Output:
    %   result - Structure containing test results and status
    
    import matlab.unittest.TestSuite;
    import matlab.unittest.TestRunner;
    import matlab.unittest.plugins.TAPPlugin;
    import matlab.unittest.plugins.ToFile;
    
    try
        
        fprintf('Running MATLAB unit tests\n');
        
        % Handle test folder specification
        if nargin < 1 || isempty(testFolder)
            % Look for common test folders relative to current directory
            commonTestFolders = {'tests', 'test', 'Tests', 'testing', '+tests'};
            
            testFolder = '';
            for i = 1:length(commonTestFolders)
                if exist(commonTestFolders{i}, 'dir')
                    testFolder = commonTestFolders{i};
                    break;
                end
            end
            
            if isempty(testFolder)
                % Default to current folder if no test folder found
                testFolder = pwd;
                fprintf('No specific test folder found. Using current directory.\n');
            else
                fprintf('Found test folder: %s\n', testFolder);
            end
        end
        
        % Discover tests based on inputs
        if nargin < 2 || isempty(testName)
            fprintf('Discovering all tests in %s\n', testFolder);
            suite = TestSuite.fromFolder(testFolder);
        else
            fprintf('Running specific test(s): %s in %s\n', testName, testFolder);
            
            % If testName is a full class name, run it directly
            if exist(testName, 'class')
                suite = TestSuite.fromClass(testName);
            else
                % Try to find test by name pattern
                suite = TestSuite.fromFolder(testFolder, 'Name', ['*' testName '*']);
                
                % If no tests found, try more aggressively
                if isempty(suite)
                    allTests = TestSuite.fromFolder(testFolder);
                    matchIdx = [];
                    for i = 1:length(allTests)
                        testClassName = class(allTests(i).TestClass);
                        if contains(lower(testClassName), lower(testName))
                            matchIdx(end+1) = i;
                        end
                    end
                    
                    if ~isempty(matchIdx)
                        suite = allTests(matchIdx);
                    end
                end
            end
        end
        
        fprintf('Found %d test case(s)\n', length(suite));
        
        % Set up test runner
        runner = TestRunner.withTextOutput;
        
        % Set up TAP output for machine readable results
        tapFile = fullfile(tempdir, 'test_results.tap');
        runner.addPlugin(TAPPlugin.producingVersion13(ToFile(tapFile)));
        
        % Run the tests
        testResults = runner.run(suite);
        
        % Calculate summary statistics
        totalCount = length(testResults);
        passedCount = sum([testResults.Passed]);
        failedCount = sum([testResults.Failed]);
        incompleteCount = sum([testResults.Incomplete]);
        
        passRate = 0;
        if totalCount > 0
            passRate = passedCount / totalCount * 100;
        end
        
        % Create test summary list
        testSummary = cell(totalCount, 1);
        for i = 1:totalCount
            status = '';
            if testResults(i).Passed
                status = 'PASSED';
            elseif testResults(i).Failed
                status = 'FAILED';
            else
                status = 'INCOMPLETE';
            end
            testSummary{i} = sprintf('%s.%s: %s (%.2fs)', ...
                class(testResults(i).TestClass), testResults(i).Name, ...
                status, testResults(i).Duration);
        end
        
        % Parse TAP file for more details (if needed)
        tapContent = '';
        if exist(tapFile, 'file')
            fid = fopen(tapFile, 'r');
            if fid ~= -1
                tapContent = fscanf(fid, '%c', inf);
                fclose(fid);
            end
        end
        
        % Return success result
        result = struct('status', 'success', ...
                       'totalTests', totalCount, ...
                       'passedTests', passedCount, ...
                       'failedTests', failedCount, ...
                       'incompleteTests', incompleteCount, ...
                       'passRate', passRate, ...
                       'testSummary', {testSummary}, ...
                       'tapOutput', tapContent);
        
        fprintf('Test execution complete. Pass rate: %.1f%% (%d/%d passed)\n', ...
            passRate, passedCount, totalCount);
        
    catch ME
        % Handle any errors
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', ...
                       'error', errorMsg);
        
        fprintf('Error running tests: %s\n', errorMsg);
    end
end