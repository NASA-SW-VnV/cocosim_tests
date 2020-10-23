function test_one(slx_full_path, nb_runs)
    if nargin < 2
        nb_runs = 1;
    end
    
    options = {'nodisplay'};
    bdclose('all')
    
    tools_config;
    
    display_msg('Starting', Constants.INFO, 'test_one', '');
    load_system(slx_full_path);
    [~, base_name, ~] = fileparts(slx_full_path);
    if bdIsLibrary(base_name)
        display_msg('The model is a library', Constants.INFO, 'test_one', '');
        return;
    end
    for i=1:nb_runs
        rng('shuffle')
        display_msg(sprintf('running iteration number %d out of %d', i, nb_runs), ...
            MsgType.RESULT, 'Runner', '');
        valid_i = ToLustre_runner(slx_full_path, options);
        if valid_i == 1
        else
            display_msg('The model has failed', Constants.INFO, 'test_one', '');
            return;
        end
    end
    display_msg('The model has succeeded', Constants.INFO, 'test_one', '');
    bdclose('all')
    
end
function [valid_i, slx2lus_failed_i, lustrec_failed_i, lustrec_binary_failed_i, ...
        sim_failed_i, is_unsupported_i] = ToLustre_runner(slx_full_path, options)
    try
        res = validate_ToLustre( slx_full_path, 1, [], 0, 0, [],options);
        valid_i = res.pp_VS_lustre_valid;
        slx2lus_failed_i = res.ToLustre_failed;
        is_unsupported_i = res.is_unsupported;
        lustrec_failed_i = res.lustrec_failed;
        lustrec_binary_failed_i = res.lustrec_binary_failed;
        sim_failed_i = res.pp_VS_lustre_simulation_failed;
    catch ME
        display_msg(ME.message, Constants.ERROR, 'Runner', '');
        display_msg(ME.getReport(), Constants.ERROR, 'Runner', '');
        valid_i = -1;
        lustrec_failed_i = -1;
        lustrec_binary_failed_i = -1;
        sim_failed_i = -1;
        is_unsupported_i = -1;
    end
end