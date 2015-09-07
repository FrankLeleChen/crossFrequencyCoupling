%% Design filter bank
fs = 1000;
[b, a, fCenterList, nTap] = filterBank_simple(8, 100, 5, 4, fs, 'fir1', 3);

%% Make some fake signal with cross-frequency coupling
TT = 5000;
T = TT + 2 * nTap;

f1 = 12 / fs;
f2 = 67 / fs;
f3 = 100 / fs;
e1 = cos(2 * pi * f1 * (1:T) + 0.1 * cumsum(randn(1, T)));
e2 = exp(-2*e1) .* cos(2 * pi * f2 * (1:T)) / 4;
e3 = sin(2 * pi * f3 * (1:T) + 0.1 * cumsum(randn(1, T)));
x = e1 + e2 + e3;
x = x(:);
x = zscore(x) + 0.01 * randn(T, 1);

figure(924); clf;
subplot(2,1,1); hold all;
pwelch(x, [], [], [], fs);
line(fs * f1 * [1, 1], [-30, -20], 'Color', 'r');
line(fs * f2 * [1, 1], [-30, -20], 'Color', 'r');
xlim([0 200]);
subplot(2,1,2); hold all
plot(e1); plot(e2);
plot(x, 'k');
xlim([100, 500]);

%%
[x_filtered, x_analytic] = applyFilterBankThenHT_filtfilt(b, a, x, nTap);
amplitude = abs(x_analytic);
phase = angle(x_analytic);

%%
fLowRange = fCenterList(fCenterList <= 35); nLow = numel(fLowRange);
fHighRange = fCenterList(fCenterList >= 40); nHigh = numel(fHighRange);
assert(nLow > 0);
assert(nHigh > 0);

%% Get some estimators
estimators = CFCestimatorFactory('all');
nEstimator = numel(estimators);

% Parameters for the surrogate generation
nSurrogate = 999; % number of shuffled surrogates requested
minTimeShift = 0.1 * fs; % minimum time to be separated to have phase decoherence
rpIdxAll = generateSurrogateIndices(T - 2*nTap, minTimeShift, nSurrogate);

CFC = {}; clear CFC
CFC(nEstimator, nLow, nHigh) = surrogateStats(); % initialize results structure
for kLow = 1:nLow
    fLow = fLowRange(kLow);
    xLow = x_filtered(:, kLow);
    aLow = amplitude(:, kLow);
    pLow = phase(:, kLow);
    for kHigh = 1:nHigh
        fHigh = fHighRange(kHigh);
        xHigh = x_filtered(:, kHigh);
        aHigh = amplitude(:, kHigh);
        pHigh = phase(:, kHigh);

        %% Generate surrogates
        xxLow  = repmat(xLow(:), 1, nSurrogate+1);
        xxHigh = xHigh(rpIdxAll);
        xaLow  = repmat(aLow(:), 1, nSurrogate+1);
        xpLow  = repmat(pLow(:), 1, nSurrogate+1);
        xaHigh = aHigh(rpIdxAll);
        xpHigh = pHigh(rpIdxAll);

%         CFCtemp = estimateCFC_GLM_Penny2008(fLow, fHigh, ...
%                         xxLow, xxHigh, xaLow, xpLow, xaHigh, xpHigh);
        for kEstim = 1:nEstimator
            CFCtemp = estimators(kEstim).handle(fLow, fHigh, ...
                            xxLow, xxHigh, xaLow, xpLow, xaHigh, xpHigh);

            stat = surrogateStats(CFCtemp(1), CFCtemp(2:end));
            CFC(kEstim, kLow, kHigh) = stat;
        end
    end
end

ts = datestr(now,30);

%%

for kEstim = 1:nEstimator
fig = figure(5877+kEstim); clf;

subplot(1,3,1);
imagesc(fLowRange, fHighRange, reshape([CFC(kEstim,:,:).value], nLow, nHigh)'); axis xy; colorbar; colormap('jet')
title(estimators(kEstim).desc);

subplot(1,3,2);
imagesc(fLowRange, fHighRange, reshape([CFC(kEstim,:,:).deviation], nLow, nHigh)'); axis xy; colorbar; colormap('jet')
title('deviation');
xlabel('Freq (Hz)'); ylabel('Freq (Hz)');
hold on
plot(f1*fs, f2*fs, 'ro');

subplot(1,3,3);
imagesc(fLowRange, fHighRange, reshape([CFC(kEstim,:,:).pValue], nLow, nHigh)'); axis xy; colorbar; colormap('jet')
title('p-value')
xlabel('Freq (Hz)'); ylabel('Freq (Hz)');
hold on
plot(f1*fs, f2*fs, 'ro');

set(fig, 'PaperSize', [8 3], 'PaperPosition', [0 0 8 3]);
saveas(fig, sprintf('%s_%s.pdf', ts, estimators(kEstim).ID));
end