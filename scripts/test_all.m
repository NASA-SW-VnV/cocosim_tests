function test_all(SimulinkTestPath, backend, commitReport, ignore_preFailedModels)
% Get start time
t_start = tic;
bdclose('all')
if nargin < 2 || isempty(backend)
    backend = coco_nasa_utils.LusBackendType.LUSTREC;
end
if nargin < 3 || isempty(commitReport)
    commitReport = false;
end
if nargin < 4
    ignore_preFailedModels = true;
end
destination = fullfile(SimulinkTestPath,'test_result');
if ~exist(destination, 'dir'); mkdir(destination); end

% delete PP files
coco_nasa_utils.MatlabUtils.reg_delete(SimulinkTestPath, '*_PP.slx*');
coco_nasa_utils.MatlabUtils.reg_delete(SimulinkTestPath, '*_PP.mdl*');

coco_nasa_utils.MatlabUtils.reg_delete(SimulinkTestPath, '*_mcdc_harness.slx*');
coco_nasa_utils.MatlabUtils.reg_delete(SimulinkTestPath, '*_mcdc_harness.mdl*');

% run unit tests without check of unsupported blocks/options
options{1} = nasa_toLustre.utils.ToLustreOptions.SKIP_COMPATIBILITY;
options{2} = nasa_toLustre.utils.ToLustreOptions.FORCE_CODE_GEN;
options{3} = nasa_toLustre.utils.ToLustreOptions.NODISPLAY;
% options{4} = nasa_toLustre.utils.ToLustreOptions.;% skip sf parser check
runner(SimulinkTestPath, destination, backend, options, commitReport, ignore_preFailedModels);

% delete PP files
coco_nasa_utils.MatlabUtils.reg_delete(SimulinkTestPath, '*_PP.slx*');
coco_nasa_utils.MatlabUtils.reg_delete(SimulinkTestPath, '*_PP.mdl*');

% delete MCDC files
coco_nasa_utils.MatlabUtils.reg_delete(SimulinkTestPath, '*_mcdc_harness.slx*');
coco_nasa_utils.MatlabUtils.reg_delete(SimulinkTestPath, '*_mcdc_harness.mdl*');

% close all
try bdclose('all'), catch, end
t_finish = toc(t_start);
msg = sprintf('Regresion tests finished in %f seconds', t_finish);
display_msg(msg, MsgType.RESULT, 'test_all', '');
end