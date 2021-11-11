classdef spikeRasterPlot < matlab.graphics.chartcontainer.ChartContainer & ...
        matlab.graphics.chartcontainer.mixin.Legend
    % spikeRasterPlot Create a spike raster plot
    %   spikeRasterPlot(spikeTimes) create a spike raster plot with the
    %   specified spike timestamps. spikeTimes must be a vector of duration
    %   values.
    %
    %   spikeRasterPlot(spikeTimes, trials) create a spike raster plot with
    %   the specified trial assignment for each spike time. trials must be
    %   a vector of equal length to the spike times and of type categorical
    %   or be convertible to categorical.
    %
    %   spikeRasterPlot() create a spike raster plot using only name-value
    %   pairs.
    %
    %   spikeRasterPlot(___,Name,Value) specifies additional options for
    %   the spike raster plot using one or more name-value pair arguments.
    %   Specify the options after all other input arguments.
    %
    %   spikeRasterPlot(parent,___) creates the spike raster plot in the
    %   specified parent.
    %
    %   h = spikeRasterPlot(___) returns the spikeRasterPlot object. Use h
    %   to modify properties of the plot after creating it.
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties
        % Spike time data.
        SpikeTimeData (:,1) duration = duration.empty(0,1)
        
        % Trial assignment of each spike in the SpikeTimeData.
        TrialData (:,1) categorical = categorical.empty(0,1)
        
        % Group assignment of each spike in the SpikeTimeData.
        GroupData (:,1) categorical = categorical.empty(0,1)
        
        % Time to use as alignment time for each trial.
        AlignmentTimes (:,1) duration = duration.empty(0,1)
        
        % Title of the plot.
        TitleText (:,1) string = ""
        
        % Subtitle of the plot.
        SubtitleText (:,1) string = ""
        
        % x-label of the plot.
        XLabelText (:,1) string = ""
        
        % y-label of the plot.
        YLabelText (:,1) string = ""
        
        % Title on the legend.
        LegendTitle (:,1) string = ""
    end
    
    properties (Dependent)
        % List of colors to use for each group.
        ColorOrder {validatecolor(ColorOrder, 'multiple')} = get(groot, 'factoryAxesColorOrder')
        
        % x-limits of the plot.
        XLimits (1,2) duration {mustBeLimits} = seconds([0 1])
        
        % Mode for the x-limits.
        XLimitsMode (1,:) char {mustBeAutoManual} = 'auto'
    end
    
    properties (Access = protected)
        SaveAxesState struct = []
    end
    
    properties (Access = private, Transient, NonCopyable)
        SpikeLines (:,1) matlab.graphics.chart.primitive.Line
    end
    
    methods
        function obj = spikeRasterPlot(varargin)
            %
            
            % Initialize list of arguments
            args = varargin;
            leadingArgs = cell(0);
            
            % Check if the first input argument is a graphics object to use as parent.
            if ~isempty(args) && isa(args{1},'matlab.graphics.Graphics')
                % spikeRasterPlot(parent, ___)
                leadingArgs = args(1);
                args = args(2:end);
            end
            
            % Check for optional positional arguments.
            if ~isempty(args) && isduration(args{1})
                if mod(numel(args), 2) == 1
                    % spikeRasterPlot(times, Name, Value)
                    times = args{1};
                    
                    % Add times to the input arguments.
                    leadingArgs = [leadingArgs {'SpikeTimeData', times}];
                    args = args(2:end);
                elseif mod(numel(args), 2) == 0
                    % spikeRasterPlot(times, trial, Name, Value)
                    times = args{1};
                    trials = args{2};
                    
                    % Verify times and trials are the same length.
                    assert(numel(times) == numel(trials), ...
                        'spikeRasterPlot:DataLengthMismatch',...
                        'Trials must be the same length as times.');
                    
                    % Add times and trials to the input arguments.
                    leadingArgs = [leadingArgs {'SpikeTimeData', times, 'TrialData', trials}];
                    args = args(3:end);
                else
                    error('spikeRasterPlot:InvalidSyntax', ...
                        'Specify just spike time data or both spike time and trial data.');
                end
            end
            
            % Combine positional arguments with name/value pairs.
            args = [leadingArgs args];
            
            % Call superclass constructor method
            obj@matlab.graphics.chartcontainer.ChartContainer(args{:});
            
            % Supress output unless it is requested.
            if nargout == 0
                clear obj
            end
        end
    end
    
    methods (Access = protected)
        function setup(obj)
            % Configure the axes.
            ax = obj.getAxes();
            ax.YDir = 'reverse';
            ax.NextPlot = 'replacechildren';
            
            % Constrain pan and zoom to just the x-dimension.
            ax.Interactions = [
                panInteraction('Dimension', 'x');
                zoomInteraction('Dimension', 'x');
                rulerPanInteraction('Dimension', 'x');
                dataTipInteraction];
            
            % Create a line to show the spike times and configure the
            % x-axis for duration data.
            obj.SpikeLines = plot(ax, seconds(NaN), categorical(NaN), ...
                'SeriesIndex', 1);
            
            % Restore any saved axes state.
            loadAxesState(obj)
        end
        
        function update(obj)
            % Verify that the data properties are consistent with one
            % another.
            showChart = verifyDataProperties(obj);
            set(obj.SpikeLines,'Visible', showChart);
            
            % Abort early if not visible due to invalid data.
            if ~showChart
                return
            end
            
            % Align the data based on the AlignmentTimes.
            times = obj.alignSpikeTimes(obj.SpikeTimeData, obj.TrialData, obj.AlignmentTimes);
            
            % Determine how many lines are needed (one per group).
            groups = obj.GroupData;
            groupNames = categories(groups);
            nGroups = numel(groupNames);
            if isempty(groups) || any(ismissing(groups))
                nGroups = nGroups + 1;
                groupNames{end+1,1} = '<undefined>';
            end
            
            % Get the axes
            ax = getAxes(obj);
            
            % Create extra lines as needed
            p = obj.SpikeLines;
            nLinesHave = numel(p);
            for n = nLinesHave+1:nGroups
                p(n) = matlab.graphics.chart.primitive.Line('Parent', ax, ...
                    'SeriesIndex', n);
            end
            
            % Update the categories and limits on the y-axis.
            cats = categories(obj.TrialData);
            if isempty(cats)
                cats = {'1'};
                ax.YAxis.TickValues = [];
            else
                ax.YAxis.TickValuesMode = 'auto';
            end
            ax.YAxis.Categories = cats;
            ax.YAxis.Limits = categorical(cats([1 end]));
            
            % Determine which group each timestamp belongs to.
            groupNumber = double(groups);
            if isempty(groupNumber)
                groupNumber = ones(size(times));
            end
            groupNumber(isnan(groupNumber)) = nGroups;
            
            % Update the lines with the data.
            for n = 1:nGroups
                % Identify the timestamps in this group.
                thisGroup = groupNumber == n;
                
                % Reformat the data into XData and YData for a line.
                [x,y] = obj.createLineData(times, obj.TrialData, thisGroup);
                
                % Update the line with the data.
                p(n).XData = x;
                p(n).YData = y;
                p(n).DisplayName = groupNames{n};
            end
            
            % Hide the legend if there is only one undefined group.
            if nGroups == 1 && groupNames{1} == "<undefined>"
                obj.LegendVisible = false;
            end
            
            % Delete unneeded lines
            delete(p((nGroups+1):numel(p)))
            obj.SpikeLines = p(1:nGroups);
            
            % Update the title/subtitle/labels on the axes and legend.
            title(getAxes(obj), obj.TitleText, obj.SubtitleText);
            xlabel(getAxes(obj), obj.XLabelText);
            ylabel(getAxes(obj), obj.YLabelText);
            if obj.LegendVisible
                title(getLegend(obj), obj.LegendTitle);
            end
        end
        
        function showChart = verifyDataProperties(obj)
            % SpikeTimeData and TrialData must be the same length.
            n = numel(obj.SpikeTimeData);
            showChart = isempty(obj.TrialData) || numel(obj.TrialData) == n;
            if ~showChart
                warning('spikeRasterPlot:DataLengthMismatch',...
                    'TrialData must be empty or the same length as SpikeTimeData.');
                return
            end
            
            % SpikeTimeData and GroupData must be the same length.
            showChart = isempty(obj.GroupData) || numel(obj.GroupData) == n;
            if ~showChart
                warning('spikeRasterPlot:DataLengthMismatch',...
                    'GroupData must be empty or the same length as SpikeTimeData.');
                return
            end
            
            % AlignmentTimes should be empty, a scalar, or have at least
            % one entry per category in TrialData.
            a = numel(obj.AlignmentTimes);
            c = categories(obj.TrialData);
            if a > 1 && a < numel(c)
                warning('spikeRasterPlot:AlignmentTimesMismatch',...
                    'Ignoring AlignmentTimes. AlignmentTimes must be empty, scalar, or have at least one entry per category in TrialData.');
            end
        end
        
        function loadAxesState(obj)
            state = obj.SaveAxesState;
            
            if isfield(state, 'ColorOrder')
                obj.ColorOrder = state.ColorOrder;
            end
            
            if isfield(state, 'XLimits')
                obj.XLimits = state.XLimits;
            end
            
            if isfield(state, 'LegendVisible')
                obj.LegendVisible = state.LegendVisible;
            end
            
            % Reset the SaveAxesState for the next save.
            obj.SaveAxesState = [];
        end
        
        function groups = getPropertyGroups(obj)
            if ~isscalar(obj)
                % List for array of objects
                groups = getPropertyGroups@matlab.mixin.CustomDisplay(obj);
            else
                % List for scalar object
                propList = cell(1,0);
                
                % Add the title, if not empty or missing.
                nonEmptyTitle = obj.TitleText ~= "" & ~ismissing(obj.TitleText);
                if any(nonEmptyTitle)
                    propList = {'TitleText'};
                end
                
                % Add the subtitle, if not empty or missing.
                nonEmptySubtitle = obj.SubtitleText ~= "" & ~ismissing(obj.SubtitleText);
                if any(nonEmptySubtitle)
                    propList{end+1} = 'SubtitleText';
                end
                
                % Add SpikeTimeData
                propList{end+1} = 'SpikeTimeData';
                
                % Add TrialData if not empty.
                if ~isempty(obj.TrialData)
                    propList{end+1} = 'TrialData';
                end
                
                % Add GroupData and LegendTitle if GroupData is not empty.
                if ~isempty(obj.GroupData)
                    propList{end+1} = 'GroupData';
                    
                    % Add the LegendTitle, if not empty or missing.
                    nonEmptyTitle = obj.LegendTitle ~= "" & ~ismissing(obj.LegendTitle);
                    if any(nonEmptyTitle)
                        propList{end+1} = 'LegendTitle';
                    end
                end
                
                groups = matlab.mixin.util.PropertyGroup(propList);
            end
        end
    end
    
    methods (Static, Access = protected)
        function [x,y] = createLineData(times, y, thisGroup)
            % Create three rows for x:
            %   First and second row replicate the input times.
            %   Third row is NaN to put breaks in the line.
            times = times(thisGroup);
            x = [times times NaN(size(times))]';
            
            % Create three rows for y:
            %   First row is the bottom of each tick mark.
            %   Second row is the top of each tick mark.
            %   Third row is NaN to put breaks in the line.
            if isempty(y)
                y = ones(size(times));
            else
                y = double(y);
                y = y(thisGroup);
            end
            y = (y+[-0.5 0.5 NaN])';
            
            % Convert both x and y into column vectors.
            x = x(:);
            y = y(:);
        end
        
        function times = alignSpikeTimes(times, c, ref)
            if isscalar(ref)
                % One alignment time, subtract the same time from all
                % timestamps.
                times = times - ref;
            elseif ~isempty(ref)
                % Get the group numbers from each timestamp.
                if isempty(c)
                    y = ones(size(times));
                else
                    y = double(c);
                end
                
                if numel(categories(c)) <= numel(ref)
                    % One alignment time per trial, shift each timestamp
                    % based on the trial number.
                    valid = ~isnan(y);
                    times(valid) = times(valid) - ref(y(valid));
                end
            end
        end
    end
    
    methods
        function title(obj, varargin)
            [t, st] = title(getAxes(obj), varargin{:});
            obj.TitleText = t.String;
            obj.SubtitleText = st.String;
        end
        
        function subtitle(obj, varargin)
            ax = getAxes(obj);
            st = subtitle(ax, varargin{:});
            obj.SubtitleText = st.String;
        end
        
        function xlabel(obj, varargin)
            ax = getAxes(obj);
            x = xlabel(ax, varargin{:});
            obj.XLabelText = x.String;
        end
        
        function ylabel(obj, varargin)
            ax = getAxes(obj);
            y = ylabel(ax, varargin{:});
            obj.YLabelText = y.String;
        end
        
        function varargout = xlim(obj, varargin)
            ax = getAxes(obj);
            [varargout{1:nargout}] = xlim(ax, varargin{:});
        end
    end
    
    methods
        function set.GroupData(obj, groups)
            obj.GroupData = groups;
            
            % When the GroupData changes, reset the legend back to on.
            obj.LegendVisible = true;
        end
        
        function set.ColorOrder(obj, map)
            ax = getAxes(obj);
            ax.ColorOrder = validatecolor(map, 'multiple');
        end
        
        function map = get.ColorOrder(obj)
            ax = getAxes(obj);
            map = ax.ColorOrder;
        end
        
        function set.XLimits(obj, limits)
            ax = getAxes(obj);
            ax.XLim = limits;
        end
        
        function limits = get.XLimits(obj)
            ax = getAxes(obj);
            limits = ax.XLim;
        end
        
        function set.XLimitsMode(obj, mode)
            ax = getAxes(obj);
            ax.XLimMode = mode;
        end
        
        function mode = get.XLimitsMode(obj)
            ax = getAxes(obj);
            mode = ax.XLimMode;
        end
        
        function state = get.SaveAxesState(obj)
            state = obj.SaveAxesState;
            
            if isempty(state)
                % Create a 1x1 struct.
                state = struct();
                
                % Add fields to the struct for each axes property to store.
                ax = getAxes(obj);
                if ax.ColorOrderMode == "manual"
                    state.ColorOrder = obj.ColorOrder;
                end
                
                if obj.XLimitsMode == "manual"
                    state.XLimits = obj.XLimits;
                end
                
                state.LegendVisible = obj.LegendVisible;
            end
        end
    end
end

function mustBeLimits(limits)

if numel(limits) ~= 2 || limits(2) <= limits(1)
    throwAsCaller(MException('spikeRasterPlot:InvalidLimits', 'Specify limits as two increasing values.'))
end

end

function mustBeAutoManual(mode)

mustBeMember(mode, {'auto','manual'})

end
