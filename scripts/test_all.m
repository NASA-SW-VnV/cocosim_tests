%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Author: Hamza Bourbouh <hamza.bourbouh@nasa.gov>
% Notices:
%
% Copyright @ 2020 United States Government as represented by the
% Administrator of the National Aeronautics and Space Administration.  All
% Rights Reserved.
%
% Disclaimers
%
% No Warranty: THE SUBJECT SOFTWARE IS PROVIDED "AS IS" WITHOUT ANY
% WARRANTY OF ANY KIND, EITHER EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING,
% BUT NOT LIMITED TO, ANY WARRANTY THAT THE SUBJECT SOFTWARE WILL CONFORM
% TO SPECIFICATIONS, ANY IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS
% FOR A PARTICULAR PURPOSE, OR FREEDOM FROM INFRINGEMENT, ANY WARRANTY THAT
% THE SUBJECT SOFTWARE WILL BE ERROR FREE, OR ANY WARRANTY THAT
% DOCUMENTATION, IF PROVIDED, WILL CONFORM TO THE SUBJECT SOFTWARE. THIS
% AGREEMENT DOES NOT, IN ANY MANNER, CONSTITUTE AN ENDORSEMENT BY
% GOVERNMENT AGENCY OR ANY PRIOR RECIPIENT OF ANY RESULTS, RESULTING
% DESIGNS, HARDWARE, SOFTWARE PRODUCTS OR ANY OTHER APPLICATIONS RESULTING
% FROM USE OF THE SUBJECT SOFTWARE.  FURTHER, GOVERNMENT AGENCY DISCLAIMS
% ALL WARRANTIES AND LIABILITIES REGARDING THIRD-PARTY SOFTWARE, IF PRESENT
% IN THE ORIGINAL SOFTWARE, AND DISTRIBUTES IT "AS IS."
%
% Waiver and Indemnity:  RECIPIENT AGREES TO WAIVE ANY AND ALL CLAIMS
% AGAINST THE UNITED STATES GOVERNMENT, ITS CONTRACTORS AND SUBCONTRACTORS,
% AS WELL AS ANY PRIOR RECIPIENT.  IF RECIPIENT'S USE OF THE SUBJECT
% SOFTWARE RESULTS IN ANY LIABILITIES, DEMANDS, DAMAGES, EXPENSES OR
% LOSSES ARISING FROM SUCH USE, INCLUDING ANY DAMAGES FROM PRODUCTS BASED
% ON, OR RESULTING FROM, RECIPIENT'S USE OF THE SUBJECT SOFTWARE, RECIPIENT
% SHALL INDEMNIFY AND HOLD HARMLESS THE UNITED STATES GOVERNMENT, ITS
% CONTRACTORS AND SUBCONTRACTORS, AS WELL AS ANY PRIOR RECIPIENT, TO THE
% EXTENT PERMITTED BY LAW.  RECIPIENT'S SOLE REMEDY FOR ANY SUCH MATTER
% SHALL BE THE IMMEDIATE, UNILATERAL TERMINATION OF THIS AGREEMENT.
%
% Notice: The accuracy and quality of the results of running CoCoSim
% directly corresponds to the quality and accuracy of the model and the
% requirements given as inputs to CoCoSim. If the models and requirements
% are incorrectly captured or incorrectly input into CoCoSim, the results
% cannot be relied upon to generate or error check software being developed.
% Simply stated, the results of CoCoSim are only as good as
% the inputs given to CoCoSim.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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