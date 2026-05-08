#ifndef LANEWISECONTROLLER_HPP
#define LANEWISECONTROLLER_HPP

#include "gradient_descent.hpp"

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

#include <vector>

class LaneWiseController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool dataReady READ dataReady NOTIFY dataReadyChanged)
    Q_PROPERTY(bool trainingInProgress READ trainingInProgress NOTIFY trainingInProgressChanged)
    Q_PROPERTY(bool hasModel READ hasModel NOTIFY hasModelChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)
    Q_PROPERTY(QVariantMap datasetSummary READ datasetSummary NOTIFY datasetSummaryChanged)
    Q_PROPERTY(QVariantList originOptions READ originOptions NOTIFY laneOptionsChanged)
    Q_PROPERTY(QVariantMap trainingSummary READ trainingSummary NOTIFY trainingSummaryChanged)
    Q_PROPERTY(QVariantList objectiveHistory READ objectiveHistory NOTIFY objectiveHistoryChanged)
    Q_PROPERTY(QVariantList coefficients READ coefficients NOTIFY coefficientsChanged)
    Q_PROPERTY(QVariantMap quoteResult READ quoteResult NOTIFY quoteResultChanged)

public:
    explicit LaneWiseController(QObject *parent = nullptr);

    bool dataReady() const;
    bool trainingInProgress() const;
    bool hasModel() const;
    QString statusText() const;
    QVariantMap datasetSummary() const;
    QVariantList originOptions() const;
    QVariantMap trainingSummary() const;
    QVariantList objectiveHistory() const;
    QVariantList coefficients() const;
    QVariantMap quoteResult() const;

    Q_INVOKABLE void trainBatch();
    Q_INVOKABLE QVariantList destinationOptions(const QString &origin) const;
    Q_INVOKABLE QVariantMap laneDefaults(const QString &origin, const QString &destination) const;
    Q_INVOKABLE QVariantMap generateQuoteForLane(const QString &origin,
                                                 const QString &destination,
                                                 double kilograms,
                                                 int pallets,
                                                 int serviceLevel);

signals:
    void dataReadyChanged();
    void trainingInProgressChanged();
    void hasModelChanged();
    void statusTextChanged();
    void datasetSummaryChanged();
    void laneOptionsChanged();
    void trainingSummaryChanged();
    void objectiveHistoryChanged();
    void coefficientsChanged();
    void quoteResultChanged();

private:
    struct OptimizerConfig {
        GradientDescentType type;
        double learningRate;
        double tolerance;
        int maxIterations;
        int batchSize;
        double momentum;
    };

    void loadRoutesFromResource();
    void initializeDatasetSummary();
    void initializeLaneOptions();
    void initializeTrainingState();
    void scheduleBatchTraining();
    void performBatchTraining();
    static OptimizerConfig batchTrainingConfig();
    gradient_descent::OptimizationResult executeTraining(const OptimizerConfig &config) const;
    ObjectiveFunction makeObjectiveFunction() const;
    GradientFunction makeGradientFunction() const;
    void setTrainingState(bool active, const QString &message);
    void updateTrainingSummary(const gradient_descent::OptimizationResult &result,
                               double initialLoss);
    void updateCoefficients(const std::vector<double> &params);
    QVariantMap buildQuoteResult(const QString &label,
                                 double miles,
                                 double kilograms,
                                 int pallets,
                                 int serviceLevel) const;
    double predictCost(const std::vector<double> &params,
                       double miles,
                       double kilograms,
                       int pallets,
                       int serviceLevel) const;
    QString serviceLabel(int serviceLevel) const;
    QVariantList toVariantHistory(const std::vector<double> &history) const;

    std::vector<RouteRecord> m_routes;
    std::vector<double> m_learnedParams;
    bool m_dataReady;
    bool m_trainingInProgress;
    bool m_hasModel;
    QString m_statusText;
    QVariantMap m_datasetSummary;
    QVariantList m_originOptions;
    QVariantMap m_laneLookup;
    QVariantMap m_locationProfiles;
    QVariantMap m_trainingSummary;
    QVariantList m_objectiveHistory;
    QVariantList m_coefficients;
    QVariantMap m_quoteResult;
};

#endif
