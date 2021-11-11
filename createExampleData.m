function [spiketimes, trials, groups, trialStarts] = createExampleData
% createExampleData Generate random spike times for testing spikeRasterPlot
% [times, trials, groups, starts] = createExampleData() Generate a random
% spike times for two neurons across 20 trials.

% Copyright 2020-2021 The MathWorks, Inc.

% Create 20 trials, one minute apart.
trialStarts = minutes(1:20);

% Create one neuron that fires 2 seconds into the trial.
times1 = [(randn(100,20)*2.5)+2; rand(20,20)*60];
trials = zeros(size(times1)) + (1:20);
keep = (times1>=0 & times1<60)';
times1 = seconds(times1) + trialStarts;
times1 = times1(keep);
t1 = trials(keep);
g1 = ones(size(times1));

% Create another neuron that fires 20 seconds into the trial.
times2 = [(randn(100,20)*5)+20; rand(10,20)*60];
trials = zeros(size(times2)) + (1:20);
keep = (times2>=0 & times2<60)';
times2 = seconds(times2) + trialStarts;
times2 = times2(keep);
t2 = trials(keep);
g2 = 2*ones(size(times2));

% Merge two together.
[spiketimes, o] = sort([times1;times2]);
trials = [t1; t2];
trials = trials(o);
groups = [g1; g2];
groups = groups(o);
