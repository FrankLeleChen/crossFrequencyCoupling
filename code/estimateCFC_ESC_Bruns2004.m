function CFC = estimateCFC_ESC_Bruns2004(fLow, fHigh, xLow, xHigh, aLow, phiLow, aHigh, phiHigh)
% Envolop-to-Signal Correlation
%
% Weakness: can't detect if coupling is at double the frequency
% Weakness: can't detect if amplitude has symmetric deviation (for example
%           increased variance)

CFC = zeros(size(xLow, 2), 1);
for k = 1:size(xLow, 2)
    CFC(k) = corr(xLow(:,k), aHigh(:,k));
end