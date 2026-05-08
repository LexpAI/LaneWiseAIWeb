#include "lanewisecontroller.hpp"

#include <QFile>
#include <QStringList>
#include <QTextStream>
#include <QTimer>

#include <algorithm>
#include <cmath>
#include <limits>
#include <map>
#include <set>

namespace {

constexpr double kDistanceScale = 1000.0;
constexpr double kWeightScale = 1000.0;
constexpr const char *kRoutesResourcePath = ":/data/shipment_routes.csv";

double percentImprovement(double initialLoss, double finalLoss)
{
    if (initialLoss <= 0.0) {
        return 0.0;
    }

    return ((initialLoss - finalLoss) / initialLoss) * 100.0;
}

} // namespace

LaneWiseController::LaneWiseController(QObject *parent)
    : QObject(parent)
    , m_dataReady(false)
    , m_trainingInProgress(false)
    , m_hasModel(false)
{
    loadRoutesFromResource();
    initializeDatasetSummary();
    initializeLaneOptions();
    initializeTrainingState();

    if (m_dataReady) {
        scheduleBatchTraining();
    }
}

LaneWiseController::OptimizerConfig LaneWiseController::batchTrainingConfig()
{
    return {GradientDescentType::BATCH, 0.001, 1e-2, 20000, 0, 0.0};
}

bool LaneWiseController::dataReady() const
{
    return m_dataReady;
}

bool LaneWiseController::trainingInProgress() const
{
    return m_trainingInProgress;
}

bool LaneWiseController::hasModel() const
{
    return m_hasModel;
}

QString LaneWiseController::statusText() const
{
    return m_statusText;
}

QVariantMap LaneWiseController::datasetSummary() const
{
    return m_datasetSummary;
}

QVariantList LaneWiseController::originOptions() const
{
    return m_originOptions;
}

QVariantMap LaneWiseController::trainingSummary() const
{
    return m_trainingSummary;
}

QVariantList LaneWiseController::objectiveHistory() const
{
    return m_objectiveHistory;
}

QVariantList LaneWiseController::coefficients() const
{
    return m_coefficients;
}

QVariantMap LaneWiseController::quoteResult() const
{
    return m_quoteResult;
}

void LaneWiseController::trainBatch()
{
    scheduleBatchTraining();
}

QVariantList LaneWiseController::destinationOptions(const QString &origin) const
{
    QVariantList options;
    for (const QVariant &originVariant : m_originOptions) {
        const QString destination = originVariant.toString();
        if (!origin.isEmpty() && destination == origin) {
            continue;
        }
        options.push_back(destination);
    }
    return options;
}

QVariantMap LaneWiseController::laneDefaults(const QString &origin, const QString &destination) const
{
    if (origin.isEmpty() || destination.isEmpty()) {
        return {
            {QStringLiteral("ready"), false},
            {QStringLiteral("label"), QStringLiteral("Select an origin and destination")}
        };
    }

    const QString laneKey = origin + QStringLiteral("|") + destination;
    const QVariantMap exactLane = m_laneLookup.value(laneKey).toMap();
    if (!exactLane.isEmpty()) {
        QVariantMap defaults = exactLane;
        defaults.insert(QStringLiteral("ready"), true);
        defaults.insert(QStringLiteral("exactMatch"), true);
        defaults.insert(QStringLiteral("laneType"), QStringLiteral("Historical lane"));
        defaults.insert(QStringLiteral("laneMessage"),
                        QStringLiteral("Built from recorded shipments on this exact lane."));
        return defaults;
    }

    const QString reverseLaneKey = destination + QStringLiteral("|") + origin;
    const QVariantMap reverseLane = m_laneLookup.value(reverseLaneKey).toMap();
    const QVariantMap originProfile = m_locationProfiles.value(origin).toMap();
    const QVariantMap destinationProfile = m_locationProfiles.value(destination).toMap();

    const double datasetAvgDistance = m_datasetSummary.value(QStringLiteral("avgDistance")).toDouble();
    const double datasetAvgWeight = m_datasetSummary.value(QStringLiteral("avgWeight")).toDouble();
    const double datasetAvgCost = m_datasetSummary.value(QStringLiteral("avgCost")).toDouble();

    const double originOutgoingDistance = originProfile.value(QStringLiteral("avgOutgoingDistance")).toDouble();
    const double destinationIncomingDistance = destinationProfile.value(QStringLiteral("avgIncomingDistance")).toDouble();

    double miles = 0.0;
    QString laneType;
    QString laneMessage;

    if (!reverseLane.isEmpty()) {
        miles = reverseLane.value(QStringLiteral("miles")).toDouble();
        laneType = QStringLiteral("Reverse-lane estimate");
        laneMessage = QStringLiteral("Estimated from the opposite direction of the same corridor.");
    } else {
        const double originHint = originOutgoingDistance > 0.0 ? originOutgoingDistance : datasetAvgDistance;
        const double destinationHint = destinationIncomingDistance > 0.0 ? destinationIncomingDistance : datasetAvgDistance;
        miles = (originHint + destinationHint) / 2.0;
        laneType = QStringLiteral("Network estimate");
        laneMessage = QStringLiteral("Estimated from origin and destination shipping patterns across the network.");
    }

    const double originWeight = originProfile.value(QStringLiteral("avgWeight")).toDouble();
    const double destinationWeight = destinationProfile.value(QStringLiteral("avgWeight")).toDouble();
    const double originPallets = originProfile.value(QStringLiteral("avgPallets")).toDouble();
    const double destinationPallets = destinationProfile.value(QStringLiteral("avgPallets")).toDouble();
    const int originShipmentCount = originProfile.value(QStringLiteral("shipmentCount")).toInt();
    const int destinationShipmentCount = destinationProfile.value(QStringLiteral("shipmentCount")).toInt();

    const double kilograms = ((originWeight > 0.0 ? originWeight : datasetAvgWeight)
                              + (destinationWeight > 0.0 ? destinationWeight : datasetAvgWeight)) / 2.0;
    const double pallets = std::max(1.0,
                                    ((originPallets > 0.0 ? originPallets : 8.0)
                                     + (destinationPallets > 0.0 ? destinationPallets : 8.0)) / 2.0);

    int defaultServiceLevel = reverseLane.value(QStringLiteral("defaultServiceLevel")).toInt();
    if (reverseLane.isEmpty()) {
        int bestScore = -1;
        for (int serviceLevel = 0; serviceLevel <= 2; ++serviceLevel) {
            const int score = originProfile.value(QStringLiteral("serviceCount%1").arg(serviceLevel)).toInt()
                + destinationProfile.value(QStringLiteral("serviceCount%1").arg(serviceLevel)).toInt();
            if (score > bestScore) {
                bestScore = score;
                defaultServiceLevel = serviceLevel;
            }
        }
        if (bestScore < 0) {
            defaultServiceLevel = 1;
        }
    }

    const double predictedBaseCost = predictCost(m_learnedParams,
                                                 miles,
                                                 kilograms,
                                                 qRound(pallets),
                                                 defaultServiceLevel);
    const double averageHintCost = ((originProfile.value(QStringLiteral("avgCost")).toDouble() > 0.0
                                     ? originProfile.value(QStringLiteral("avgCost")).toDouble()
                                     : datasetAvgCost)
                                    + (destinationProfile.value(QStringLiteral("avgCost")).toDouble() > 0.0
                                       ? destinationProfile.value(QStringLiteral("avgCost")).toDouble()
                                       : datasetAvgCost)) / 2.0;
    const double bandCenter = predictedBaseCost > 0.0 ? predictedBaseCost : averageHintCost;
    const double minCost = std::max(0.0, bandCenter * 0.88);
    const double maxCost = bandCenter * 1.12;

    return {
        {QStringLiteral("ready"), true},
        {QStringLiteral("label"), origin + QStringLiteral(" -> ") + destination},
        {QStringLiteral("miles"), miles},
        {QStringLiteral("kilograms"), kilograms},
        {QStringLiteral("pallets"), pallets},
        {QStringLiteral("minCost"), minCost},
        {QStringLiteral("maxCost"), maxCost},
        {QStringLiteral("shipmentCount"), originShipmentCount + destinationShipmentCount},
        {QStringLiteral("defaultServiceLevel"), defaultServiceLevel},
        {QStringLiteral("serviceLabel"), serviceLabel(defaultServiceLevel)},
        {QStringLiteral("exactMatch"), false},
        {QStringLiteral("laneType"), laneType},
        {QStringLiteral("laneMessage"), laneMessage}
    };
}

QVariantMap LaneWiseController::generateQuoteForLane(const QString &origin,
                                                     const QString &destination,
                                                     double kilograms,
                                                     int pallets,
                                                     int serviceLevel)
{
    if (!m_hasModel) {
        return m_quoteResult;
    }

    const QVariantMap defaults = laneDefaults(origin, destination);
    if (!defaults.value(QStringLiteral("ready")).toBool()) {
        return m_quoteResult;
    }

    const double miles = defaults.value(QStringLiteral("miles")).toDouble();
    const double resolvedKilograms = kilograms > 0.0
        ? kilograms
        : defaults.value(QStringLiteral("kilograms")).toDouble();
    const int resolvedPallets = pallets > 0
        ? pallets
        : qRound(defaults.value(QStringLiteral("pallets")).toDouble());
    const int resolvedService = serviceLevel >= 0
        ? serviceLevel
        : defaults.value(QStringLiteral("defaultServiceLevel")).toInt();
    const QString label = origin + QStringLiteral(" -> ") + destination;

    QVariantMap result = buildQuoteResult(label,
                                          miles,
                                          resolvedKilograms,
                                          resolvedPallets,
                                          resolvedService);
    result.insert(QStringLiteral("laneType"), defaults.value(QStringLiteral("laneType")));
    result.insert(QStringLiteral("laneMessage"), defaults.value(QStringLiteral("laneMessage")));
    result.insert(QStringLiteral("exactMatch"), defaults.value(QStringLiteral("exactMatch")));
    result.insert(QStringLiteral("historicalLow"), defaults.value(QStringLiteral("minCost")));
    result.insert(QStringLiteral("historicalHigh"), defaults.value(QStringLiteral("maxCost")));

    m_quoteResult = result;
    emit quoteResultChanged();
    return result;
}

void LaneWiseController::loadRoutesFromResource()
{
    QFile file(QString::fromUtf8(kRoutesResourcePath));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        m_statusText = QStringLiteral("Unable to open the embedded pricing network.");
        emit statusTextChanged();
        return;
    }

    QTextStream stream(&file);
    bool firstLine = true;

    auto trim = [](const QString &value) -> QString {
        return value.trimmed();
    };

    while (!stream.atEnd()) {
        const QString line = stream.readLine().trimmed();
        if (line.isEmpty()) {
            continue;
        }

        if (firstLine && line.contains(QStringLiteral("origin"), Qt::CaseInsensitive)) {
            firstLine = false;
            continue;
        }
        firstLine = false;

        const QStringList fields = line.split(QLatin1Char(','));
        if (fields.size() < 7) {
            continue;
        }

        bool okDistance = false;
        bool okWeight = false;
        bool okPallets = false;
        bool okService = false;
        bool okCost = false;

        const double distance = trim(fields[2]).toDouble(&okDistance);
        const double weight = trim(fields[3]).toDouble(&okWeight);
        const int pallets = trim(fields[4]).toInt(&okPallets);
        const int service = trim(fields[5]).toInt(&okService);
        const double cost = trim(fields[6]).toDouble(&okCost);

        if (!okDistance || !okWeight || !okPallets || !okService || !okCost) {
            continue;
        }

        RouteRecord route;
        route.origin = trim(fields[0]).toStdString();
        route.destination = trim(fields[1]).toStdString();
        route.distance_mi = distance;
        route.weight_kg = weight;
        route.pallet_count = pallets;
        route.service_level = service;
        route.cost_usd = cost;
        m_routes.push_back(route);
    }

    m_dataReady = !m_routes.empty();
    emit dataReadyChanged();

    if (m_dataReady) {
        m_statusText = QStringLiteral("Freight network loaded. Preparing live pricing...");
    } else {
        m_statusText = QStringLiteral("The embedded freight network is empty.");
    }
    emit statusTextChanged();
}

void LaneWiseController::initializeDatasetSummary()
{
    if (!m_dataReady) {
        m_datasetSummary = {
            {QStringLiteral("rows"), 0},
            {QStringLiteral("uniqueLanes"), 0},
            {QStringLiteral("avgDistance"), 0.0},
            {QStringLiteral("avgWeight"), 0.0},
            {QStringLiteral("avgCost"), 0.0},
            {QStringLiteral("minCost"), 0.0},
            {QStringLiteral("maxCost"), 0.0}
        };
        emit datasetSummaryChanged();
        return;
    }

    double totalDistance = 0.0;
    double totalWeight = 0.0;
    double totalCost = 0.0;
    double minCost = std::numeric_limits<double>::max();
    double maxCost = 0.0;
    std::set<std::string> lanePairs;

    for (const RouteRecord &route : m_routes) {
        totalDistance += route.distance_mi;
        totalWeight += route.weight_kg;
        totalCost += route.cost_usd;
        minCost = std::min(minCost, route.cost_usd);
        maxCost = std::max(maxCost, route.cost_usd);
        lanePairs.insert(route.origin + std::string("|") + route.destination);
    }

    const double routeCount = static_cast<double>(m_routes.size());

    m_datasetSummary = {
        {QStringLiteral("rows"), static_cast<int>(m_routes.size())},
        {QStringLiteral("uniqueLanes"), static_cast<int>(lanePairs.size())},
        {QStringLiteral("avgDistance"), totalDistance / routeCount},
        {QStringLiteral("avgWeight"), totalWeight / routeCount},
        {QStringLiteral("avgCost"), totalCost / routeCount},
        {QStringLiteral("minCost"), minCost},
        {QStringLiteral("maxCost"), maxCost}
    };
    emit datasetSummaryChanged();
}

void LaneWiseController::initializeLaneOptions()
{
    m_originOptions.clear();
    m_laneLookup.clear();
    m_locationProfiles.clear();

    if (!m_dataReady) {
        emit laneOptionsChanged();
        return;
    }

    struct LaneSummary {
        QString origin;
        QString destination;
        double totalDistance = 0.0;
        double totalWeight = 0.0;
        double totalPallets = 0.0;
        double minCost = std::numeric_limits<double>::max();
        double maxCost = 0.0;
        int count = 0;
        int serviceCounts[3] = {0, 0, 0};
    };

    struct LocationSummary {
        double outgoingDistanceTotal = 0.0;
        int outgoingDistanceCount = 0;
        double incomingDistanceTotal = 0.0;
        int incomingDistanceCount = 0;
        double totalWeight = 0.0;
        double totalPallets = 0.0;
        double totalCost = 0.0;
        int count = 0;
        int serviceCounts[3] = {0, 0, 0};
    };

    std::map<QString, LaneSummary> lanesByKey;
    std::map<QString, LocationSummary> locationsByName;
    std::set<QString> locations;

    for (const RouteRecord &route : m_routes) {
        const QString origin = QString::fromStdString(route.origin);
        const QString destination = QString::fromStdString(route.destination);
        const QString key = origin + QStringLiteral("|") + destination;
        LaneSummary &summary = lanesByKey[key];

        summary.origin = origin;
        summary.destination = destination;
        summary.totalDistance += route.distance_mi;
        summary.totalWeight += route.weight_kg;
        summary.totalPallets += static_cast<double>(route.pallet_count);
        summary.minCost = std::min(summary.minCost, route.cost_usd);
        summary.maxCost = std::max(summary.maxCost, route.cost_usd);
        summary.count += 1;
        if (route.service_level >= 0 && route.service_level <= 2) {
            summary.serviceCounts[route.service_level] += 1;
        }

        LocationSummary &originSummary = locationsByName[origin];
        originSummary.outgoingDistanceTotal += route.distance_mi;
        originSummary.outgoingDistanceCount += 1;
        originSummary.totalWeight += route.weight_kg;
        originSummary.totalPallets += static_cast<double>(route.pallet_count);
        originSummary.totalCost += route.cost_usd;
        originSummary.count += 1;
        if (route.service_level >= 0 && route.service_level <= 2) {
            originSummary.serviceCounts[route.service_level] += 1;
        }

        LocationSummary &destinationSummary = locationsByName[destination];
        destinationSummary.incomingDistanceTotal += route.distance_mi;
        destinationSummary.incomingDistanceCount += 1;
        destinationSummary.totalWeight += route.weight_kg;
        destinationSummary.totalPallets += static_cast<double>(route.pallet_count);
        destinationSummary.totalCost += route.cost_usd;
        destinationSummary.count += 1;
        if (route.service_level >= 0 && route.service_level <= 2) {
            destinationSummary.serviceCounts[route.service_level] += 1;
        }

        locations.insert(origin);
        locations.insert(destination);
    }

    for (const QString &location : locations) {
        m_originOptions.push_back(location);
    }

    for (const auto &entry : locationsByName) {
        const QString &locationName = entry.first;
        const LocationSummary &summary = entry.second;
        const double sampleCount = static_cast<double>(std::max(1, summary.count));

        m_locationProfiles.insert(locationName, QVariantMap{
            {QStringLiteral("avgOutgoingDistance"),
             summary.outgoingDistanceCount > 0
                 ? summary.outgoingDistanceTotal / static_cast<double>(summary.outgoingDistanceCount)
                 : 0.0},
            {QStringLiteral("avgIncomingDistance"),
             summary.incomingDistanceCount > 0
                 ? summary.incomingDistanceTotal / static_cast<double>(summary.incomingDistanceCount)
                 : 0.0},
            {QStringLiteral("avgWeight"), summary.totalWeight / sampleCount},
            {QStringLiteral("avgPallets"), summary.totalPallets / sampleCount},
            {QStringLiteral("avgCost"), summary.totalCost / sampleCount},
            {QStringLiteral("shipmentCount"), summary.count},
            {QStringLiteral("serviceCount0"), summary.serviceCounts[0]},
            {QStringLiteral("serviceCount1"), summary.serviceCounts[1]},
            {QStringLiteral("serviceCount2"), summary.serviceCounts[2]}
        });
    }

    for (const auto &entry : lanesByKey) {
        const LaneSummary &summary = entry.second;
        const double count = static_cast<double>(summary.count);
        int defaultServiceLevel = 0;
        for (int serviceLevel = 1; serviceLevel <= 2; ++serviceLevel) {
            if (summary.serviceCounts[serviceLevel] > summary.serviceCounts[defaultServiceLevel]) {
                defaultServiceLevel = serviceLevel;
            }
        }

        const QVariantMap laneMap = QVariantMap{
            {QStringLiteral("label"), summary.origin + QStringLiteral(" -> ") + summary.destination},
            {QStringLiteral("miles"), summary.totalDistance / count},
            {QStringLiteral("kilograms"), summary.totalWeight / count},
            {QStringLiteral("pallets"), summary.totalPallets / count},
            {QStringLiteral("minCost"), summary.minCost},
            {QStringLiteral("maxCost"), summary.maxCost},
            {QStringLiteral("shipmentCount"), summary.count},
            {QStringLiteral("defaultServiceLevel"), defaultServiceLevel},
            {QStringLiteral("serviceLabel"), serviceLabel(defaultServiceLevel)},
            {QStringLiteral("laneType"), QStringLiteral("Historical lane")},
            {QStringLiteral("laneMessage"),
             QStringLiteral("Built from recorded shipments on this exact lane.")}
        };
        m_laneLookup.insert(summary.origin + QStringLiteral("|") + summary.destination, laneMap);
    }

    emit laneOptionsChanged();
}

void LaneWiseController::initializeTrainingState()
{
    m_trainingSummary = {
        {QStringLiteral("ready"), false},
        {QStringLiteral("distanceScale"), kDistanceScale},
        {QStringLiteral("weightScale"), kWeightScale},
        {QStringLiteral("initialLoss"), 0.0},
        {QStringLiteral("finalLoss"), 0.0},
        {QStringLiteral("lossImprovementPercent"), 0.0},
        {QStringLiteral("iterations"), 0},
        {QStringLiteral("converged"), false},
        {QStringLiteral("message"), QStringLiteral("Pricing engine is preparing live rates.")}
    };
    emit trainingSummaryChanged();

    m_quoteResult = {
        {QStringLiteral("label"), QStringLiteral("Ready for your shipment")},
        {QStringLiteral("serviceLabel"), QStringLiteral("Economy")},
        {QStringLiteral("laneType"), QStringLiteral("Quote context")},
        {QStringLiteral("laneMessage"), QStringLiteral("Select a lane to generate a price.")},
        {QStringLiteral("exactMatch"), false},
        {QStringLiteral("historicalLow"), 0.0},
        {QStringLiteral("historicalHigh"), 0.0}
    };
    emit quoteResultChanged();
}

void LaneWiseController::scheduleBatchTraining()
{
    if (!m_dataReady || m_trainingInProgress) {
        return;
    }

    setTrainingState(true, QStringLiteral("Refreshing live pricing..."));

    QTimer::singleShot(0, this, [this]() {
        performBatchTraining();
    });
}

void LaneWiseController::performBatchTraining()
{
    const OptimizerConfig config = batchTrainingConfig();
    const ObjectiveFunction objective = makeObjectiveFunction();
    const std::vector<double> initialParams = {0.0, 0.0, 0.0, 0.0, 0.0};
    const double initialLoss = objective(initialParams);

    const gradient_descent::OptimizationResult result = executeTraining(config);
    m_learnedParams = result.final_params;

    updateTrainingSummary(result, initialLoss);
    updateCoefficients(result.final_params);

    const bool hadModel = m_hasModel;
    m_hasModel = result.final_params.size() == 5;
    if (m_hasModel != hadModel) {
        emit hasModelChanged();
    }

    m_quoteResult = buildQuoteResult(QStringLiteral("Seattle WA -> San Francisco CA"),
                                     808.0,
                                     8000.0,
                                     12,
                                     2);
    emit quoteResultChanged();

    setTrainingState(false, QStringLiteral("Live pricing is ready. Update shipment details to generate a quote."));
}

gradient_descent::OptimizationResult LaneWiseController::executeTraining(const OptimizerConfig &config) const
{
    gradient_descent optimizer(config.type,
                               config.learningRate,
                               config.tolerance,
                               config.maxIterations);

    if (config.batchSize > 0) {
        optimizer.set_batch_size(config.batchSize);
    }

    if (config.momentum > 0.0) {
        optimizer.set_momentum(config.momentum);
    }

    const std::vector<double> initialParams = {0.0, 0.0, 0.0, 0.0, 0.0};
    return optimizer.optimize_with_history(initialParams, makeObjectiveFunction(), makeGradientFunction());
}

ObjectiveFunction LaneWiseController::makeObjectiveFunction() const
{
    const std::vector<RouteRecord> routes = m_routes;
    const double routeCount = static_cast<double>(routes.size());

    return [routes, routeCount](const std::vector<double> &params) -> double {
        double totalError = 0.0;
        for (const RouteRecord &route : routes) {
            const double predicted = params[0]
                + params[1] * (route.distance_mi / kDistanceScale)
                + params[2] * (route.weight_kg / kWeightScale)
                + params[3] * static_cast<double>(route.pallet_count)
                + params[4] * static_cast<double>(route.service_level);
            const double error = predicted - route.cost_usd;
            totalError += error * error;
        }

        return totalError / routeCount;
    };
}

GradientFunction LaneWiseController::makeGradientFunction() const
{
    const std::vector<RouteRecord> routes = m_routes;
    const double routeCount = static_cast<double>(routes.size());

    return [routes, routeCount](const std::vector<double> &params) -> std::vector<double> {
        double dw0 = 0.0;
        double dw1 = 0.0;
        double dw2 = 0.0;
        double dw3 = 0.0;
        double dw4 = 0.0;

        for (const RouteRecord &route : routes) {
            const double xMiles = route.distance_mi / kDistanceScale;
            const double xWeight = route.weight_kg / kWeightScale;
            const double predicted = params[0]
                + params[1] * xMiles
                + params[2] * xWeight
                + params[3] * static_cast<double>(route.pallet_count)
                + params[4] * static_cast<double>(route.service_level);
            const double error = predicted - route.cost_usd;

            dw0 += 2.0 * error;
            dw1 += 2.0 * error * xMiles;
            dw2 += 2.0 * error * xWeight;
            dw3 += 2.0 * error * static_cast<double>(route.pallet_count);
            dw4 += 2.0 * error * static_cast<double>(route.service_level);
        }

        return {
            dw0 / routeCount,
            dw1 / routeCount,
            dw2 / routeCount,
            dw3 / routeCount,
            dw4 / routeCount
        };
    };
}

void LaneWiseController::setTrainingState(bool active, const QString &message)
{
    const bool stateChanged = m_trainingInProgress != active;
    m_trainingInProgress = active;
    m_statusText = message;

    if (stateChanged) {
        emit trainingInProgressChanged();
    }
    emit statusTextChanged();
}

void LaneWiseController::updateTrainingSummary(const gradient_descent::OptimizationResult &result,
                                               double initialLoss)
{
    m_trainingSummary = {
        {QStringLiteral("ready"), true},
        {QStringLiteral("distanceScale"), kDistanceScale},
        {QStringLiteral("weightScale"), kWeightScale},
        {QStringLiteral("initialLoss"), initialLoss},
        {QStringLiteral("finalLoss"), result.final_objective_value},
        {QStringLiteral("lossImprovementPercent"), percentImprovement(initialLoss, result.final_objective_value)},
        {QStringLiteral("iterations"), result.iterations_performed},
        {QStringLiteral("converged"), result.converged},
        {QStringLiteral("message"), QStringLiteral("Calibrated the current pricing engine.")}
    };
    emit trainingSummaryChanged();

    m_objectiveHistory = toVariantHistory(result.objective_history);
    emit objectiveHistoryChanged();
}

void LaneWiseController::updateCoefficients(const std::vector<double> &params)
{
    if (params.size() != 5) {
        return;
    }

    m_coefficients = {
        QVariantMap{
            {QStringLiteral("key"), QStringLiteral("w0")},
            {QStringLiteral("label"), QStringLiteral("Base handling")},
            {QStringLiteral("rawValue"), params[0]},
            {QStringLiteral("businessValue"), params[0]},
            {QStringLiteral("unit"), QStringLiteral("$ per shipment")},
            {QStringLiteral("insight"), QStringLiteral("A base handling charge anchors each shipment before route-specific costs are added.")}
        },
        QVariantMap{
            {QStringLiteral("key"), QStringLiteral("w1")},
            {QStringLiteral("label"), QStringLiteral("Distance rate")},
            {QStringLiteral("rawValue"), params[1]},
            {QStringLiteral("businessValue"), params[1] / kDistanceScale},
            {QStringLiteral("unit"), QStringLiteral("$ per mile")},
            {QStringLiteral("insight"), QStringLiteral("Mileage creates a clear linehaul contribution for each lane.")}
        },
        QVariantMap{
            {QStringLiteral("key"), QStringLiteral("w2")},
            {QStringLiteral("label"), QStringLiteral("Weight rate")},
            {QStringLiteral("rawValue"), params[2]},
            {QStringLiteral("businessValue"), params[2] / kWeightScale},
            {QStringLiteral("unit"), QStringLiteral("$ per kg")},
            {QStringLiteral("insight"), QStringLiteral("Weight keeps heavy freight quotes aligned with real invoice behavior.")}
        },
        QVariantMap{
            {QStringLiteral("key"), QStringLiteral("w3")},
            {QStringLiteral("label"), QStringLiteral("Pallet handling")},
            {QStringLiteral("rawValue"), params[3]},
            {QStringLiteral("businessValue"), params[3]},
            {QStringLiteral("unit"), QStringLiteral("$ per pallet")},
            {QStringLiteral("insight"), QStringLiteral("Pallet count reflects dock time, touches, and handling complexity.")}
        },
        QVariantMap{
            {QStringLiteral("key"), QStringLiteral("w4")},
            {QStringLiteral("label"), QStringLiteral("Priority uplift")},
            {QStringLiteral("rawValue"), params[4]},
            {QStringLiteral("businessValue"), std::abs(params[4])},
            {QStringLiteral("unit"), QStringLiteral("$ per service step")},
            {QStringLiteral("insight"), QStringLiteral("Priority service adds a premium as shipments move from economy to express.")}
        }
    };
    emit coefficientsChanged();
}

QVariantMap LaneWiseController::buildQuoteResult(const QString &label,
                                                 double miles,
                                                 double kilograms,
                                                 int pallets,
                                                 int serviceLevel) const
{
    const double predictedCost = predictCost(m_learnedParams, miles, kilograms, pallets, serviceLevel);
    return {
        {QStringLiteral("label"), label},
        {QStringLiteral("miles"), miles},
        {QStringLiteral("kilograms"), kilograms},
        {QStringLiteral("pallets"), pallets},
        {QStringLiteral("serviceLabel"), serviceLabel(serviceLevel)},
        {QStringLiteral("predictedCost"), predictedCost},
        {QStringLiteral("laneType"), QStringLiteral("Direct quote")},
        {QStringLiteral("laneMessage"), QStringLiteral("Generated from the selected shipment profile.")},
        {QStringLiteral("exactMatch"), true},
        {QStringLiteral("historicalLow"), 0.0},
        {QStringLiteral("historicalHigh"), 0.0}
    };
}

double LaneWiseController::predictCost(const std::vector<double> &params,
                                       double miles,
                                       double kilograms,
                                       int pallets,
                                       int serviceLevel) const
{
    if (params.size() != 5) {
        return 0.0;
    }

    return params[0]
        + params[1] * (miles / kDistanceScale)
        + params[2] * (kilograms / kWeightScale)
        + params[3] * static_cast<double>(pallets)
        + params[4] * static_cast<double>(serviceLevel);
}

QString LaneWiseController::serviceLabel(int serviceLevel) const
{
    switch (serviceLevel) {
    case 0:
        return QStringLiteral("Economy");
    case 1:
        return QStringLiteral("Standard");
    case 2:
        return QStringLiteral("Express");
    default:
        return QStringLiteral("Unknown");
    }
}

QVariantList LaneWiseController::toVariantHistory(const std::vector<double> &history) const
{
    QVariantList points;
    points.reserve(static_cast<qsizetype>(history.size()));
    for (double value : history) {
        points.push_back(value);
    }
    return points;
}
