function lus_runner(source, destination)
    % validate lus2slx compiler
    bdclose('all')
    regression_path = fullfile(source);
    
    addpath(fullfile(source));
    
    
    display_msg('Starting', Constants.INFO, 'Lustre to Simulink Regression', '');
    
    lus_files = dir(fullfile(regression_path,'*.lus'));
    lus_names = {lus_files.name};
    n = numel(lus_names);
    
    lus_file_nb_bytes = zeros(n,1);
    valid = zeros(n,1);
    lustrec_failed = zeros(n,1);
    lustrec_binary_failed = zeros(n,1);
    sim_failed = zeros(n,1);
    
    for i=1:n
        lus_full_path = fullfile(regression_path, char(lus_names{i}));
        try
            [valid_i, lustrec_failed_i, lustrec_binary_failed_i, sim_failed_i] = validate_lus2slx( lus_full_path);
        catch ME
            display_msg(ME.message, Constants.ERROR, 'Runner', '');
            display_msg(ME.getReport(), Constants.DEBUG, 'Runner', '');
            valid_i = -1;
            lustrec_failed_i = -1;
            lustrec_binary_failed_i = -1;
            sim_failed_i = -1;
        end
        valid(i) = valid_i;
        lustrec_failed(i) = lustrec_failed_i;
        lustrec_binary_failed(i) = lustrec_binary_failed_i;
        sim_failed(i) = sim_failed_i;
        
        
        
        if exist(lus_full_path,'file')
            d = dir(lus_full_path);
            lus_file_nb_bytes(i) = d.bytes;
        end
        
    end
    result = table(lus_names', lus_file_nb_bytes, valid, lustrec_failed, lustrec_binary_failed, sim_failed,  ...
        'VariableNames', {'models_name','lus_file_nb_bytes','valid', 'lustrec_failed', 'lustrec_binary_failed', 'sim_failed'});
    
    % if you want to order the result by a column
    result = sortrows(result,3);
    %if you want to debug the invalid examples
    not_valid_inexes = find(valid~=1);
    if ~isempty(not_valid_inexes)
        try
            not_valid_models_dir = fullfile(regression_path, 'not_valid_models');
            mkdir(not_valid_models_dir);
            t = datetime('now','Format','dd-MM-yyyy''@''HHmmss');
            filename = fullfile(destination, ['not_valid_models_' char(t) '.csv']);
            fileID = fopen(filename,'w');
            formatSpec = '%s\n';
            for i=not_valid_inexes'
                if fileID> 0 ;fprintf(fileID,formatSpec,lus_names{i});end
                src =  fullfile(regression_path, char(lus_names{i}));
                dst = fullfile(not_valid_models_dir, char(lus_names{i}));
                copyfile(src, dst);
            end
        catch ME
            display_msg(ME.message, Constants.ERROR, 'Runner', '');
            display_msg(ME.getReport(), Constants.DEBUG, 'Runner', '');
        end
    end
    
    % plot statistics
    t = datetime('now','Format','dd-MM-yyyy''@''HHmmss');
    filename = ['regression_result_' char(t) '.csv'];
    writetable(result,filename);
    mv_cmd = sprintf('mv %s %s', filename, destination);
    system(mv_cmd);
    rmpath(regression_path);
end