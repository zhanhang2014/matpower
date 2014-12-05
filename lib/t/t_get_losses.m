function t_get_losses(quiet)
%T_GET_LOSSES  Tests for code in GET_LOSSES.

%   MATPOWER
%   $Id$
%   by Ray Zimmerman, PSERC Cornell
%   Copyright (c) 2014 by Power System Engineering Research Center (PSERC)
%
%   This file is part of MATPOWER.
%   See http://www.pserc.cornell.edu/matpower/ for more info.
%
%   MATPOWER is free software: you can redistribute it and/or modify
%   it under the terms of the GNU General Public License as published
%   by the Free Software Foundation, either version 3 of the License,
%   or (at your option) any later version.
%
%   MATPOWER is distributed in the hope that it will be useful,
%   but WITHOUT ANY WARRANTY; without even the implied warranty of
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
%   GNU General Public License for more details.
%
%   You should have received a copy of the GNU General Public License
%   along with MATPOWER. If not, see <http://www.gnu.org/licenses/>.
%
%   Additional permission under GNU GPL version 3 section 7
%
%   If you modify MATPOWER, or any covered work, to interface with
%   other modules (such as MATLAB code and MEX-files) available in a
%   MATLAB(R) or comparable environment containing parts covered
%   under other licensing terms, the licensors of MATPOWER grant
%   you additional permission to convey the resulting work.

if nargin < 1
    quiet = 0;
end

n_tests = 20;

t_begin(n_tests, quiet);

%% define named indices into data matrices
[PQ, PV, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM, ...
    VA, BASE_KV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN] = idx_bus;
[F_BUS, T_BUS, BR_R, BR_X, BR_B, RATE_A, RATE_B, RATE_C, ...
    TAP, SHIFT, BR_STATUS, PF, QF, PT, QT, MU_SF, MU_ST, ...
    ANGMIN, ANGMAX, MU_ANGMIN, MU_ANGMAX] = idx_brch;

casefile = 't_case9_opf';
if quiet
    verbose = 0;
else
    verbose = 0;
end
if have_fcn('octave')
    s1 = warning('query', 'Octave:load-file-in-path');
    warning('off', 'Octave:load-file-in-path');
end

mpopt = mpoption('opf.violation', 1e-6, 'mips.gradtol', 1e-8, ...
        'mips.comptol', 1e-8, 'mips.costtol', 1e-9);
mpopt = mpoption(mpopt, 'out.all', 0, 'verbose', verbose, 'opf.ac.solver', 'MIPS');
mpc = loadcase(casefile);
mpc.branch(8, TAP) = 0.95;
mpc.branch(4, SHIFT) = -2;
r = runopf(mpc, mpopt);
p_loss = [0; 0.250456; 0.944337; 0; 0.151545; 0.298009; 0; 1.600081; 0.216618];
q_loss = [3.890347; 1.355409; 4.116342; 5.017914; 1.283672; 2.524309; 10.20216; 8.050407; 1.841254];
the_fchg = [0; 9.476543; 20.751015; 0; 12.113509; 8.563392; 0; 20.056039; 10.431575];
the_tchg = [0; 9.158269; 20.749455; 0; 12.011738; 8.813679; 0; 18.136716; 10.556150];

%%-----  all load  -----
t = 'loss = get_losses(results) : ';
loss = get_losses(r);
t_is(real(loss), p_loss, 6, [t 'P loss']);
t_is(imag(loss), q_loss, 6, [t 'Q loss']);

t = 'loss = get_losses(baseMVA, bus, branch) : ';
loss = get_losses(r.baseMVA, r.bus, r.branch);
t_is(real(loss), p_loss, 6, [t 'P loss']);
t_is(imag(loss), q_loss, 6, [t 'Q loss']);

t = '[loss, chg, chg] = get_losses(results) : ';
[loss, chg] = get_losses(r);
t_is(real(loss), p_loss, 6, [t 'P loss']);
t_is(imag(loss), q_loss, 6, [t 'Q loss']);
t_is(chg, the_fchg+the_tchg, 6, [t 'Q inj (total)']);

t = '[loss, fchg, tchg] = get_losses(results) : ';
[loss, fchg, tchg] = get_losses(r);
t_is(real(loss), p_loss, 6, [t 'P loss']);
t_is(imag(loss), q_loss, 6, [t 'Q loss']);
t_is(fchg, the_fchg, 6, [t 'Q inj (from)']);
t_is(tchg, the_tchg, 6, [t 'Q inj (to)']);
t_is(real(loss), r.branch(:, PF)+r.branch(:, PT), 12, [t 'P_loss = Pf+Pt']);
t_is(imag(loss), r.branch(:, QF)+r.branch(:, QT)+tchg+fchg, 12, [t 'Q_loss = Qf+Qt+fchg+tchg']);


t = '[loss, fchg, tchg, dloss_dV, dchg_dVm] = get_losses(r) : ';
[loss, fchg, tchg, dloss_dV, dchg_dVm] = get_losses(r);
epsilon = 1e-8;
%% build numerical versions of dloss_dVa and dloss_dVm
nb = size(r.bus, 1);    %% number of buses
nl = size(r.branch, 1); %% number of branches
dloss_dVa = sparse(nl, nb);
dloss_dVm = sparse(nl, nb);
dfchg_dVm = sparse(nl, nb);
dtchg_dVm = sparse(nl, nb);
for j = 1:nb
    mpc = r;
    mpc.bus(j, VA) = mpc.bus(j, VA) + 180 / pi * epsilon;
    loss2 = get_losses(mpc);
    dloss_dVa(:, j) = (loss2 - loss) / epsilon;
end
for j = 1:nb
    mpc = r;
    mpc.bus(j, VM) = mpc.bus(j, VM) + epsilon;
    [loss2, fchg2, tchg2] = get_losses(mpc);
    dloss_dVm(:, j) = (loss2 - loss) / epsilon;
    dfchg_dVm(:, j) = (fchg2 - fchg) / epsilon;
    dtchg_dVm(:, j) = (tchg2 - tchg) / epsilon;
end
t_is(full(real(dloss_dV.a)), full(real(dloss_dVa)), 5, [t 'dPloss/dVa']);
t_is(full(imag(dloss_dV.a)), full(imag(dloss_dVa)), 4, [t 'dQloss/dVa']);
t_is(full(real(dloss_dV.m)), full(real(dloss_dVm)), 5, [t 'dPloss/dVm']);
t_is(full(imag(dloss_dV.m)), full(imag(dloss_dVm)), 4, [t 'dQloss/dVm']);
t_is(full(dchg_dVm.f), full(dfchg_dVm), 5, [t 'dfchg/dVm']);
t_is(full(dchg_dVm.t), full(dtchg_dVm), 5, [t 'dtchg/dVm']);

t = 'Loss Sensitivity Factors (LSF)';
%% convert to internal indexing to use makeJac()
ri = ext2int(r);            %% results with internal indexing
[loss, fchg, tchg, dloss_dV] = get_losses(ri);
nb = size(ri.bus, 1);
nl = size(ri.branch, 1);
[ref, pv, pq] = bustypes(ri.bus, ri.gen);
J = makeJac(ri);
dL = real([dloss_dV.a(:, [pv;pq]) dloss_dV.m(:, pq)]) / ri.baseMVA;
LSFi = zeros(nl, 2*nb);
LSFi(:, [pv; pq; nb+pq]) = dL / J;  %% loss sensitivity factors in internal indexing

%% convert to external indexing
nb = size(r.bus, 1);
nl = size(r.branch, 1);
LSF = zeros(nl, 2*nb);
LSF(ri.order.branch.status.on, [ri.order.bus.status.on; nb+ri.order.bus.status.on]) = LSFi;

numLSF = zeros(nl, 2*nb);
epsilon = 1e-4;
mpopt = mpoption('out.all', 0, 'verbose', 0, 'pf.tol', 1e-12);
for j = 1:nb
    mpc = r;
    mpc.bus(j, PD) = mpc.bus(j, PD) - epsilon;
    rr = runpf(mpc, mpopt);
    loss2 = get_losses(rr);
    numLSF(:, j) = real(loss2 - loss) / epsilon;
    
    mpc = r;
    mpc.bus(j, QD) = mpc.bus(j, QD) - epsilon;
    rr = runpf(mpc, mpopt);
    loss2 = get_losses(rr);
    numLSF(:, nb+j) = real(loss2 - loss) / epsilon;
end
t_is(LSF, numLSF, 1e-6, t);

% norm(numLSF - LSF, Inf)
% norm(numLSF(:, 1:nb) - LSF(:, 1:nb), Inf)

% LSF
% numLSF

% sum(LSF)
% sum(numLSF)

% norm(sum(numLSF) - sum(LSF), Inf)

t_end;
