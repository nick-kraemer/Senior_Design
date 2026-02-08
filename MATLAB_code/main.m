close all
clear all

%Replace log files with the new logs I generated below are the original

%fname_gps='logs/vehicleOut (1).txt';
%fname_power="logs/dump.txt";
fname_gps='logs/GPS6.txt';
fname_power="logs/Power6.txt";

%Location of the transmitter only for testing
origin_y = 35.72744374828529;
origin_x = -78.69606234773077;

[timestamp_gps, timestamp_gps_for_csv, GPSx, GPSy, GPSz] = process_csv_GPS(fname_gps);

% --- UPDATED: process_txt_CS now only takes power file and returns 3 outputs ---
[timestamp_power, mpower, timestamp_power_for_csv] = process_txt_CS(fname_power);

% --- Clean up GPS timestamps: sort + drop exact duplicates ---
[timestamp_gps, idxSort] = sort(timestamp_gps);      % ensure increasing order
GPSx = GPSx(idxSort);
GPSy = GPSy(idxSort);
GPSz = GPSz(idxSort);

[timestamp_gps_u, idxU] = unique(timestamp_gps, 'stable');  % remove duplicates
GPSx = GPSx(idxU);
GPSy = GPSy(idxU);
GPSz = GPSz(idxU);

timestamp_gps = timestamp_gps_u;   % use the cleaned version from here on

%Find location of the measurements
mX = zeros(length(timestamp_power),1);
mY = zeros(length(timestamp_power),1);
mZ = zeros(length(timestamp_power),1);

for i=1:length(timestamp_power)
    if timestamp_power(i)<timestamp_gps(1)
        mX(i,1)=GPSx(1);
        mY(i,1)=GPSy(1);
        mZ(i,1)=GPSz(1);
    elseif timestamp_power(i)>timestamp_gps(end)
        mX(i,1)=GPSx(end);
        mY(i,1)=GPSy(end);
        mZ(i,1)=GPSz(end);
    else
        mX(i,1)=interp1(timestamp_gps,GPSx,timestamp_power(i));
        mY(i,1)=interp1(timestamp_gps,GPSy,timestamp_power(i));
        mZ(i,1)=interp1(timestamp_gps,GPSz,timestamp_power(i));
    end
end

%Remove measurements before GPS started and after GPS ended
% (Fixes the original boolean arithmetic bug)
validindex = find(timestamp_power > timestamp_gps(1) & timestamp_power < timestamp_gps(end));

mX=mX(validindex);
mY=mY(validindex);
mZ=mZ(validindex);
timestamp_power=timestamp_power(validindex);
timestamp_power_for_csv=timestamp_power_for_csv(validindex,:);
mpower=mpower(validindex);

figure(5)
clf
hold on
grid on
scatter3(mX,mY,mZ,10,mpower)
scatter3(origin_x,origin_y,0,10,-60)
scatter3(origin_x,origin_y,0,100,-60)
scatter3(origin_x,origin_y,30,10,-60)
scatter3(origin_x,origin_y,30,100,-60)
x0=min(mX);x1=max(mX);y0=min(mY);y1=y0+(x1-x0);
xlim([x0 x1+0.00015   ]);
ylim([y0 y1]-(y1-y0)/2);
colormap(jet);
colorbar;
caxislim=[-40 35];
caxis(caxislim)

xlabel('Longitude')
ylabel('Latitude')
zlabel('Altitude')
zlim([0 35]);
hcb=colorbar;
colorTitleHandle = get(hcb,'Title');
titleString = 'Power (dB)';
set(colorTitleHandle ,'String',titleString);

%% --- Transit detector (geometry-based): flags straight connector legs ---
deg_per_m_lat = 1/110540;
deg_per_m_lon = 1/(111320*cosd(mean(mY)));

% Convert lon/lat to local meters (relative coords)
Xm_all = (mX - mean(mX)) / deg_per_m_lon;
Ym_all = (mY - mean(mY)) / deg_per_m_lat;

% Heading between consecutive samples
dx = [0; diff(Xm_all)];
dy = [0; diff(Ym_all)];
hdg = atan2(dy, dx);  % radians

% Wrapped heading change per step
dhdg = [0; atan2(sin(diff(hdg)), cos(diff(hdg)))];

% Straightness and turning over a sliding window
W = 25;  % window length in samples (try 15–40 depending on sample rate)
straightness = zeros(size(Xm_all));
turnmag = zeros(size(Xm_all));

for i = 1:numel(Xm_all)
    i0 = max(1, i-W+1);
    xs = Xm_all(i0:i); ys = Ym_all(i0:i);

    pathLen = sum(hypot(diff(xs), diff(ys)));
    netLen  = hypot(xs(end)-xs(1), ys(end)-ys(1));
    straightness(i) = netLen / max(pathLen, eps);

    turnmag(i) = mean(abs(dhdg(i0:i)));   % average turning magnitude
end

% Connector heuristic: very straight AND low turning
% Make thresholds adaptive to the dataset
thrStraight = prctile(straightness, 85);      % top 15% straightest windows
thrTurn     = prctile(turnmag, 25);           % bottom 25% turning windows

isTransit = (straightness >= thrStraight) & (turnmag <= thrTurn);

fprintf('Transit thresholds: straight>=%.3f, turn<=%.3f\n', thrStraight, thrTurn);
fprintf('Connector-flagged samples: %d / %d\n', nnz(isTransit), numel(isTransit));

%% --- LOBs via local RSSI gradient (NO wedges; LOB lines only) ---

% Visual params
R_m          = 1000;     % line length (m), just for drawing

% Gradient-fit params (local window & weighting)
neigh_m = 80;           % neighborhood radius (m) for plane fit
sigma_m = 40;           % Gaussian weight width (m)

% ---------- Option A: ensure one seed per square ----------
K = 3;  % number of intended boxes/squares
XY = [mX mY];

% Fit kmeans using ONLY non-connector samples so connector legs don't become a cluster
[~, C] = kmeans(XY(~isTransit,:), K, 'MaxIter', 200, 'Replicates', 5);

% Assign every sample (including connector ones) to the nearest centroid for bookkeeping
grp = knnsearch(C, XY);

% From each spatial group, take the top-k RSSI points
kPer = 12;  % up to 12 strongest per square
idx_top = [];
for g = 1:3
    I = find(grp == g & ~isTransit);
    if isempty(I), continue; end
    [~, ord] = sort(mpower(I), 'descend');
    take = I(ord(1:min(kPer, numel(I))));
    idx_top = [idx_top; take(:)];
end

% Re-center seeds using only strong points (cleaner cluster centroids)
[~, C] = kmeans([mX(idx_top) mY(idx_top)], 3, 'MaxIter', 200, 'Replicates', 5);
Nlob = size(C,1);

% ---------- Plan view ----------
figure(6); clf; hold on; grid on; axis equal
scatter(mX, mY, 10, mpower, 'filled'); colormap(jet); colorbar; caxis(caxislim);
title('High-RSSI Gradient LOBs (Lines Only)');
xlabel('Longitude'); ylabel('Latitude');

% Degrees per meter (for drawing)
R_lon = R_m * deg_per_m_lon;
R_lat = R_m * deg_per_m_lat;

% Keep LOB starts & bearings for a least-squares intersection
LOB_start = zeros(Nlob,2);    % [lon lat]
LOB_theta = zeros(Nlob,1);    % radians

for c = 1:Nlob
    cx = C(c,1); cy = C(c,2);    % seed at square c

    % --- Neighborhood (rectangular window in degrees from meters) ---
    rx = neigh_m * deg_per_m_lon;
    ry = neigh_m * deg_per_m_lat;
    inNbh = abs(mX - cx) <= rx & abs(mY - cy) <= ry;

    % Exclude transit samples to de-bias the gradient
    inNbh = inNbh & ~isTransit;

    % Fallback: nearest by distance (still avoid transits)
    if nnz(inNbh) < 12
        d_m = hypot( (mX - cx)/deg_per_m_lon, (mY - cy)/deg_per_m_lat );
        [~, ord] = sort(d_m);
        ord = ord(~isTransit(ord));                 % drop transits
        take = ord(1:min(40, numel(ord)));         % limit count
    else
        take = find(inNbh);
    end

    % --- Density trim: drop sparse outliers inside the window ---
    if numel(take) > 18
        Xm = (mX(take) - cx) / deg_per_m_lon;
        Ym = (mY(take) - cy) / deg_per_m_lat;
        D  = squareform(pdist([Xm Ym]));
        D_sorted = sort(D + diag(inf(size(D,1),1)), 2);
        k = min(5, size(D_sorted,2));
        d_k = D_sorted(:,k);
        keep = d_k <= prctile(d_k, 70);            % keep denser 70%
        take = take(keep);
        Xm = Xm(keep); Ym = Ym(keep);
    else
        Xm = (mX(take) - cx) / deg_per_m_lon;
        Ym = (mY(take) - cy) / deg_per_m_lat;
    end

    p  = mpower(take);
    r  = hypot(Xm, Ym);
    w  = exp(-(r.^2)/(2*sigma_m^2));
    w  = w / max(eps, sum(w));
% === ADD THIS: downweight any transit samples that slipped in ===
w(isTransit(take)) = 0.1 * w(isTransit(take));   % 10× less influence
w = w / max(eps, sum(w));
% ===============================================================
    % --- Weighted plane fit: p ≈ a*X + b*Y + c ---
    Xls  = [Xm, Ym, ones(size(Xm))];
    Xw   = Xls .* w;                        % (kept as in your original style)
    pw   = p   .* w;
    beta = Xw \ pw;                         % [a; b; c]
    gx = beta(1); gy = beta(2);            % gradient (dP/dx, dP/dy)

    % Bearing toward increasing RSSI
    theta = atan2(gy, gx);

    % ---- Draw LOB line only (no wedge) ----
    x_end = cx + R_lon*cos(theta);
    y_end = cy + R_lat*sin(theta);
    plot([cx x_end], [cy y_end], 'k-', 'LineWidth', 2);

    % Save for LS intersection
    LOB_start(c,:) = [cx, cy];
    LOB_theta(c)   = theta;
end

legend({'Power samples','LOB line'}, 'Location','best');

% ---------- Bearing-only least-squares intersection (red/yellow pin) ----------
lon0 = mean(LOB_start(:,1));  lat0 = mean(LOB_start(:,2));
X0   = [(LOB_start(:,1)-lon0)/deg_per_m_lon, (LOB_start(:,2)-lat0)/deg_per_m_lat];
v    = [cos(LOB_theta), sin(LOB_theta)];

M = zeros(2); b = [0;0];
for i = 1:size(X0,1)
    P = eye(2) - (v(i,:).'*v(i,:));   % projector onto line normal
    M = M + P;  b = b + P * X0(i,:).';
end
x_hat = M \ b;                         % meters relative to (lon0,lat0)
lon_hat = lon0 + x_hat(1)*deg_per_m_lon;
lat_hat = lat0 + x_hat(2)*deg_per_m_lat;

%% Adaptive radius + P(ELT inside chosen area)  (NO wedges; ALWAYS circle)

% Residual-based covariance from LOB geometry
e2 = zeros(size(X0,1),1);
for i = 1:size(X0,1)
    P = eye(2) - (v(i,:).'*v(i,:));
    r = P * (x_hat - X0(i,:).');
    e2(i) = r.'*r;
end
sigma2 = max(1e-6, median(e2));
Sigma  = sigma2 * inv(M + 1e-9*eye(2));

% Always use a circular search radius around LS estimate
d_m = hypot( (LOB_start(:,1)-lon_hat)/deg_per_m_lon, ...
             (LOB_start(:,2)-lat_hat)/deg_per_m_lat );

Rprob_m = 0.9*median(d_m) + 1.8*sqrt(sigma2);
Rprob_m = max(20, min(150, Rprob_m));

ang = linspace(0, 2*pi, 240).';
xs = lon_hat + (Rprob_m * deg_per_m_lon) * cos(ang);
ys = lat_hat + (Rprob_m * deg_per_m_lat) * sin(ang);
finalPoly = polyshape(xs, ys);

fprintf('Search radius (always) = %.1f m\n', Rprob_m);

% Probability ELT is inside finalPoly (Monte Carlo)
Nmc = 20000;
L = chol(Sigma + 1e-9*eye(2), 'lower');
Xmc = x_hat + L * randn(2, Nmc);

lon_mc = lon0 + Xmc(1,:).' * deg_per_m_lon;
lat_mc = lat0 + Xmc(2,:).' * deg_per_m_lat;

P_in = mean(isinterior(finalPoly, lon_mc, lat_mc));
fprintf('P(ELT inside chosen search area) ≈ %.3f\n', P_in);

% Mark LS intersection on figure 6
plot(lon_hat, lat_hat, 'rp', 'MarkerFaceColor', 'y', 'MarkerSize', 12);

%% Figure 7: Chosen search circle (no wedges)
figure(7); clf; hold on; grid on; axis equal
xlabel('Longitude'); ylabel('Latitude'); title('Search Area (Circle)')

scatter(mX, mY, 6, [0.7 0.7 0.7], 'filled');
plot(finalPoly, 'FaceColor',[0.85 0.4 0], 'FaceAlpha',0.22, 'EdgeColor','none');
plot(lon_hat, lat_hat, 'rp', 'MarkerFaceColor','y', 'MarkerSize',12);
axis tight; box on;

%% --- Create input.csv for KML generation ---
csvfilename='input.csv';
if isfile(csvfilename)
    delete(csvfilename)
end

for i=1:length(timestamp_power)
    a=[num2str(i) ',' timestamp_power_for_csv(i,:) ',' ...
       num2str(mX(i),"%5.7f") ',' num2str(mY(i),"%5.7f") ',' ...
       num2str(mZ(i),"%5.7f") ',' num2str(mpower(i))];
    dlmwrite(csvfilename, a, 'delimiter', '', '-append');
end

%% --- Write chosen search area as its own KML  ---
outKml = 'feasible_region.kml';

% Build coordinates from the final chosen region (finalPoly)
V = finalPoly.Vertices;                 % Nx2 [lon lat]
if any(V(1,:) ~= V(end,:)), V = [V; V(1,:)]; end   % ensure closed
coords = V;

% Write a simple, styled polygon KML
fid = fopen(outKml, 'w');
fprintf(fid, ['<?xml version="1.0" encoding="UTF-8"?>\n' ...
    '<kml xmlns="http://www.opengis.net/kml/2.2">\n' ...
    '  <Document>\n' ...
    '    <name>ELT Search Area</name>\n' ...
    '    <Style id="elt_region_style">\n' ...
    '      <LineStyle><color>ff5a00ff</color><width>2</width></LineStyle>\n' ...
    '      <PolyStyle><color>40009818</color><fill>1</fill><outline>1</outline></PolyStyle>\n' ...
    '    </Style>\n' ...
    '    <Placemark>\n' ...
    '      <name>Search Area</name>\n' ...
    '      <styleUrl>#elt_region_style</styleUrl>\n' ...
    '      <Polygon><tessellate>1</tessellate><outerBoundaryIs><LinearRing>\n' ...
    '        <coordinates>\n']);

for i = 1:size(coords,1)
    fprintf(fid, '          %.8f,%.8f,0\n', coords(i,1), coords(i,2)); % lon,lat,alt
end

fprintf(fid, ['        </coordinates>\n' ...
    '      </LinearRing></outerBoundaryIs></Polygon>\n' ...
    '    </Placemark>\n' ...
    '  </Document>\n' ...
    '</kml>\n']);
fclose(fid);

disp(['Wrote search area polygon KML: ', outKml]);

% Add text label for estimated ELT position
fprintf('Estimated ELT location (from LOB intersection):\n');
fprintf('  Latitude:  %.7f\n', lat_hat);
fprintf('  Longitude: %.7f\n', lon_hat);
