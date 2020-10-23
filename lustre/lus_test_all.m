% validate lus2slx compiler
bdclose('all')
regression_test_path = fileparts(mfilename('fullpath'));
test_folder = fullfile(regression_test_path,'unit_tests');


destination = fullfile(regression_test_path,'result');
if ~exist(destination, 'dir'); mkdir(destination); end
previous_tests = dir(fullfile(destination,'regression_result_*.csv'));
if ~isempty(previous_tests)
    previous_tests_name = {previous_tests.name};
    for test=previous_tests_name
        full_name = fullfile(destination,test{1});
        cmd = sprintf('rm %s', full_name);
        system(cmd);
    end
end
previous_tests =  dir(fullfile(destination,'not_valid_models_*.csv'));
if ~isempty(previous_tests)
    previous_tests_name = {previous_tests.name};
    for test=previous_tests_name
        full_name = fullfile(destination,test{1});
        cmd = sprintf('rm %s', full_name);
        system(cmd);
    end
end


lus_runner(test_folder, destination);

bdclose('all')